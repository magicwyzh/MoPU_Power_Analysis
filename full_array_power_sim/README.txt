1. 对于outfm_size<num_pe_row/2的情况：由于有超过一半的PErow都没有计算，会显著降低perf。为了显著降低这个side effect，考虑架构的如下的优化方式：
	1a.对于normal conv，PEArray上半部分照常计算，PEArray的下半部分输入的infm row和上半部分相同，只不过在架构上给上下半部分各分配一组WRegs和WBPRs。这样原本一次只能由32个output channel可以一下变成64个output channel，可以提高一定的performance
	1b.对于dw_conv， 上下两部分各算一个channel，也就是在channel上并行。而两个channel虽然weights不一样，但是在1a里面说了，上下班部分各分配一组WRegs和WBPRs，所以刚好也可以用来给上下半部分做参数的缓冲。另一方面为了feed last PE row，也要给上半部分的最后一行增加和WeightBuffer的缓冲。事实上理论上为了应对不同的fmsize，应该要给每一行的PE的ShadowAFIFO input 都连接到weight buffer中。。但是我这里没有这么做。
	1c.上述只是理论上应该可以这么实现，但是在power analysis的过程中，为了方便，我的做法只是让PEArray下半部分的PE Row的act input和上半部分的act input相同，而共用weights。然后在具体计算的调度上少计算一半的channel。修改了的task分别为:a)array_conv_one_row_ctrl/load_infm2d_to_array_col b)array_conv_one_layer_ctrl/dw_conv_one_layer  c)array_conv_layer_ctrl/normal_conv_one_layer(添加了cout_start_idx_onetime_step;) d)array_conv_layer_ctrl/normal_conv_one_infm_tile

2. 当outfm_Width 比较小的时候，如果做dwconv，用我现在那种方法可能会导致systolic data out需要无用的cycle（一方面来自于每个PE可能output activation数目会略有不同，差1，也有可能有的pe array直接没有输出。。），暂时还没有处理。。

3.现在这种把featuremap 二维展开的情况对于7x7的效率很低，是因为不仅下半部分不会计算，而且右边半部分也不会计算。。。。理论上在通过systolic data chain 进行output shift out的时候也应该只shift out左边半部分的。。或者其实可以同时算4个channel。。修改 array_conv_one_row_ctrl/load_infm2d_to_array_accord_workload。。 但是对于perf的提升效果还是很不好。。因为给每一个column送数据实在是太慢了。。对于7x7的layer，只是从15Op/cycle提升到22Op/Cycle, 理想的是64Op/Cycle..但是看了下在fm_size = 114的情况下的perf，大概有54OP/cycle，说明对于比较大的featuremap，效果还马马虎虎。。可能主要是因为比较大的featuremap，每个PE column需要的activation重叠的没那么多，不会需要重复送，以及每个PE需要的计算时间增加了。。fm size=16的时候虽然感觉刚好能填满PE Array，但是Perf只有21。。

4. 

4. 所以对于depthwise Conv这种memory bound的情况，其实应该要考虑的是再进一步提高feed 数据的on-chip Buffer带宽，所以实际上OutBuffer也应该参与到feed数据中来。。比如在fm size > num_pe_col/2的情况下， outbuffer中应该存有右半部分的infm。。在fm_size < num_pe_col/2的情况下，outbuffer应该保存有其他channel的 infm数据。。现在暂时先不搞这个了，留着以后搞吧。估计这个还能再提升一倍的perf。。 