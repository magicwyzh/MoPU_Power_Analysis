`timescale 1ns/1ns
module AllBuffers_for_power_analysis #(parameter
	nb_taps = 11,
	weight_width = 16,
	activation_width = 16,
	tap_width = 24,
	compressed_act_width = activation_width + 1,
	weight_bpr_width = ((weight_width+1)/2)*3,
	act_bpr_width = ((activation_width+1)/2)*3,
	ETC_width = 4,
	output_width = tap_width,
	nb_actbuff = 8,
	nb_wbuff = 32,
	nb_accbuff = 8
)(
	input ActBuff_wEn_AH, ActBuff_rEn_AH,

	input [10-1: 0] ActBuff_wAddr, ActBuff_rAddr,
	output [nb_accbuff*17-1: 0] ActBufferOut,
	input [17-1: 0] ActBufferIn,

	output [nb_wbuff*nb_taps * weight_width - 1: 0] WBuff_WRegs,
	output [nb_wbuff*nb_taps * weight_bpr_width - 1: 0] WBuff_WBPRs,
	output [nb_wbuff*nb_taps * ETC_width - 1: 0] WBuff_WETCs,
	input [nb_taps-1: 0] WBuff_weight_load_en,
	input [7-1: 0] WBuff_wAddr, WBuff_rAddr,
	input [16-1: 0] WBuff_data_in,
	input WBuff_wEn_AH, WBuff_rEn_AH,

	input [24-1: 0] AccBuff_data_in,
	input [13-1: 0] AccBuff_wAddr, AccBuff_rAddr,
	input AccBuff_wEn_AH, AccBuff_rEn_AH,
	output [nb_accbuff*16-1: 0]AccBuff_data_out,
	input acc_adder_src_sel,

	input clk, rst_n,
	input [4-1: 0] n_ap
);


/**************ACC BUFF Instances*************/
acc_out_buffer_bank #(
    .pe_out_width                   ( 24                            ),

    .buffer_width                   ( 16                            ),

    .buffer_depth                   ( 8192                          ))

U_ACC_OUT_BUFFER_BANK_0(

    .out_fr_pe                      ( AccBuff_data_in                     ),

    .wAddr                          ( AccBuff_wAddr                         ),

    .rAddr                          ( AccBuff_rAddr                         ),

    .wEn                            ( ~AccBuff_wEn_AH                           ),

    .rEn                            ( ~AccBuff_rEn_AH                           ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

	.buffer_out                     ( AccBuff_data_out[16-1 -: 16] ),
.adder_src_sel					( acc_adder_src_sel)
);

acc_out_buffer_bank #(
    .pe_out_width                   ( 24                            ),

    .buffer_width                   ( 16                            ),

    .buffer_depth                   ( 8192                          ))

U_ACC_OUT_BUFFER_BANK_1(

    .out_fr_pe                      ( AccBuff_data_in                     ),

    .wAddr                          ( AccBuff_wAddr                         ),

    .rAddr                          ( AccBuff_rAddr                         ),

    .wEn                            ( ~AccBuff_wEn_AH                           ),

    .rEn                            ( ~AccBuff_rEn_AH                           ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

	.buffer_out                     ( AccBuff_data_out[32-1 -: 16] ),
.adder_src_sel					( acc_adder_src_sel)
);

acc_out_buffer_bank #(
    .pe_out_width                   ( 24                            ),

    .buffer_width                   ( 16                            ),

    .buffer_depth                   ( 8192                          ))

U_ACC_OUT_BUFFER_BANK_2(

    .out_fr_pe                      ( AccBuff_data_in                     ),

    .wAddr                          ( AccBuff_wAddr                         ),

    .rAddr                          ( AccBuff_rAddr                         ),

    .wEn                            ( ~AccBuff_wEn_AH                           ),

    .rEn                            ( ~AccBuff_rEn_AH                           ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

	.buffer_out                     ( AccBuff_data_out[48-1 -: 16] ),
.adder_src_sel					( acc_adder_src_sel)
);

acc_out_buffer_bank #(
    .pe_out_width                   ( 24                            ),

    .buffer_width                   ( 16                            ),

    .buffer_depth                   ( 8192                          ))

U_ACC_OUT_BUFFER_BANK_3(

    .out_fr_pe                      ( AccBuff_data_in                     ),

    .wAddr                          ( AccBuff_wAddr                         ),

    .rAddr                          ( AccBuff_rAddr                         ),

    .wEn                            ( ~AccBuff_wEn_AH                           ),

    .rEn                            ( ~AccBuff_rEn_AH                           ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

	.buffer_out                     ( AccBuff_data_out[64-1 -: 16] ),
.adder_src_sel					( acc_adder_src_sel)
);

acc_out_buffer_bank #(
    .pe_out_width                   ( 24                            ),

    .buffer_width                   ( 16                            ),

    .buffer_depth                   ( 8192                          ))

U_ACC_OUT_BUFFER_BANK_4(

    .out_fr_pe                      ( AccBuff_data_in                     ),

    .wAddr                          ( AccBuff_wAddr                         ),

    .rAddr                          ( AccBuff_rAddr                         ),

    .wEn                            ( ~AccBuff_wEn_AH                           ),

    .rEn                            ( ~AccBuff_rEn_AH                           ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

	.buffer_out                     ( AccBuff_data_out[80-1 -: 16] ),
.adder_src_sel					( acc_adder_src_sel)
);

acc_out_buffer_bank #(
    .pe_out_width                   ( 24                            ),

    .buffer_width                   ( 16                            ),

    .buffer_depth                   ( 8192                          ))

U_ACC_OUT_BUFFER_BANK_5(

    .out_fr_pe                      ( AccBuff_data_in                     ),

    .wAddr                          ( AccBuff_wAddr                         ),

    .rAddr                          ( AccBuff_rAddr                         ),

    .wEn                            ( ~AccBuff_wEn_AH                           ),

    .rEn                            ( ~AccBuff_rEn_AH                           ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

	.buffer_out                     ( AccBuff_data_out[96-1 -: 16] ),
.adder_src_sel					( acc_adder_src_sel)
);

acc_out_buffer_bank #(
    .pe_out_width                   ( 24                            ),

    .buffer_width                   ( 16                            ),

    .buffer_depth                   ( 8192                          ))

U_ACC_OUT_BUFFER_BANK_6(

    .out_fr_pe                      ( AccBuff_data_in                     ),

    .wAddr                          ( AccBuff_wAddr                         ),

    .rAddr                          ( AccBuff_rAddr                         ),

    .wEn                            ( ~AccBuff_wEn_AH                           ),

    .rEn                            ( ~AccBuff_rEn_AH                           ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

	.buffer_out                     ( AccBuff_data_out[112-1 -: 16] ),
.adder_src_sel					( acc_adder_src_sel)
);

acc_out_buffer_bank #(
    .pe_out_width                   ( 24                            ),

    .buffer_width                   ( 16                            ),

    .buffer_depth                   ( 8192                          ))

U_ACC_OUT_BUFFER_BANK_7(

    .out_fr_pe                      ( AccBuff_data_in                     ),

    .wAddr                          ( AccBuff_wAddr                         ),

    .rAddr                          ( AccBuff_rAddr                         ),

    .wEn                            ( ~AccBuff_wEn_AH                           ),

    .rEn                            ( ~AccBuff_rEn_AH                           ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

	.buffer_out                     ( AccBuff_data_out[128-1 -: 16] ),
.adder_src_sel					( acc_adder_src_sel)
);

/**************WEIGHT BUFF Instances*************/
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_0(

		
		.WRegs                          ( WBuff_WRegs[1*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[1*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[1*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_1(

		
		.WRegs                          ( WBuff_WRegs[2*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[2*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[2*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_2(

		
		.WRegs                          ( WBuff_WRegs[3*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[3*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[3*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_3(

		
		.WRegs                          ( WBuff_WRegs[4*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[4*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[4*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_4(

		
		.WRegs                          ( WBuff_WRegs[5*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[5*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[5*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_5(

		
		.WRegs                          ( WBuff_WRegs[6*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[6*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[6*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_6(

		
		.WRegs                          ( WBuff_WRegs[7*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[7*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[7*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_7(

		
		.WRegs                          ( WBuff_WRegs[8*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[8*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[8*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_8(

		
		.WRegs                          ( WBuff_WRegs[9*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[9*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[9*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_9(

		
		.WRegs                          ( WBuff_WRegs[10*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[10*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[10*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_10(

		
		.WRegs                          ( WBuff_WRegs[11*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[11*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[11*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_11(

		
		.WRegs                          ( WBuff_WRegs[12*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[12*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[12*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_12(

		
		.WRegs                          ( WBuff_WRegs[13*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[13*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[13*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_13(

		
		.WRegs                          ( WBuff_WRegs[14*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[14*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[14*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_14(

		
		.WRegs                          ( WBuff_WRegs[15*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[15*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[15*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_15(

		
		.WRegs                          ( WBuff_WRegs[16*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[16*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[16*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_16(

		
		.WRegs                          ( WBuff_WRegs[17*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[17*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[17*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_17(

		
		.WRegs                          ( WBuff_WRegs[18*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[18*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[18*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_18(

		
		.WRegs                          ( WBuff_WRegs[19*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[19*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[19*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_19(

		
		.WRegs                          ( WBuff_WRegs[20*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[20*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[20*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_20(

		
		.WRegs                          ( WBuff_WRegs[21*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[21*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[21*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_21(

		
		.WRegs                          ( WBuff_WRegs[22*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[22*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[22*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_22(

		
		.WRegs                          ( WBuff_WRegs[23*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[23*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[23*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_23(

		
		.WRegs                          ( WBuff_WRegs[24*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[24*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[24*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_24(

		
		.WRegs                          ( WBuff_WRegs[25*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[25*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[25*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_25(

		
		.WRegs                          ( WBuff_WRegs[26*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[26*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[26*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_26(

		
		.WRegs                          ( WBuff_WRegs[27*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[27*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[27*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_27(

		
		.WRegs                          ( WBuff_WRegs[28*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[28*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[28*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_28(

		
		.WRegs                          ( WBuff_WRegs[29*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[29*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[29*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_29(

		
		.WRegs                          ( WBuff_WRegs[30*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[30*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[30*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_30(

		
		.WRegs                          ( WBuff_WRegs[31*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[31*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[31*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
weightBuffer_bank #(

		.nb_taps		                ( nb_taps                             ),

		.weight_width                   ( weight_width                           ),

		.ETC_width                      ( ETC_width                             ))

		U_WEIGHTBUFFER_BANK_31(

		
		.WRegs                          ( WBuff_WRegs[32*nb_taps*weight_width-1 -: (nb_taps*weight_width)]               ),

		.WBPRs                          ( WBuff_WBPRs[32*nb_taps*weight_bpr_width-1 -: (nb_taps*weight_bpr_width)]                       ),

	    .WETCs                          ( WBuff_WETCs[32*nb_taps*ETC_width-1 -: (nb_taps*ETC_width)]  ),

	
    .weight_load_en                 ( WBuff_weight_load_en                ),

    .clk                            ( clk                           ),

    .rst_n                          ( rst_n                         ),

    .wAddr                          ( WBuff_wAddr                         ),

    .rAddr                          ( WBuff_rAddr                         ),

    .buffer_data_in                 ( WBuff_data_in                ),

    .buffer_wEn                     ( ~WBuff_wEn_AH                    ),

    .buffer_rEn                     ( ~WBuff_rEn_AH                    ),

    .n_ap                           ( n_ap                          )

);

	
/**************ACT BUFF Instances*************/

TS6N28HPCPHVTA768X17M8F U_ACTBUFFBANK_0(

	.AA(ActBuff_wAddr),

	.D(ActBufferIn),

	.WEB(~ActBuff_wEn_AH),

	.CLKW(clk),

	.AB(ActBuff_rAddr),

	.REB(~ActBuff_rEn_AH),

	.CLKR(clk),

	.Q(ActBufferOut[1*17-1 -: 17])
);


TS6N28HPCPHVTA768X17M8F U_ACTBUFFBANK_1(

	.AA(ActBuff_wAddr),

	.D(ActBufferIn),

	.WEB(~ActBuff_wEn_AH),

	.CLKW(clk),

	.AB(ActBuff_rAddr),

	.REB(~ActBuff_rEn_AH),

	.CLKR(clk),

	.Q(ActBufferOut[2*17-1 -: 17])
);


TS6N28HPCPHVTA768X17M8F U_ACTBUFFBANK_2(

	.AA(ActBuff_wAddr),

	.D(ActBufferIn),

	.WEB(~ActBuff_wEn_AH),

	.CLKW(clk),

	.AB(ActBuff_rAddr),

	.REB(~ActBuff_rEn_AH),

	.CLKR(clk),

	.Q(ActBufferOut[3*17-1 -: 17])
);


TS6N28HPCPHVTA768X17M8F U_ACTBUFFBANK_3(

	.AA(ActBuff_wAddr),

	.D(ActBufferIn),

	.WEB(~ActBuff_wEn_AH),

	.CLKW(clk),

	.AB(ActBuff_rAddr),

	.REB(~ActBuff_rEn_AH),

	.CLKR(clk),

	.Q(ActBufferOut[4*17-1 -: 17])
);


TS6N28HPCPHVTA768X17M8F U_ACTBUFFBANK_4(

	.AA(ActBuff_wAddr),

	.D(ActBufferIn),

	.WEB(~ActBuff_wEn_AH),

	.CLKW(clk),

	.AB(ActBuff_rAddr),

	.REB(~ActBuff_rEn_AH),

	.CLKR(clk),

	.Q(ActBufferOut[5*17-1 -: 17])
);


TS6N28HPCPHVTA768X17M8F U_ACTBUFFBANK_5(

	.AA(ActBuff_wAddr),

	.D(ActBufferIn),

	.WEB(~ActBuff_wEn_AH),

	.CLKW(clk),

	.AB(ActBuff_rAddr),

	.REB(~ActBuff_rEn_AH),

	.CLKR(clk),

	.Q(ActBufferOut[6*17-1 -: 17])
);


TS6N28HPCPHVTA768X17M8F U_ACTBUFFBANK_6(

	.AA(ActBuff_wAddr),

	.D(ActBufferIn),

	.WEB(~ActBuff_wEn_AH),

	.CLKW(clk),

	.AB(ActBuff_rAddr),

	.REB(~ActBuff_rEn_AH),

	.CLKR(clk),

	.Q(ActBufferOut[7*17-1 -: 17])
);


TS6N28HPCPHVTA768X17M8F U_ACTBUFFBANK_7(

	.AA(ActBuff_wAddr),

	.D(ActBufferIn),

	.WEB(~ActBuff_wEn_AH),

	.CLKW(clk),

	.AB(ActBuff_rAddr),

	.REB(~ActBuff_rEn_AH),

	.CLKR(clk),

	.Q(ActBufferOut[8*17-1 -: 17])
);



endmodule
