module FPAP_for_power_analysis #(
    num_pe_row = 16,
    num_pe_col = 16,
    total_num_pe = num_pe_row * num_pe_col,
    out_fr_array_width = 24,
    OutBuff_data_width = 16,
    ActBuff_depth = 768,
    ActBuff_addr_width = clogb2(ActBuff_depth),
    WBuff_depth  = 72,
    WBuff_addr_width = clogb2(WBuff_depth),
    OutBuff_depth = 8192,
    OutBuff_addr_width = clogb2(OutBuff_depth),
    //parameters for PE and FoFIR
	nb_taps = 11,
	activation_width = 16,
	compressed_act_width = activation_width + 1,
	weight_width = 16,
	tap_width = 24,
	weight_bpr_width = ((weight_width+1)/2)*3,
	act_bpr_width = ((activation_width+1)/2)*3,
	ETC_width = 4,
	width_current_tap = nb_taps > 8 ? 4 : 3,
    output_width = tap_width
)(
    // input data ports from the dummy_ctrl
    input [num_pe_row-1: 0][compressed_act_width-1: 0] compressed_act_in_fr_dummy_ctrl,
    input [num_pe_col-1: 0][compressed_act_width-1: 0] last_row_shadow_AFIFO_data_in_fr_dummy_ctrl,
    input [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs_fr_dummy_ctrl,
    input [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs_fr_dummy_ctrl,
    input [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs_fr_dummy_ctrl, 
    // select signals to choose the data source
    // 0 is from dummy, else from actbuff bank equal or below current PE row
    input [2-1: 0] compressed_act_in_sel, 
    // 0 is from dummy, else from wbuff
    input last_row_shadow_afifo_in_sel,
    input wreg_in_sel,
    /********ActBuff Ports**************/
	input [num_pe_row-1: 0][compressed_act_width-1: 0] ActBuff_data_in,
	input [num_pe_row-1: 0] ActBuff_wEn_AH, 
    input [num_pe_row-1: 0] ActBuff_rEn_AH, 
	input [num_pe_row-1: 0][ActBuff_addr_width-1: 0] ActBuff_wAddr,
    input [num_pe_row-1: 0][ActBuff_addr_width-1: 0] ActBuff_rAddr,
    /*******WeightBuff Ports************/
    input [num_pe_col-1: 0][nb_taps-1: 0] WBuff_weight_load_en,
	input [num_pe_col-1: 0][WBuff_addr_width-1: 0] WBuff_wAddr, 
	input [num_pe_col-1: 0][WBuff_addr_width-1: 0] WBuff_rAddr,
	input [num_pe_col-1: 0][weight_width-1: 0] WBuff_data_in,
	input [num_pe_col-1: 0] WBuff_wEn_AH,//active high 
    input [num_pe_col-1: 0] WBuff_rEn_AH,//active high
    input WBuff_clear_all_wregs,
    /****** OutBuff Ports**************/
    output [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_out_even,
    output [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_out_odd,
    input [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_in_fr_dummy_ctrl_even,
    input [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_in_fr_dummy_ctrl_odd,
    input [num_pe_row-1: 0] OutBuff_wEn_even_AH,//active high
    input [num_pe_row-1: 0] OutBuff_wEn_odd_AH,//active high
    input [num_pe_row-1: 0] OutBuff_rEn_even_AH,//active high
    input [num_pe_row-1: 0] OutBuff_rEn_odd_AH,//active high
    input [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_wAddr_even,
    input [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_wAddr_odd,
    input [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_rAddr_even,
    input [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_rAddr_odd,
    input next_data_fr_array_valid,
    input OutBuff_ctrl_signal_sel,
    /***** PEArray Control Ports*********/
    // configuration
        input [total_num_pe-1: 0][4-1: 0] pe_ctrl_n_ap,
    // control ports for PAMAC
        input [total_num_pe-1: 0][3-1: 0] pe_ctrl_PAMAC_BPEB_sel,
        input [total_num_pe-1: 0] pe_ctrl_PAMAC_DFF_en,
        input [total_num_pe-1: 0] pe_ctrl_PAMAC_first_cycle,
        input [total_num_pe-1: 0] pe_ctrl_PAMAC_MDecomp,
        input [total_num_pe-1: 0] pe_ctrl_PAMAC_AWDecomp,
    // control ports for FoFIR
        input [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_current_tap,
        input [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_en,
        input [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_clr,
        input [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_in_sel,
        input [total_num_pe-1: 0] pe_ctrl_index_update_en,
        input [total_num_pe-1: 0] pe_ctrl_out_mux_sel,
        input [total_num_pe-1: 0] pe_ctrl_out_reg_en,
    // control ports for FIFOs
        input [total_num_pe-1: 0] pe_ctrl_AFIFO_write,
        input [total_num_pe-1: 0] pe_ctrl_AFIFO_read, 
        input [total_num_pe-1: 0] pe_ctrl_ACCFIFO_write,
        input [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read,
        input [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read_to_outbuffer,
        input [total_num_pe-1: 0] pe_ctrl_out_mux_sel_PE,//
        input [total_num_pe-1: 0] pe_ctrl_out_to_right_pe_en,	
        input [total_num_pe-1: 0] pe_ctrl_add_zero,
        input [total_num_pe-1: 0] pe_ctrl_feed_zero_to_accfifo,
        input [total_num_pe-1: 0] pe_ctrl_accfifo_head_to_tail,
        input [total_num_pe-1: 0] pe_ctrl_which_accfifo_for_compute,
        input [total_num_pe-1: 0] pe_ctrl_which_afifo_for_compute, 
        input [total_num_pe-1: 0] pe_ctrl_compute_AFIFO_read_delay_enable,
        input [num_pe_col-1: 0] pe_ctrl_last_row_shadow_AFIFO_write,

    /**** End of Ports to control the PE array***/

    /**** Ports from PE array for some info ****/
        output [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_PD0,
        output [total_num_pe-1: 0] pe_ctrl_AFIFO_full,
        output [total_num_pe-1: 0] pe_ctrl_AFIFO_empty,
        output [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_afifo_out,
    /**** End of Ports from PE array for some info****/

    /**** Ports for systolic chain*******************/
        output [total_num_pe-1: 0] pe_ctrl_ACCFIFO_empty,
    /****** Configuration Ports********/

    input clk, rst_n
);
/***** Wires of ActBuff*******/
logic [num_pe_row-1: 0][compressed_act_width -1: 0] compressed_act_fr_ActBuff;
/***** Wires of WeightBuff******/
logic [num_pe_col-1: 0][nb_taps * weight_width - 1: 0] WRegs_fr_WBuff;
logic [num_pe_col-1: 0][nb_taps * weight_bpr_width - 1: 0] WBPRs_fr_WBuff;
logic [num_pe_col-1: 0][nb_taps * ETC_width - 1: 0] WETCs_fr_WBuff;
logic [num_pe_col-1: 0][activation_width-1: 0] last_row_shadow_AFIFO_data_in_fr_WBuff;
logic [num_pe_col-1: 0][compressed_act_width-1: 0] last_row_shadow_AFIFO_data_in_to_PEArray;
/***** Wires of OutBuff with PEArray*********/
logic [num_pe_row-1: 0][out_fr_array_width-1: 0] array_out_even_col;
logic [num_pe_row-1: 0][out_fr_array_width-1: 0] array_out_odd_col;
/***** Wires between data wrapper with PEArray**************/
logic [num_pe_row-1: 0][compressed_act_width-1: 0] pe_data_compressed_act_in;
logic [num_pe_col-1: 0][compressed_act_width-1: 0] pe_data_last_row_shadow_AFIFO_data_in;
logic [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs;
logic [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs;
logic [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs;

/***** Insert Zero to the last row shadow afifo data in*****/
genvar gen_i;
generate
    for(gen_i = 0; gen_i < num_pe_row; gen_i++) begin
        assign last_row_shadow_AFIFO_data_in_to_PEArray[gen_i] = {1'b0, last_row_shadow_AFIFO_data_in_fr_WBuff[gen_i]};
    end
endgenerate


/****************Instances*****************/
ActBuff_for_power_analysis #(
    .nb_pe_row(num_pe_row),
    .nb_pe_col(num_pe_col),
    .activation_width(activation_width)
) u_ActBuff_for_power_analysis(
	.mem_data_in_all_rows          ( ActBuff_data_in          ),
    .wEn_AH                        (ActBuff_wEn_AH                        ),
    .rEn_AH                        (ActBuff_rEn_AH                   ),
    .wAddr                         (ActBuff_wAddr                        ),
    .rAddr                         ( ActBuff_rAddr                        ),
    .clk                           (clk                           ),
    .rst_n                         (rst_n                         ),
    .compressed_act_to_pe_all_rows (compressed_act_fr_ActBuff)
);

WBuff_for_power_analysis #(
    .nb_pe_col(num_pe_col),
    .weight_width(weight_width),
    .ETC_width(ETC_width)
) u_WBuff_for_power_analysis(
	.WRegs               (WRegs_fr_WBuff               ),
    .WBPRs               ( WBPRs_fr_WBuff               ),
    .WETCs               (WETCs_fr_WBuff              ),
    .last_pe_row_data_in (last_row_shadow_AFIFO_data_in_fr_WBuff ),
    .weight_load_en      (WBuff_weight_load_en      ),
    .clk                 (clk                 ),
    .rst_n               (rst_n               ),
    .wAddr               ( WBuff_wAddr               ),
    .rAddr               ( WBuff_rAddr               ),
    .buffer_data_in      (WBuff_data_in      ),
    .buffer_wEn_AH       (WBuff_wEn_AH       ),
    .buffer_rEn_AH       (WBuff_rEn_AH       ),
    .clear_all_wregs     (WBuff_clear_all_wregs     ),
    .n_ap                ( 4'b0                )
);

OutBuff_for_power_analysis #(
    .num_pe_row(num_pe_row),
    .out_fr_array_width(out_fr_array_width)
) u_OutBuff_for_power_analysis(
	.buff_data_out_even              (OutBuff_data_out_even             ),
    .buff_data_out_odd               (OutBuff_data_out_odd               ),
    .buff_data_in_fr_dummy_ctrl_even ( OutBuff_data_in_fr_dummy_ctrl_even ),
    .buff_data_in_fr_dummy_ctrl_odd  ( OutBuff_data_in_fr_dummy_ctrl_odd ),
    .wEn_fr_dummy_ctrl_even_AH       (OutBuff_wEn_even_AH       ),
    .wEn_fr_dummy_ctrl_odd_AH        (OutBuff_wEn_odd_AH        ),
    .rEn_fr_dummy_ctrl_even_AH       (OutBuff_rEn_even_AH     ),
    .rEn_fr_dummy_ctrl_odd_AH        (OutBuff_rEn_odd_AH      ),
    .wAddr_fr_dummy_ctrl_even        (OutBuff_wAddr_even        ),
    .wAddr_fr_dummy_ctrl_odd         (OutBuff_wAddr_odd        ),
    .rAddr_fr_dummy_ctrl_even        (OutBuff_rAddr_even        ),
    .rAddr_fr_dummy_ctrl_odd         (OutBuff_rAddr_odd          ),
    .array_out_even_col              (array_out_even_col              ),
    .array_out_odd_col               (array_out_odd_col               ),
    .next_data_fr_array_valid        (next_data_fr_array_valid        ),
    .ctrl_signal_sel                 (OutBuff_ctrl_signal_sel                 ),
    .clk                             (clk                             ),
    .rst_n                           (rst_n                           )
);
PEArrayDataInWrapper #(
    .num_pe_row(num_pe_row),
    .num_pe_col(num_pe_col),
    .weight_width(weight_width),
    .activation_width(activation_width),
    .ETC_width(ETC_width)
)u_PEArrayDataInWrapper(
	.pe_data_compressed_act_in                   (pe_data_compressed_act_in                   ),
    .pe_data_last_row_shadow_AFIFO_data_in       (pe_data_last_row_shadow_AFIFO_data_in       ),
    .WRegs                                       (WRegs                                       ),
    .WBPRs                                       (WBPRs                                       ),
    .WETCs                                       (WETCs                                       ),
    .compressed_act_in_fr_dummy_ctrl             (compressed_act_in_fr_dummy_ctrl             ),
    .last_row_shadow_AFIFO_data_in_fr_dummy_ctrl (last_row_shadow_AFIFO_data_in_fr_dummy_ctrl ),
    .WRegs_fr_dummy_ctrl                         (WRegs_fr_dummy_ctrl                         ),
    .WBPRs_fr_dummy_ctrl                         (WBPRs_fr_dummy_ctrl                         ),
    .WETCs_fr_dummy_ctrl                         (WETCs_fr_dummy_ctrl                         ),
    .compressed_act_in_fr_actbuff                (compressed_act_fr_ActBuff                ),
    .WRegs_fr_wbuff                              (WRegs_fr_WBuff                             ),
    .WBPRs_fr_wbuff                              (WBPRs_fr_WBuff                              ),
    .WETCs_fr_wbuff                              (WETCs_fr_WBuff                              ),
    .last_row_shadow_AFIFO_data_in_fr_wbuff      (last_row_shadow_AFIFO_data_in_to_PEArray    ),
    .compressed_act_in_sel                       (compressed_act_in_sel                       ),
    .last_row_shadow_afifo_in_sel                (last_row_shadow_afifo_in_sel                ),
    .wreg_in_sel                                 (wreg_in_sel                                 )
);

PEArray_for_power_analysis #(
    .num_pe_row(num_pe_row),
    .num_pe_col(num_pe_col),
    .nb_taps(nb_taps),
    .weight_width(weight_width),
    .activation_width(activation_width),
    .ETC_width(ETC_width)
)u_PEArray_for_power_analysis(
	.pe_data_compressed_act_in               (pe_data_compressed_act_in               ),
    .pe_data_last_row_shadow_AFIFO_data_in   (pe_data_last_row_shadow_AFIFO_data_in   ),
    .pe_ctrl_n_ap                            (pe_ctrl_n_ap                            ),
    .pe_ctrl_PAMAC_BPEB_sel                  (pe_ctrl_PAMAC_BPEB_sel                  ),
    .pe_ctrl_PAMAC_DFF_en                    (pe_ctrl_PAMAC_DFF_en                    ),
    .pe_ctrl_PAMAC_first_cycle               (pe_ctrl_PAMAC_first_cycle               ),
    .pe_ctrl_PAMAC_MDecomp                   (pe_ctrl_PAMAC_MDecomp                   ),
    .pe_ctrl_PAMAC_AWDecomp                  (pe_ctrl_PAMAC_AWDecomp                  ),
    .pe_ctrl_current_tap                     (pe_ctrl_current_tap                     ),
    .pe_ctrl_DRegs_en                        (pe_ctrl_DRegs_en                        ),
    .pe_ctrl_DRegs_clr                       (pe_ctrl_DRegs_clr                       ),
    .pe_ctrl_DRegs_in_sel                    (pe_ctrl_DRegs_in_sel                    ),
    .pe_ctrl_index_update_en                 (pe_ctrl_index_update_en                 ),
    .pe_ctrl_out_mux_sel                     (pe_ctrl_out_mux_sel                     ),
    .pe_ctrl_out_reg_en                      (pe_ctrl_out_reg_en                      ),
    .pe_ctrl_AFIFO_write                     (pe_ctrl_AFIFO_write                     ),
    .pe_ctrl_AFIFO_read                      (pe_ctrl_AFIFO_read                      ),
    .pe_ctrl_ACCFIFO_write                   (pe_ctrl_ACCFIFO_write                   ),
    .pe_ctrl_ACCFIFO_read                    (pe_ctrl_ACCFIFO_read                    ),
    .pe_ctrl_ACCFIFO_read_to_outbuffer       (pe_ctrl_ACCFIFO_read_to_outbuffer       ),
    .pe_ctrl_out_mux_sel_PE                  (pe_ctrl_out_mux_sel_PE                  ),
    .pe_ctrl_out_to_right_pe_en              (pe_ctrl_out_to_right_pe_en              ),
    .pe_ctrl_add_zero                        (pe_ctrl_add_zero                        ),
    .pe_ctrl_feed_zero_to_accfifo            (pe_ctrl_feed_zero_to_accfifo            ),
    .pe_ctrl_accfifo_head_to_tail            (pe_ctrl_accfifo_head_to_tail            ),
    .pe_ctrl_which_accfifo_for_compute       (pe_ctrl_which_accfifo_for_compute       ),
    .pe_ctrl_which_afifo_for_compute         (pe_ctrl_which_afifo_for_compute         ),
    .pe_ctrl_compute_AFIFO_read_delay_enable (pe_ctrl_compute_AFIFO_read_delay_enable ),
    .pe_ctrl_last_row_shadow_AFIFO_write     (pe_ctrl_last_row_shadow_AFIFO_write     ),
    .pe_ctrl_PD0                             (pe_ctrl_PD0                             ),
    .pe_ctrl_AFIFO_full                      (pe_ctrl_AFIFO_full                      ),
    .pe_ctrl_AFIFO_empty                     (pe_ctrl_AFIFO_empty                     ),
    .pe_data_afifo_out                       (pe_data_afifo_out                       ),
    .WRegs                                   (WRegs                                   ),
    .WBPRs                                   (WBPRs                                   ),
    .WETCs                                   (WETCs                                   ),
    .out_fr_rightest_PE_even_col             (array_out_even_col              ),
    .out_fr_rightest_PE_odd_col              (array_out_odd_col              ),
    .pe_ctrl_ACCFIFO_empty                   (pe_ctrl_ACCFIFO_empty                   ),
    .clk                                     (clk                                     ),
    .rst_n                                   (rst_n                                   )
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