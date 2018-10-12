`timescale 1ns/1ns
module AllBuffers_tb #(parameter
	AFIFO_size = 8,
	ACCFIFO_size = 32,
	nb_not_compute = 0,
	nb_actqb = 8,
    nb_wqb = 8,
    dump_vcd = 0,
	//parameters for FoFIR
	nb_taps = 11,
	activation_width = 16,
	compressed_act_width = activation_width + 1,
	weight_width = 16,
	tap_width = 24,
	weight_bpr_width = ((weight_width+1)/2)*3,
	act_bpr_width = ((activation_width+1)/2)*3,
	ETC_width = 4,
	width_current_tap = nb_taps > 8 ? 4 : 3,
	output_width = tap_width,
	nb_actbuff = 8,
	nb_wbuff = 32,
	nb_accbuff = 8
)();
	logic valid_result_trig, valid_result;
	logic [compressed_act_width-1: 0] compressed_act_in;
	logic [output_width-1: 0] out_fr_left_PE;
	
	logic out_to_right_pe_en;
	/*************control signals for FoFIR************/
	//configuration ports
	logic [4-1: 0] n_ap;

	//control ports for PAMAC
	logic [3-1: 0] PAMAC_BPEB_sel;
	logic PAMAC_DFF_en;
	logic PAMAC_first_cycle;
	//the following two logics are reserved 
	logic PAMAC_MDecomp;//1 is mulwise, 0 is layerwise
	logic PAMAC_AWDecomp;// 0 is act decomp, 1 is w decomp

	//control signals for FoFIR
	logic [width_current_tap-1: 0] current_tap;
	//DRegs signals
	logic [nb_taps-1: 0] DRegs_en;
	logic [nb_taps-1: 0] DRegs_clr;
	logic [nb_taps-1: 0] DRegs_in_sel;//0 is from left, 1 is from pamac wire
	
	//DRegs indexing signals
	logic index_update_en;

	//wire signals
	logic out_mux_sel;//0 is from PAMAC, 1 is from DRegs
	logic out_reg_en;
	
	/**********Weight Ports for FoFIR********************/
	logic [weight_width*nb_taps-1: 0] WRegs;
	logic [weight_bpr_width*nb_taps-1: 0] WBPRs;
	logic [ETC_width*nb_taps-1: 0] WETCs;
	
	/************Control Signals for FIFOs***************/
	logic AFIFO_write;
	logic AFIFO_read;
	logic ACCFIFO_write;
	logic ACCFIFO_read;
	logic out_mux_sel_PE;//
	logic add_zero;
	logic clk;
	logic rst_n;
	wire [width_current_tap-1: 0] PD0;
	wire [output_width-1: 0] out_to_right_PE;
	wire ACCFIFO_empty;
PE_for_power_analysis #(
    .AFIFO_size            ( AFIFO_size                             ),
    .ACCFIFO_size                   ( ACCFIFO_size                            ),
    .nb_taps                        ( nb_taps                             ),
    .activation_width               ( activation_width                            ),
    .compressed_act_width           ( compressed_act_width            ),
    .weight_width                   ( weight_width                            ),
    .tap_width                      ( tap_width                            ),
    .ETC_width                      ( ETC_width                             ))
U_PE_FOR_POWER_ANLAYSIS_0(
    .compressed_act_in              ( compressed_act_in             ),
    .out_fr_left_PE                 ( out_fr_left_PE                ),
    .n_ap                           ( n_ap                          ),
    .PAMAC_BPEB_sel                 ( PAMAC_BPEB_sel                ),
    .PAMAC_DFF_en                   ( PAMAC_DFF_en                  ),
    .PAMAC_first_cycle              ( PAMAC_first_cycle             ),
    .PAMAC_MDecomp                  ( PAMAC_MDecomp                 ),
    .PAMAC_AWDecomp                 ( PAMAC_AWDecomp                ),
    .current_tap                    ( current_tap                   ),
    .DRegs_en                       ( DRegs_en                      ),
    .DRegs_clr                      ( DRegs_clr                     ),
    .DRegs_in_sel                   ( DRegs_in_sel                  ),
    .index_update_en                ( index_update_en               ),
    .out_mux_sel                    ( out_mux_sel                   ),
    .out_reg_en                     ( out_reg_en                    ),
    .WRegs                          ( WRegs                         ),
    .WBPRs                          ( WBPRs                         ),
    .WETCs                          ( WETCs                         ),
    .AFIFO_write                    ( AFIFO_write                   ),
    .AFIFO_read                     ( AFIFO_read                    ),
    .ACCFIFO_write                  ( ACCFIFO_write                 ),
    .ACCFIFO_read                   ( ACCFIFO_read                  ),
    .out_mux_sel_PE                 ( out_mux_sel_PE                ),
	.add_zero						( add_zero                      ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .PD0                            ( PD0                           ),
    .out_to_right_PE                ( out_to_right_PE               ),
	.out_to_right_pe_en				( out_to_right_pe_en),
	.ACCFIFO_empty					(ACCFIFO_empty)
);



/*****************ActBuffer Bank ports**************************/
//AH means Active High
logic ActBuff_wEn_AH;
logic ActBuff_rEn_AH;
logic [10-1: 0] ActBuff_wAddr, ActBuff_rAddr;
wire [nb_actbuff*17-1: 0] ActBufferOut;
logic [17-1: 0] ActBufferIn;


/****************End of ActBuffer Bank ports *******************/


/**************WeightBufferBank ports**************************/
wire [nb_wbuff*nb_taps * weight_width - 1: 0] WBuff_WRegs;
wire [nb_wbuff*nb_taps * weight_bpr_width - 1: 0] WBuff_WBPRs;
wire [nb_wbuff*nb_taps * ETC_width - 1: 0] WBuff_WETCs;
logic [nb_taps-1: 0] WBuff_weight_load_en;
logic [7-1: 0] WBuff_wAddr, WBuff_rAddr;
logic [16-1: 0] WBuff_data_in;
logic WBuff_wEn_AH, WBuff_rEn_AH;

/**************End of WeightBufferBank ports******************/

/*************ACCBUFF Bank ports*************************/
logic [24-1: 0] AccBuff_data_in;
logic [13-1: 0] AccBuff_wAddr, AccBuff_rAddr;
logic AccBuff_wEn_AH, AccBuff_rEn_AH;
wire [nb_actbuff*16-1: 0]AccBuff_data_out;
logic adder_src_sel;

/***********End of ACCBUFF Bank ports********************/
/*******All Buffer Instance****************/

AllBuffers_for_power_analysis #(
    .nb_taps                        ( 11                            ),
    .weight_width                   ( 16                            ),
    .activation_width               ( 16                            ),
    .tap_width                      ( 24                            ),
    .compressed_act_width           ( activation_width+1            ),
    .ETC_width                      ( 4                             ),
    .output_width                   ( tap_width                     ),
    .nb_actbuff                     ( 8                             ),
    .nb_wbuff                       ( 32                            ),
    .nb_accbuff                     ( 8                             ))
U_ALLBUFFERS_FOR_POWER_ANALYSIS_0(
    .ActBuff_wEn_AH                 ( ActBuff_wEn_AH                ),
    .ActBuff_rEn_AH                 ( ActBuff_rEn_AH                ),
    .ActBuff_wAddr                  ( ActBuff_wAddr                 ),
    .ActBuff_rAddr                  ( ActBuff_rAddr                 ),
    .ActBufferOut                   ( ActBufferOut                  ),
    .ActBufferIn                    ( ActBufferIn                   ),
    .WBuff_WRegs                    ( WBuff_WRegs                   ),
    .WBuff_WBPRs                    ( WBuff_WBPRs                   ),
    .WBuff_WETCs                    ( WBuff_WETCs                   ),
    .WBuff_weight_load_en           ( WBuff_weight_load_en          ),
    .WBuff_wAddr                    ( WBuff_wAddr                   ),
    .WBuff_rAddr                    ( WBuff_rAddr                   ),
    .WBuff_data_in                  ( WBuff_data_in                 ),
    .WBuff_wEn_AH                   ( WBuff_wEn_AH                  ),
    .WBuff_rEn_AH                   ( WBuff_rEn_AH                  ),
    .AccBuff_data_in                ( AccBuff_data_in               ),
    .AccBuff_wAddr                  ( AccBuff_wAddr                 ),
    .AccBuff_rAddr                  ( AccBuff_rAddr                 ),
    .AccBuff_wEn_AH                 ( AccBuff_wEn_AH                ),
    .AccBuff_rEn_AH                 ( AccBuff_rEn_AH                ),
    .AccBuff_data_out               ( AccBuff_data_out              ),
    .acc_adder_src_sel              ( adder_src_sel             ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .n_ap                           ( n_ap                          )
);

/*******End of AllBuffers Instance**********/


initial begin
	clk = 0;
	forever begin
		#10 clk = ~ clk;
	end
end
initial begin

    //init buffers ports
    {ActBuff_rEn_AH, ActBuff_wEn_AH, ActBuff_wAddr,ActBuff_rAddr,ActBufferIn} = 0;
    {WBuff_weight_load_en, WBuff_wAddr, WBuff_rAddr, WBuff_data_in, WBuff_rEn_AH, WBuff_wEn_AH} = 0;
    {AccBuff_data_in, AccBuff_rAddr, AccBuff_wAddr, AccBuff_rEn_AH, AccBuff_wEn_AH} = 0;
    adder_src_sel = 0;
    valid_result_trig = 0; 	
    compressed_act_in = 0;
    out_fr_left_PE = 0;

    out_to_right_pe_en = 0;

    PAMAC_BPEB_sel = 0;
    PAMAC_DFF_en = 0;
    PAMAC_first_cycle = 0;
    PAMAC_MDecomp = 0;//1 is mulwise, 0 is layerwise
    PAMAC_AWDecomp = 0;// 0 is act decomp, 1 is w decomp

    current_tap = 0;
    DRegs_en = 0;
    DRegs_clr = 0;
    DRegs_in_sel = 0;//0 is from left, 1 is from pamac wire

    index_update_en = 0;

    out_mux_sel = 0;//0 is from PAMAC, 1 is from DRegs
    out_reg_en = 0;

    WRegs = 0;
    WBPRs = 0;
    WETCs = 0;

    AFIFO_write = 0;
    AFIFO_read = 0;
    ACCFIFO_write = 0;
    ACCFIFO_read = 0;
    out_mux_sel_PE = 0;//
    add_zero = 0;

end

/*************Helper variables*************************/
wire [compressed_act_width-1: 0] afifo_out;
assign afifo_out = U_PE_FOR_POWER_ANLAYSIS_0.compressed_act_fr_afifo;
int i;
int kernel_size;
int quantized_bits;

int temp;
logic [16-1: 0] weights_this_layer[3*3*512*512];//the maximum
logic [compressed_act_width-1: 0]  act_this_row[$];
logic first_acc_flag;

int kernel_size_per_layer[52] = '{3,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1};
int is_depthwise[52] = '{0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0};
int fm_size_per_layer[52] = '{226,114,112,112,114,56,56,58,56,56,58,28,28,30,28,28,30,28,28,30,14,14,16,14,14,16,14,14,16,14,14,16,14,14,16,14,14,16,14,14,16,7,7,9,7,7,9,7,7,9,7,7};
int in_ch_per_layer[52] = '{3,32,32,16,96,96,24,144,144,24,144,144,32,192,192,32,192,192,32,192,192,64,384,384,64,384,384,64,384,384,64,384,384,96,576,576,96,576,576,96,576,576,160,960,960,160,960,960,160,960,960,320};
int out_ch_per_layer[52] = '{32,32,16,96,96,24,144,144,24,144,144,32,192,192,32,192,192,32,192,192,64,384,384,64,384,384,64,384,384,64,384,384,96,576,576,96,576,576,96,576,576,160,960,960,160,960,960,160,960,960,320,1280};
int stride_per_layer[52] = '{2,1,1,1,2,1,1,1,1,1,2,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1};

int start_layer;
int end_layer;
int current_layer;
int seed;
int act_quantized_bits;
int weight_quantized_bits;
/******************Main**********************/
initial begin
	int nb_pe_row;
	int nb_pe_col;
	act_quantized_bits = nb_actqb;
	weight_quantized_bits = nb_wqb;
	seed = 0;
	PAMAC_MDecomp = 1;
    PAMAC_AWDecomp = 0;
    //previously wrongly use nb_pe_row=nb_pe_col=1....
	nb_pe_row = 16;
	nb_pe_col = 16;
	first_acc_flag = 1;
	PAMAC_MDecomp = 1;
	PAMAC_AWDecomp = 0;
	start_layer = 1;
	end_layer = 3;
	n_ap = nb_not_compute;
	//init_random_weights;
	quantized_bits = weight_quantized_bits;
	add_zero = 0;
	rst_n = 1;
    init_weight_this_layer;
    clear_infm2d_buffer;
	#5
	rst_n = 0;
	#20
	rst_n = 1;
	fork
		init_WBuff;
		init_ACCFIFO;
		init_AccBuff;
	join
    @(posedge clk);
    if(dump_vcd) begin
        $dumpon;
    end
	for(current_layer=start_layer;current_layer<end_layer; current_layer++) begin
        kernel_size = kernel_size_per_layer[current_layer];
        // currently not support stride=2
        if(stride_per_layer[current_layer] == 2) begin
            continue;
        end
        if(is_depthwise == 1) begin
            dw_conv_one_layer(
                current_layer, 
                in_ch_per_layer[current_layer],
                kernel_size_per_layer[current_layer],
                stride_per_layer[current_layer],
                fm_size_per_layer[current_layer],
                nb_pe_row,
                nb_pe_col,
                n_ap,
                quantized_bits
            );
        end
        else begin
            conv_one_layer(
                current_layer, 
                in_ch_per_layer[current_layer], 
                out_ch_per_layer[current_layer],
                kernel_size_per_layer[current_layer],
                stride_per_layer[current_layer],
                fm_size_per_layer[current_layer],
                1,//nb_pe_row,
                1,//nb_pe_col,
                n_ap,
                quantized_bits
            );
        end
		
	end
    @(posedge clk);
    if(dump_vcd) begin
        $dumpoff;
    end
	$finish;
end

int total_wetc;
int act_row_size;
always@(*) begin
	total_wetc = 0;
	for(int mmm=0;mmm<nb_taps; mmm ++ )begin
		total_wetc += WETCs[(mmm+1)*ETC_width-1 -: ETC_width];
	end
end
/**************Tasks and Functions******************************/
task init_weight_this_layer;
	for(int i = 0; i < 3*3*512*512; i ++ ) begin
		weights_this_layer[i] = 0;
	end
endtask
task init_ACCFIFO;
	add_zero = 1;
	for(int i = 0; i < 32; i++) begin
		ACCFIFO_write = 1;
		@(posedge clk);
		ACCFIFO_write = 0;
	end
	for(int i = 0; i < 32; i ++) begin
		ACCFIFO_read = 1;
		@(posedge clk);
		ACCFIFO_read = 0;
	end
endtask


// PE workload generate for depthwise convolution
//PE_workload[x][0] = start_idx, [x][1]=end_idx, [x][2] = out_size, [x][3] = in_size
// end_idx is usable
int PE_workload[16][4];
task compute_pe_col_workload(
    input int num_pe_col,
    input int inp_col_size,
    input int stride, 
    input int kernel_size
);
int outp_col_size;
int per_pe_output_col;
int res;
//clear
for(int i = 0; i < num_pe_col; i++) begin
    for(int j = 0; j < 4; j++) begin
        PE_workload[i][j] = 0;
    end
end
outp_col_size =  ((inp_col_size - kernel_size) /stride ) + 1;
per_pe_output_col = outp_col_size / num_pe_col;
for(int i = 0; i < num_pe_col;i++) begin
    PE_workload[i][2] = per_pe_output_col;
end
res = outp_col_size % per_pe_output_col;
for(int i = 0; i <res; i++) begin
    PE_workload[i][2] = PE_workload[i][2] + 1;
end
PE_workload[0][0] = 0;
PE_workload[0][1] = kernel_size + (PE_workload[0][2]-1)*stride - 1;
PE_workload[0][3] = kernel_size + (PE_workload[0][2]-1)*stride;
for(int i = 1; i < num_pe_col;i++) begin
    PE_workload[i][0] = PE_workload[i-1][1] - (stride==2?0:1);
    PE_workload[i][1] = PE_workload[i][0] + kernel_size + (PE_workload[i][2]-1)*stride-1;
    PE_workload[i][3] = PE_workload[i][1] - PE_workload[i][0] + 1;
end
endtask

function int min(input int a, input int b);
    return a > b ? b : a;
endfunction

//variable for depthwise conv
logic [activation_width-1: 0] dwconv_infm_2d[226*226];
task clear_infm2d_buffer;
    for(int i =0;i<226*226;i++) begin
        dwconv_infm_2d[i] = 0;
    end
endtask
// only load a tile of act row from dwconv_infm_2d
task dwconv_load_act_this_row(
    input int row_idx, 
    input int fm_size,
    input int col_start_idx,
    input int col_end_idx
);
//col_end_idx is usable
act_this_row.delete();
for(int i = col_start_idx; i<=col_end_idx;i++) begin
    act_this_row.push_back({1'b0,dwconv_infm_2d[row_idx*fm_size + i]}); //1'b0 is the zero_indicator, always let it be 0 because no compress
end
endtask
// the conv process for depthwise convolution
task dw_conv_one_layer(
    input int layer_idx, 
    input int nb_ch,
    input int kSize,
    input int stride,
    input int fm_size,
    input int nb_pe_row,
	input int nb_pe_col,
	input int n_ap,
	input int quantized_bits
);
int base_row;
int act_row_idx_for_this_pe;
int end_row_idx;
int num_convolved_rows;
// Not implemented now!
if(stride!=1) begin
    return;
end
//after this call, the PE_workload vairable is set for each PE column to find the correct col idx in an input row
compute_pe_col_workload(nb_pe_col, fm_size, stride, kernel_size);

for(int out_ch_idx = 0; out_ch_idx < nb_ch; out_ch_idx++)begin
    dwconv_load_act_this_ch_from_file(layer_idx, out_ch_idx); //need to be implemented
    for(int tiled_row_start = 0; tiled_row_start<fm_size;tiled_row_start = tiled_row_start+nb_pe_row*stride) begin
        end_row_idx = min(tiled_row_start + (nb_pe_row-1)*stride + kernel_size, fm_size);
        num_convolved_rows = end_row_idx - tiled_row_start;
        for(int PE_row_idx = 0; PE_row_idx < nb_pe_row;PE_row_idx++) begin
            for(int PE_col_idx = 0; PE_col_idx < nb_pe_col; PE_col_idx++) begin
                //sample rate 1/256
                if(({$random(seed)}%(255-0+1)+0) == 222) begin
                    for(int krow=0;krow<kernel_size;krow++) begin
                        fork 
                            load_WRegs(
                                layer_idx, 
                                out_ch_idx,//co
                                0,//ci
                                krow,//k_row,
                                1, //nb_ci
                                kernel_size,
                                n_ap
                            );
                            WBuff_RW_procedure(kernel_size);
                        join
                        // skip if all weights in this row are zero
                        if(WETCs == 0) begin
                            continue;
                        end
                        // weights are not all zero
                        base_row = tiled_row_start + krow;
                        act_row_idx_for_this_pe = base_row + PE_row_idx;
                        // continue if out of range
                        if(act_row_idx_for_this_pe >= fm_size || PE_workload[PE_col_idx][2]==0) begin
                            continue;
                        end
                        // only load to the act_this_row, not a hardware task
                        dwconv_load_act_this_row(
                            act_row_idx_for_this_pe, 
                            fm_size,
                            PE_workload[PE_col_idx][0],//start_idx
                            PE_workload[PE_col_idx][1]
                        );
                        fork
                            begin:PE_computing
                                first_acc_flag = krow==0 ? 1:0;
                                PE_conv_one_row(
                                    n_ap,
                                    quantized_bits, 
                                    kernel_size
                                );
                                if(krow==kernel_size-1) begin
                                    fork
                                        read_output_fr_pe();
                                        AccBuff_RW_procedure(fm_size);
                                    join
                                end
                            end:PE_computing
                            begin:ActBuff_Fetching
                                ActBuff_RW_procedure();
                            end:ActBuff_Fetching
                        join

                    end
                end
            end
        end
    end
end
endtask

task conv_one_layer(
	input int layer_idx,
	input int nb_cin,
	input int nb_cout,
	input int kSize,
	input int stride,
	input int fm_size,
	input int nb_pe_row,
	input int nb_pe_col,
	input int n_ap,
	input int quantized_bits
);
	int start_time, end_time;
	load_weights_this_layer_from_file(layer_idx);
	
	//only tile the rows of feature maps, tiling of columns needs dealing with
	//the accfifo in PE and the data representation, which is troublesome...
	//after the second layer of Alex all fm are smaller than 32, so we can
	//just do power analysis in 2-5layer
	for(int tiled_start_row = 0; tiled_start_row < fm_size; tiled_start_row += nb_pe_row) begin
		for(int cin_start_idx=0;cin_start_idx < nb_cin; cin_start_idx += 16) begin
				//load_act_buffer_banks_for_16_ch()//load 16 in channels of one row per bank and then output, 
				for(int cout_start_idx = 0; cout_start_idx < nb_cout; cout_start_idx += nb_pe_col) begin
					for(int pe_col_idx = 0; pe_col_idx < nb_pe_col; pe_col_idx++) begin//should be par for
						for(int pe_row_idx=0;pe_row_idx<nb_pe_row; pe_row_idx++) begin//should be par for
							if(({$random(seed)}%(255-0+1)+0) == 222) begin//only compute part of the mapping for time saving
								for(int cin_inner_group_idx=0;cin_inner_group_idx< 16;cin_inner_group_idx++) begin//for the actbuffer size of 16 cin
								//read_fr_one_weight_buffer_bank;
									for(int kernel_row=0;kernel_row < kernel_size; kernel_row ++) begin
										start_time = $time;
										load_WRegs(
											layer_idx, 
											cout_start_idx+pe_col_idx,
											cin_start_idx+ cin_inner_group_idx, 
											kernel_row,
											nb_cin, 
											kernel_size, 
											n_ap
										);
										//stall when all weights are zeros
										if(WETCs == 0) begin
											fork
												for(int tt = 0; tt < fm_size_per_layer[layer_idx]; tt ++) begin
													@(posedge clk);
												end
												WBuff_RW_procedure(kernel_size);
											join
											continue;
										end
										else if((tiled_start_row + pe_row_idx + kernel_row) < fm_size) begin//only when there has fm rows
											load_act_this_row_from_file(
												layer_idx,
												cin_start_idx + cin_inner_group_idx,
												tiled_start_row + pe_row_idx+kernel_row
											);

											fork
												begin
													WBuff_RW_procedure(kernel_size);
												end
												begin//PE computing
													first_acc_flag = cin_inner_group_idx == 0 && kernel_row == 0 ? 1 : 0;
													//first_acc_flag = 1;//always 1 to ensure no x state
													PE_conv_one_row(
														n_ap,
														quantized_bits,
														kernel_size
													);//write AFIFO, read AFIFO, and then compute
													if(cin_inner_group_idx == 15 && kernel_row == kernel_size-1) begin
														fork
															read_output_fr_pe();
															AccBuff_RW_procedure(fm_size);
														join
														
													end
												end
												begin//ActBuff Fetching
													ActBuff_RW_procedure();
												end
											join
										end
									end
								end
							end
						end
					//collect_pe_out_and_write_out_buffer;//write results for nb_pe_col cout channels and nb_pe_rows
					end
				end
		end
	end

endtask
task AccBuff_RW_procedure(
	input int fm_size
);
	//random write and read
	for(int t = 0; t< fm_size-1; t++) begin
		AccBuff_data_in = $random(seed)%32768;//out_to_right_PE;//$random(seed);
		AccBuff_wEn_AH = 1;
		AccBuff_wAddr = t;
		AccBuff_rEn_AH = 1;
		AccBuff_rAddr = t + 1;
		@(posedge clk);
	end
	AccBuff_rEn_AH = 0;
	AccBuff_data_in = $random(seed);
	AccBuff_wEn_AH = 1;
	@(posedge clk);
	
	AccBuff_rEn_AH = 0;
	AccBuff_wEn_AH = 0;
endtask

task init_AccBuff;
	for(int t = 0; t < 32; t++) begin
		AccBuff_data_in = 0;
		AccBuff_wEn_AH = 1;
		AccBuff_wAddr = t;
		adder_src_sel = 1;
		@(posedge clk);		
	end
	//prevent x
	AccBuff_rAddr = 0;
	AccBuff_wEn_AH = 0;
	AccBuff_rEn_AH = 1;
	@(posedge clk);
	AccBuff_rEn_AH = 0;
	adder_src_sel = 0;
	AccBuff_rEn_AH = 0;
endtask


task WBuff_RW_procedure(
	input int ksize
);
//each weight of a certain cin, will be shared by 2xnb_pe_row pes at a time in
//one tiling(????), so it is 50% possibility to be write to the WBuff
for(int i = 0; i < ksize; i ++) begin
	//if({$random(seed)}%2== 0) begin//random for only one time WBuff write in a tile
		if( ({$random(seed)} % 16) < weight_quantized_bits) begin//random for weight quanbits variability
			WBuff_wAddr = i;
			WBuff_data_in = WRegs[(i+1)*weight_width-1 -: weight_width];
			WBuff_wEn_AH =1;
			@(posedge clk);
		end
	//end
end
WBuff_wEn_AH = 0;

for(int i = 0; i < ksize; i ++ ) begin
	if(({$random(seed)}%16) < weight_quantized_bits) begin
		WBuff_rAddr = i;
		WBuff_rEn_AH = 1;
		@(posedge clk);
		WBuff_rEn_AH = 0;
		WBuff_weight_load_en = 0;
		WBuff_weight_load_en[i] = 1;
		@(posedge clk);
		WBuff_weight_load_en = 0;
	end
end
WBuff_rEn_AH = 0;
WBuff_weight_load_en = 0;


endtask
task init_WBuff();
	//so that it will not read x out
	for(int t=0;t<nb_taps; t++) begin
		WBuff_wAddr = t;
		WBuff_wEn_AH = 1;
		WBuff_data_in = 0;
		@(posedge clk);
	end
	WBuff_wEn_AH = 0;
	WBuff_rAddr = 0;
	WBuff_rEn_AH = 1;
	@(posedge clk);
	WBuff_rEn_AH = 0;
endtask
task ActBuff_RW_procedure();
	int act_this_row_size;
	act_this_row_size = act_this_row.size();
	ActBuff_rEn_AH = 0;
	foreach(act_this_row[t]) begin
		if(act_quantized_bits > 8) begin
			//write and read
			ActBuff_wEn_AH = 1;
			ActBufferIn = act_this_row[t];
			ActBuff_wAddr = t;
			@(posedge clk);
			ActBuff_wEn_AH = 0;
			ActBuff_rEn_AH = 1;
			ActBuff_rAddr = t;
			@(posedge clk);
			ActBuff_rEn_AH = 0;
		end
		else begin
			if($random(seed)%2 == 0) begin//half of the probability to fetch data
				//write and read
				ActBuff_wEn_AH = 1;
				ActBufferIn = act_this_row[t];
				ActBuff_wAddr = t;
				@(posedge clk);
				ActBuff_wEn_AH = 0;
				ActBuff_rEn_AH = 1;
				ActBuff_rAddr = t;
				@(posedge clk);
				ActBuff_rEn_AH = 0;
			end
		end
	end
	ActBuff_rEn_AH = 0;
	ActBuff_wEn_AH = 0;
endtask


task read_output_fr_pe;
	ACCFIFO_read = 1;
	out_mux_sel_PE = 0;
	@(posedge clk);
	#1;
	while(ACCFIFO_empty != 1) begin
		ACCFIFO_read = 1;
		out_to_right_pe_en = 1;
		@(posedge clk);
		#1;
	end
	ACCFIFO_read = 0;
	out_to_right_pe_en = 1;
	@(posedge clk);
	out_to_right_pe_en = 0;
	
	
endtask

task PE_conv_one_row(
	input int n_ap,
	input int quantized_bits,
	input int kernel_size
);
	int act_row_length;
	act_row_length = act_this_row.size();

	ACCFIFO_write = 0;
	AFIFO_read = 0;
	ACCFIFO_read = 0;
	AFIFO_write = 1;
	compressed_act_in = act_this_row[0];
	@(posedge clk);
	foreach(act_this_row[i]) begin
		if(i == 0) begin
			continue;
		end
		else begin
			AFIFO_read = 1;
			compressed_act_in = act_this_row[i];
			AFIFO_write = 1;
			//$display("the %2d-th act is 0x%x",i, act_this_row[i]);
			@(posedge clk);
			ACCFIFO_write = 0;
			AFIFO_read = 0;
			AFIFO_write = 0;
			#1;
			//now the output of afifo is gotten
			fork
				FoFIR_update_one_time_task(
					afifo_out[activation_width-1: 0],
					afifo_out[compressed_act_width-1],
					WRegs,
					n_ap,
					quantized_bits,
					kernel_size,
					PAMAC_MDecomp,
					PAMAC_AWDecomp
				);
				ACCFIFO_pre_read_when_computing;
			join
			ACCFIFO_write = 1;
		end
	end
	//processing the last fedded act to the AFIFO
	AFIFO_read = 1;
	@(posedge clk);
	ACCFIFO_write = 0;
	AFIFO_read = 0;
	#1;
	//now the output of afifo is gotten
	fork
		FoFIR_update_one_time_task(
			afifo_out[activation_width-1: 0],
			afifo_out[compressed_act_width-1],
			WRegs,
			n_ap,
			quantized_bits,
			kernel_size,
			PAMAC_MDecomp,
			PAMAC_AWDecomp
		);
		ACCFIFO_pre_read_when_computing;
	join
	ACCFIFO_write = 1;
	@(posedge clk);
	ACCFIFO_write = 0;
	AFIFO_read = 0;
	AFIFO_write = 0;
	ACCFIFO_read = 0;

endtask


task dwconv_load_act_this_ch_from_file(
    input int layer_idx,
    input int ch_idx
);
    string file_name, file_path, model_name,layer_idx_str, full_path, ch_str;
    logic [activation_width-1: 0] r;
    int n;
    int fp;
    int pix;
    //dwconv_infm_2d
    layer_idx_str.itoa(layer_idx);
    ch_str.itoa(ch_idx);
    model_name = "mobilenet";
    file_path = {"../testbench/test_data/", model_name, "/act_conv_", layer_idx_str, "_dw/"};
    file_name = {"act_dump_ch", ch_str,".dat"};
    full_path = {file_path, file_name};
    $display("@%t, The depthwise conv file name is %s", $time, full_path);
    fp = $fopen(full_path, "r");
    pix = 0;
    while(!$feof(fp)) begin
        n = $fscanf(fp, "%x\n", r);
        dwconv_infm_2d[pix] = r;
        pix++;
    end
endtask
task load_act_this_row_from_file(
	input int layer_idx, 
	input int ch_idx,
	input int row_idx
);
	string file_name, file_path, model_name, layer_idx_str, full_path, ch_str, row_str;
	logic [compressed_act_width-1: 0] r;
	int n;
	int fp;
	act_this_row.delete();
	layer_idx_str.itoa(layer_idx);
	ch_str.itoa(ch_idx);
	row_str.itoa(row_idx);
	model_name = "mobilenet";
	file_path = {"../testbench/test_data/",model_name, "/act_conv_", layer_idx_str, "/"};
	file_name = {"act_dump_ch", ch_str, "_row", row_str, ".dat"};
	full_path = {file_path, file_name};
	$display("@%t, The act row file name is %s.", $time, full_path);
	fp = $fopen(full_path, "r");
	while(!$feof(fp)) begin
		n = $fscanf(fp, "%x\n", r);
		act_this_row.push_back(r);
	end
	$fclose(fp);
	
endtask
task load_weights_this_layer_from_file(input int layer_idx);
	string file_name, file_path, model_name, layer_idx_str, full_path;
	model_name = "mobilenet";
	file_path = {"../testbench/test_data/",model_name, "weights/"};
	layer_idx_str.itoa(layer_idx);
	file_name = {"conv_", layer_idx_str, "_weight.dat"};
	full_path = {file_path, file_name};
	$display("The weight file name is %s.", full_path);
	$readmemh(full_path, weights_this_layer);
endtask

function [16-1: 0] find_weight(input int co, input int ci, input int kH, input int kW, 
								input int nb_ci, input int kernel_size
);
begin
	return weights_this_layer[
		kW +
		kH * kernel_size +
		ci * (kernel_size*kernel_size) + 
		co * (kernel_size*kernel_size*nb_ci)
	];
end
endfunction

task load_WRegs(
	input int layer_idx,
	input int co,
	input int ci,
	input int k_row,
	input int nb_ci,
	input int kernel_size,
	input logic [4-1: 0] n_ap
);
WRegs = 0;
WBPRs = 0;
WETCs = 0;
for(int i = 0; i < kernel_size; i ++ ) begin
	WRegs[(i+1)*weight_width -: weight_width] = find_weight(co, ci, k_row, i, nb_ci, kernel_size );
	BPEB_Enc_task( WRegs[(i+1)*weight_width -: weight_width],
				   n_ap,
				   WBPRs[(i+1)*weight_bpr_width -: weight_bpr_width],
				   WETCs[(i+1)*ETC_width -: ETC_width]
	);
end
endtask

task ACCFIFO_pre_read_when_computing;
begin
	//ACCFIFO_read = 1;//because the first time need not to read
	if(afifo_out[compressed_act_width-1] == 0) begin
		//not a zero act
		ACCFIFO_read = first_acc_flag ? 0:1;
		@(posedge clk);
		ACCFIFO_read = 0;
	end
	else begin
		//zero activation
		temp = afifo_out[activation_width-1-1: 0] < kernel_size ?
			afifo_out[activation_width-1-1: 0] : kernel_size;
		for(int tt = 0; tt<temp;tt++) begin//
			#1;
			if(valid_result_trig == 1) begin
				ACCFIFO_read = first_acc_flag ? 0 : 1;
				add_zero = first_acc_flag ? 1:0;
			end
			else begin
				ACCFIFO_read = first_acc_flag ? 0 : 1;
				add_zero = first_acc_flag ? 1:0;
				$display("@%t, the valid trig should be 1 but not meet", $time);
			end
			@(posedge clk);
			ACCFIFO_write = 1;
		end
		ACCFIFO_write = 0;
	end
end
endtask

task init_random_weights; 
begin
reg [ETC_width-1: 0] WETC_temp;
reg [weight_bpr_width-1: 0] WBPR_temp;
reg [weight_width-1: 0] weight_temp;
for(int i = 0; i < nb_taps; i++) begin
	weight_temp = $random(seed);
	if(weight_temp[0] == 0) begin
		WRegs[(i+1)*weight_width-1 -: weight_width] = $random(seed) % 255;
	end
	else begin
		WRegs[(i+1)*weight_width-1 -: weight_width] = 0;
	end
	//WRegs[(nb_taps)*weight_width-1 -: weight_width] = $random(seed) % 255; //the last tap forced to be nonzero to make it work as TrFIR
	weight_temp = WRegs[(i+1)*weight_width-1 -: weight_width];
	BPEB_Enc_task( weight_temp,
				   n_ap,
				   WBPR_temp,
				   WETC_temp
	);
	WBPRs[(i+1)*weight_bpr_width-1 -: weight_bpr_width] = WBPR_temp;
	WETCs[(i+1)*ETC_width-1 -: ETC_width] = WETC_temp;
	//$display("weight_temp = 0x%x, WBPR_temp = 0x%x,ETC_temp = 0x%x", weight_temp, WBPR_temp, WETC_temp);
end

end
endtask
task init_fix_weights(input int n_ap);
begin
reg [ETC_width-1: 0] WETC_temp;
reg [weight_bpr_width-1: 0] WBPR_temp;
reg [weight_width-1: 0] weight_temp;
WRegs = 0;
WRegs[(weight_width-1) -: weight_width] = 1;
for(int i = 0; i < nb_taps; i++) begin
	weight_temp = WRegs[(i+1)*weight_width-1 -: weight_width];
	BPEB_Enc_task( weight_temp,
				   n_ap,
				   WBPR_temp,
				   WETC_temp
	);
	WBPRs[(i+1)*weight_bpr_width-1 -: weight_bpr_width] = WBPR_temp;
	WETCs[(i+1)*ETC_width-1 -: ETC_width] = WETC_temp;

end
end
endtask

`include "../testbench/BPEB_Enc_task.sv"
task PAMAC_compute_ctrl_task_new(
	input [8*3-1: 0] BPR,
	input [5-1: 0] quantized_bits,
	input [4-1: 0]n_ap
);
begin
	int t;
	int n_ap_int;
	reg unsigned [4-1:0] i;
	reg unsigned [4-1: 0] half_n;
	reg V[8];
	int ETC;
	int last_essential_term_idx;
	last_essential_term_idx = -1;
	i = 0;
	//finish = 0;
	n_ap_int = n_ap;
	//initialize
	PAMAC_DFF_en = 0;
	PAMAC_BPEB_sel = 0;
	half_n = (quantized_bits + 1)/2;
	for(i = 0; i< 8; i++) begin
		V[i] = 0;
	end
	//value encoding
	for(i=0; i < half_n; i=i+1) begin
		case(BPR[3*(i+1)-1 -: 3])
			3'b000, 3'b111:begin
				V[i] = 0;
			end
			default:begin
				//this module dont care whether Vi is 1 or 2 or -1 or -2, 
				//so uniformly represent as 1
				V[i] = 1;
				if(last_essential_term_idx == -1 && i >= n_ap_int) begin
					last_essential_term_idx = i;
				end
			end
		endcase
		if(i<n_ap_int) begin
			V[i] = 0;
		end
	end
	ETC = 0;
	for(i = 0; i < half_n; i++) begin
		if(V[i] == 1) begin
			ETC = ETC +  1;
		end
	end
	//start multi-cycle-computation
	PAMAC_first_cycle = 1;
	for(t = half_n-1; t >= 0; t--) begin
		if(V[t] == 1) begin
			PAMAC_DFF_en = 1;
			PAMAC_BPEB_sel = t;
			if(t > last_essential_term_idx) begin
				@(posedge clk);	//wait for the posedge except for the last cycle
				PAMAC_first_cycle = 0;
			end
		end
		else begin
			;
		end
	end
	PAMAC_first_cycle = ETC==1 ? 1 : 0;
	PAMAC_DFF_en = 0;

