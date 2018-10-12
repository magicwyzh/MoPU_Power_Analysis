module top #(parameter
	//PE Array parameter
	nb_pe_row = 8,
	nb_pe_col = 32,
	//PE parameter
	AFIFO_size = 8,
	ACCFIFO_size = 32,
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
	pe_out_width = tap_width,
	//act_buff parameters
	act_buff_mem_bank_width = compressed_act_width,
	act_buff_mem_depth = 768,
	act_buff_addr_width = clogb2(act_buff_mem_depth),
	//weight buff parameters
	weight_buff_depth = 72,
	weight_buff_width = 16,
	weight_buff_addr_width = clogb2(weight_buff_depth),
	//obf parameters
	obf_width = 16,
	obf_depth = 8192,
	obf_addr_width = clogb2(obf_depth)
)(
	input clk, rst_n,
	/********PE Array ports***********/
	/***All PEs share the same control for simplicity******/
	//configuration ports
	input [4-1: 0] n_ap,

	//control ports for PAMAC
	input [3-1: 0] PAMAC_BPEB_sel,
	input PAMAC_DFF_en,
	input PAMAC_first_cycle,
	//the following two inputs are reserved 
	input PAMAC_MDecomp,//1 is mulwise, 0 is layerwise
	input PAMAC_AWDecomp,// 0 is act decomp, 1 is w decomp

	//control signals for FoFIR
	input [width_current_tap-1: 0] current_tap,
	//DRegs signals
	input [nb_taps-1: 0] DRegs_en,
	input [nb_taps-1: 0] DRegs_clr,
	input [nb_taps-1: 0] DRegs_in_sel,//0 is from left, 1 is from pamac output
	
	//DRegs indexing signals
	input index_update_en,

	//output signals
	input out_mux_sel,//0 is from PAMAC, 1 is from DRegs
	input out_reg_en,
	//FIFOs
	input AFIFO_write,
	input AFIFO_read,
	input ACCFIFO_write,
	input ACCFIFO_read,
	input ACCFIFO_read_out,
	input ACCFIFO_sel,//double buffer 
	input out_mux_sel_PE,//

	/**********Ports for ActBuffer**************/
	input [nb_pe_row * compressed_act_width-1: 0] act_buff_data_in,
	input act_buff_wEn, act_buff_rEn, 
	input [act_buff_addr_width-1: 0] act_buff_wAddr, act_buff_rAddr,
	/************ports for weight buffer*********/
	input [nb_taps-1: 0] weight_load_en,
	input [weight_buff_addr_width-1: 0] weight_buff_wAddr, weight_buff_rAddr,
	input [nb_pe_col * weight_buff_width-1: 0] weight_buff_data_in,
	input weight_buff_wEn, weight_buff_rEn,
	/********ports for OBF************/
	input [obf_addr_width-1: 0] obf_wAddr, obf_rAddr,
	input obf_wEn, obf_rEn,
	output [nb_pe_row * obf_width -1: 0] obf_out
);


wire [nb_pe_col * nb_taps * weight_width - 1: 0] WRegs_all_cols;
wire [nb_pe_col * nb_taps * weight_bpr_width - 1: 0] WBPRs_all_cols;
wire [nb_pe_col * nb_taps * ETC_width - 1: 0] WETCs_all_cols;
wire [nb_pe_row * compressed_act_width -1: 0] compressed_act_all_rows;
wire [nb_pe_row * pe_out_width - 1: 0] pe_array_out;

act_buffer #(
    .nb_pe_row             ( nb_pe_row                             ),
    .nb_pe_col                      ( nb_pe_col                            ),
    .activation_width               ( activation_width                            ),
    .mem_depth                      ( act_buff_mem_depth                           ))
U_ACT_BUFFER_0(
    .mem_data_in_all_rows           ( act_buff_data_in          ),
    .wEn                            ( act_buff_wEn                           ),
    .rEn                            ( act_buff_rEn                           ),
    .wAddr                          ( act_buff_wAddr                         ),
    .rAddr                          ( act_buff_rAddr                         ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .compressed_act_to_pe_all_rows  ( compressed_act_all_rows )
);



PEArray #(
    .nb_pe_row             ( nb_pe_row                             ),
    .nb_pe_col                      ( nb_pe_col                            ),
    .AFIFO_size                     ( AFIFO_size                             ),
    .ACCFIFO_size                   ( ACCFIFO_size                            ),
    .nb_taps                        ( nb_taps                             ),
    .activation_width               ( activation_width                           ),
    .compressed_act_width           ( activation_width+1            ),
    .weight_width                   ( weight_width                            ),
    .tap_width                      ( tap_width                            ),
    .ETC_width                      ( ETC_width                             ),
    .output_width                   ( pe_out_width                    ))
U_PEARRAY_0(
    .WRegs_all_cols                 ( WRegs_all_cols                ),
    .WBPRs_all_cols                 ( WBPRs_all_cols                ),
    .WETCs_all_cols                 ( WETCs_all_cols                ),
    .compressed_act_in_all_rows     ( compressed_act_all_rows    ),
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
    .AFIFO_write                    ( AFIFO_write                   ),
    .AFIFO_read                     ( AFIFO_read                    ),
    .ACCFIFO_write                  ( ACCFIFO_write                 ),
    .ACCFIFO_read                   ( ACCFIFO_read                  ),
    .ACCFIFO_read_out               ( ACCFIFO_read_out              ),
    .ACCFIFO_sel                    ( ACCFIFO_sel                   ),
    .out_mux_sel_PE                 ( out_mux_sel_PE                ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .out_to_OBF_all_rows            ( pe_array_out          )
);


weight_buffer #(
    .nb_pe_col             ( nb_pe_col                            ),
    .nb_taps                        ( nb_taps                             ),
    .weight_width                   ( weight_width                            ),
    .ETC_width                      ( ETC_width                             ),
    .buffer_depth                   ( weight_buff_depth                            ),
    .buffer_width                   ( weight_buff_width                            ))
U_WEIGHT_BUFFER_0(
    .WRegs                          ( WRegs_all_cols                         ),
    .WBPRs                          ( WBPRs_all_cols                         ),
    .WETCs                          ( WETCs_all_cols                         ),
    .weight_load_en                 ( weight_load_en                ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .wAddr                          ( weight_buff_wAddr                         ),
    .rAddr                          ( weight_buff_rAddr                         ),
    .buffer_data_in                 ( weight_buff_data_in                ),
    .buffer_wEn                     ( weight_buff_wEn                    ),
    .buffer_rEn                     ( weight_buff_rEn                    ),
    .n_ap                           ( n_ap                          )
);


accu_outbuffer #(
    .nb_pe_row             ( nb_pe_row                             ),
    .pe_out_width                   ( pe_out_width                            ),
    .buffer_width                   ( obf_width                            ),
    .buffer_depth                   ( obf_depth                         ))
U_ACCU_OUTBUFFER_0(
    .out_fr_pe_array                ( pe_array_out               ),
    .wAddr                          ( obf_wAddr                         ),
    .rAddr                          ( obf_rAddr                         ),
    .wEn                            ( obf_wEn                           ),
    .rEn                            ( obf_rEn                           ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .buffer_out_all_rows            ( obf_out           )
);



//************************************************************************
//function called clogb2 that returns an integer which has the
//value of the ceiling of the log base 2.
function integer clogb2 (input integer bit_depth);
begin
bit_depth = bit_depth - 1;
for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
bit_depth = bit_depth>>1;
end
endfunction
//************************************************************************


endmodule

