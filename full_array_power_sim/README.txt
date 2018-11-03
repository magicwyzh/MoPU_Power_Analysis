1. 对于outfm_size<num_pe_row/2的情况：由于有超过一半的PErow都没有计算，会显著降低perf。为了显著降低这个side effect，考虑架构的如下的优化方式：
	1a.对于normal conv，PEArray上半部分照常计算，PEArray的下半部分输入的infm row和上半部分相同，只不过在架构上给上下半部分各分配一组WRegs和WBPRs。这样原本一次只能由32个output channel可以一下变成64个output channel，可以提高一定的performance
	1b.对于dw_conv， 上下两部分各算一个channel，也就是在channel上并行。而两个channel虽然weights不一样，但是在1a里面说了，上下班部分各分配一组WRegs和WBPRs，所以刚好也可以用来给上下半部分做参数的缓冲。另一方面为了feed last PE row，也要给上半部分的最后一行增加和WeightBuffer的缓冲。事实上理论上为了应对不同的fmsize，应该要给每一行的PE的ShadowAFIFO input 都连接到weight buffer中。。但是我这里没有这么做。
	1c.上述只是理论上应该可以这么实现，但是在power analysis的过程中，为了方便，我的做法只是让PEArray下半部分的PE Row的act input和上半部分的act input相同，而共用weights。然后在具体计算的调度上少计算一半的channel。修改了的task分别为:a)array_conv_one_row_ctrl/load_infm2d_to_array_col b)array_conv_one_layer_ctrl/dw_conv_one_layer  c)array_conv_layer_ctrl/normal_conv_one_layer(添加了cout_start_idx_onetime_step;) d)array_conv_layer_ctrl/normal_conv_one_infm_tile

2. 当outfm_Width 比较小的时候，如果做dwconv，用我现在那种方法可能会导致systolic data out需要无用的cycle（一方面来自于每个PE可能output activation数目会略有不同，差1，也有可能有的pe array直接没有输出。。），暂时还没有处理。。

3.现在这种把featuremap 二维展开的情况对于7x7的效率很低，是因为不仅下半部分不会计算，而且右边半部分也不会计算。。。。理论上在通过systolic data chain 进行output shift out的时候也应该只shift out左边半部分的。。或者其实可以同时算4个channel。。修改 array_conv_one_row_ctrl/load_infm2d_to_array_accord_workload。。 但是对于perf的提升效果还是很不好。。因为给每一个column送数据实在是太慢了。。对于7x7的layer，只是从15Op/cycle提升到22Op/Cycle, 理想的是64Op/Cycle..但是看了下在fm_size = 114的情况下的perf，大概有54OP/cycle，说明对于比较大的featuremap，效果还马马虎虎。。可能主要是因为比较大的featuremap，每个PE column需要的activation重叠的没那么多，不会需要重复送，以及每个PE需要的计算时间增加了。。fm size=16的时候虽然感觉刚好能填满PE Array，但是Perf只有21。。


4. 所以对于depthwise Conv这种memory bound的情况，其实应该要考虑的是再进一步提高feed 数据的on-chip Buffer带宽，所以实际上OutBuffer也应该参与到feed数据中来。。比如在fm size > num_pe_col/2的情况下， outbuffer中应该存有右半部分的infm。。在fm_size < num_pe_col/2的情况下，outbuffer应该保存有其他channel的 infm数据。。现在暂时先不搞这个了，留着以后搞吧。估计这个还能再提升一倍的perf。。 

5. 在实现Buffer control的时候，是通过一个额外的buffer_ctrl.sv来实现的，里面和compute ctrl一样也有一堆模拟tiling的for循环，并没有和compute ctrl合并在一起，而是在每个layer开始的时候一次性把这个layer所有的读写都搞定。
outputbuffer没有专门去进行control，而是直接接到PEArray上面，然后在outbuffer里面添加一个counter8K用来产生读写地址，而control产生的next_cycle_data_valid用来当作rEn of Outbuffer，delay之后作为wEn。反正主要就是让每次PE Array需要把结果写入OutBuffer的时候都有地方写入就可以了，并不需要真的有什么具体的地址，因为只是power analysis。

6. 另外OutBuffer之类的也重新实现了一下，不过还是没有调成8bit Buffer，还是16bit Buffer。然后读写的办法也还是一次出来一个weight data，没有在低bit的时候把多个weight pack起来减少读写。

7. 发现了VCS和Modelsim行为不一致，其实这个主要原因就是我的control经常就是@(posedge clk);然后就直接开始直接操作一些控制信号了。在Modelsim里面，Datapath中的寄存器会正常地采样上个周期结束时候一些信号的值，但是换成VCS之后发现DataPath就直接采样了新信号，就会出错。找了半天其实发现解决办法应该是在@(posedge clk)之后都稍微延迟一下再去产生控制信号。按照网上的说法（http://www.cnblogs.com/yuphone/archive/2010/12/31/1922614.html 事件控制section），这个其实就是要avoid hold-time violation的。其实我觉得中间的逻辑大概是这样的：在每个posedge clk到来之后，Modelsim会首先去更新底层模块中各个信号的值，所以会采样到旧信号，而VCS是自上而下的，所以Modelsim的行为符合预期而VCS的行为不符合预期。
不过需要注意的是，我原来的code里面其实就包含了一些“#1;”这样的控制，主要是让testbench等待testbench内部信号的时候能够正确采样。而为了让VCS也有符合预期的行为，把所有:
@(posedge clk); -> @(posedge clk) #(`HOLD_TIME_DELTA); 
那么一个问题就来了，这个HOLD_TIME_DELTA和原来的#1是不是会重复或者冲突呢？我本来是想把所有的@(posedge clk)后的#1都删了，但是发现在VCS里仿真会有问题。。就是比如遇到一些control在等待testbench内部的其他信号（如singlePEScheduler中等待xxx_valid_trig这个信号的时候，等待的窗口期只有1个cycle，而一开始HOLD_TIME_DELTA也=1， 而原本也#1，导致采样才不采不到。。
最后想了，觉得其实应该这样, HOLD_TIME_DELTA设置为比如0.5，即小于原来常用的1，那么对于原本需要#1的地方，那个posedge clk还是和原来一样的，被当作一个没有hold-time delta的posedge clk。 然后应该就可以正常工作了。

8. 16b DataPath做了功耗分析之后power太大了，所以要把datapath的width降下来来降低功耗，主要是从16b降低到8b，还有把11tap搞成3tap，因为3tap是最常用的。具体方法是保留各个模块的接口为16b，但是多余的线置零或者符号扩展，希望DC能够自动优化，具体如下：
	8a. 在WBuff中将ram改成8bit的，但是WBuff模块的接口还是16b的，只不过把多余的bit都置成0，另外多余的tap也置0。
	8b. ActBuff和WBuff一样，17bits->8bits，原本的zero indicator还是最高位，但是不存sign bit了，默认为0。
	8c. PEArrayDataInWrapper中，把多余的taps置零
	8d. PE的AFIFO换成了8bits的，但是输入输出还是17bits，因为activation是不需要符号位的。
	8e. PE的ACCFIFO原本是24bits，占了大部分功耗，但是经过仿真发现，几乎不会遇到在ACCFIFO output需要超过16bits的，所以最后ACCFIFO的位宽可以调整成16bits。仍然是将DoubleACCFIFO中做截断和符号扩展。