end
endtask

task static FoFIR_update_one_time_task(
	input [activation_width-1: 0] act_value,
	input is_zero_act,
	input [weight_width*nb_taps-1: 0] WRegs,
	input [4-1: 0] n_ap,
	input [5-1: 0] quantized_bits,
	//input [width_current_tap-1: 0] PD0,
	input int kernel_size,
	input is_MDecomp,
	input AW_Decomp
);
begin
	reg [ETC_width-1: 0] WETCs[nb_taps];
	reg [ETC_width-1: 0] ETC_A;
	reg [act_bpr_width-1: 0] BPR_A;
	reg [weight_bpr_width-1: 0] WBPRs[nb_taps];
	reg first_tap;
	int wetc_sum;
	int nb_effective_tap;
	reg [width_current_tap-1: 0] next_tap;
	int nb_zero_act;
	int nb_zero_cycle;
	reg [weight_bpr_width-1:0] BPR_for_PAMAC_ctrl;
	
	valid_result_trig = 0;
	wetc_sum = 0;
	//init the control signal
	DRegs_en = 0;
	DRegs_clr = 0;
	DRegs_in_sel = 0;
	index_update_en = 0;
	out_mux_sel = 0;
	out_reg_en = 0;

	for(int i=0; i < nb_taps; i++) begin
		BPEB_Enc_task(WRegs[(i+1)*weight_width-1 -: weight_width], n_ap, WBPRs[i], WETCs[i]);
		//$display("In ctrl function, Weights = 0x%x, WBPRs = 0x%x, WTCs=0x%x",WRegs[(i+1)*weight_width-1 -: weight_width], WBPRs[i], WETCs[i]);
	end
	//deal with all zero taps
	for(int i=0; i< nb_taps; i++) begin
		wetc_sum += WETCs[i];
	end
	if(wetc_sum == 0) begin
		$display("All taps are ineffective!");
		out_mux_sel = 1;
		current_tap = 0;
		out_reg_en = 1;
		@(posedge clk);
		out_mux_sel = 0;
		out_reg_en = 0;
		return;
	end
	
	//The ETC may be zero when n_ap > 0
	BPEB_Enc_task(act_value, n_ap, BPR_A, ETC_A);


	if(is_zero_act === 0 && ETC_A > 0) begin
		//an effective value
		
		//Make a queue to store the effective taps
		automatic int  effective_tap_index[$] = {};//use a queue to store the effective taps
		for(int tap_idx = nb_taps-1; tap_idx >=0; tap_idx--) begin
			if(WETCs[tap_idx] > 0) begin
				effective_tap_index.push_back(tap_idx);
				nb_effective_tap += 1;
			end
		end
		#1;//wait for PD0
		foreach(effective_tap_index[i]) begin
			//i == 0 indicates the first non-zero tap, that should be output
			current_tap = effective_tap_index[i];
			if(is_MDecomp === 1) begin
				BPR_for_PAMAC_ctrl = ETC_A > WETCs[current_tap] ? WBPRs[current_tap]: BPR_A;
			end
			else if(is_MDecomp === 0 && AW_Decomp === 1) begin
				//weight decomp
				BPR_for_PAMAC_ctrl = WBPRs[current_tap];
			end
			else if(is_MDecomp ===0 && AW_Decomp ===0) begin
				BPR_for_PAMAC_ctrl = BPR_A;
			end
			else begin
				$display("Error! non of MDecomp,AWDecomp is used!");
				$stop;
			end
			//compute
			PAMAC_compute_ctrl_task_new(BPR_for_PAMAC_ctrl, quantized_bits, n_ap);
			//now the results is in the out port of PAMAC
			out_reg_en = i == 0 ? 1 : 0;//if the first tap, save to output reg
			out_mux_sel = 0;
			//save the results to the right register, only if it has right
			//register
			DRegs_en = 0;
			if((current_tap + 1 < nb_taps) && (current_tap+1 <kernel_size) && i != 0) begin
				DRegs_en[(PD0+current_tap+1)%nb_taps] = 1;
				DRegs_in_sel[(current_tap+PD0+1)%nb_taps] = 1;//update by the PAMAC output
			end
			//the left registers of the current taps should update in the same
			//cycle
			if(i == nb_effective_tap -1) begin
				//the last effective tap, left of it should all be updated
				//with zero
				for(int t=0; t <= current_tap; t++) begin
					DRegs_clr[(t+PD0)%nb_taps] = 1;
				end
			end
			else begin
				next_tap = effective_tap_index[i+1];//have a peep for the next tap
				for(int t=next_tap+1; t <= current_tap; t++) begin
					DRegs_en[(PD0+t)%nb_taps] = DRegs_clr[(t+PD0)%nb_taps] == 1 ? 0 : 1;
					DRegs_in_sel[(PD0+t)%nb_taps] = 0;//updated by the left
				end
			end
			if(i == (nb_effective_tap -1)) 
				valid_result_trig = 1;
			else 
				valid_result_trig = 0;
			@(posedge clk);
			out_reg_en = 0;
			DRegs_in_sel = 0;
			DRegs_clr = 0;
			DRegs_en = 0;
		end

	end
	else if(is_zero_act === 1 || ETC_A == 0) begin
		//a zero activation input, the act_value is of no use
		out_mux_sel = 1;
		out_reg_en = 1;
		nb_zero_act = is_zero_act ? act_value : 1;//this zero act may from zero ETC by approximate computing
		nb_zero_cycle = nb_zero_act >= kernel_size ? kernel_size : nb_zero_act;
		if(nb_zero_cycle == kernel_size) begin
			for(int i=kernel_size-1;i >= 0; i--) begin
				current_tap = i;
				valid_result_trig = 1;
				DRegs_clr = i == 0 ? {nb_taps{1'b1}} : 0;//clear all regs after the last cycle
				@(posedge clk);
			end
		end
		else begin
			//less than kernel_size zeros
			for(int i = 0;i<nb_zero_cycle;i++) begin
				index_update_en = 1;
				current_tap = kernel_size - 1;//output the righest register, but should according to the kernel size, otherwise, it equals a FIR filter with multiple delay element in the output if the n_tap > kernel size
				//DRegs_en = {nb_taps{1'b1}};//shift is not required
				DRegs_en = 0;
				//DRegs_en[PD0] = 0;//the D0 should be cleared
				DRegs_in_sel = 0;//from left registers
				#1;//wait for the PD0 update
				DRegs_clr = 0;
				DRegs_clr[(PD0+kernel_size-1)%nb_taps] = 1;
				valid_result_trig = 1;
				@(posedge clk);
			end
		end
		
	end
	else begin
		$display("error! is_zero_act is not 1 or 0");
	end
	DRegs_clr = 0;
	DRegs_en = 0;
	index_update_en = 0;
	out_reg_en = 0;
	out_mux_sel = 0;
	valid_result_trig = 0;

end
endtask
/*************Helper register********************************/
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		valid_result <= 0;
	end
	else if(valid_result_trig) begin
		valid_result <= 1;
	end
	else begin
		valid_result <= 0;
	end
end
initial begin
	string file_name, seed_str, n_ap_str, act_qb_str, weight_qb_str;
	#1;
	seed_str.itoa(seed);
	n_ap_str.itoa(n_ap);
	act_qb_str.itoa(act_quantized_bits);
	weight_qb_str.itoa(weight_quantized_bits);
    file_name = {"AllBuffers_nap", n_ap_str, "_actqb", act_qb_str, "_wqb", weight_qb_str, ".vcd"};
    if(dump_vcd) begin
        $dumpfile(file_name);
        $dumpvars;
    end
end
initial begin
	#50;
	//$dumpon;
	//#8000;
	//$dumpoff;
	//$dumpoff;
	//$finish;
end

endmodule
