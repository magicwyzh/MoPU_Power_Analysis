module FPAP_Ctrl #(
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
    // data ports from the dummy_ctrl
    output [num_pe_row-1: 0][compressed_act_width-1: 0] compressed_act_in_fr_dummy_ctrl,
    output [num_pe_col-1: 0][compressed_act_width-1: 0] last_row_shadow_AFIFO_data_in_fr_dummy_ctrl,
    output [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs_fr_dummy_ctrl,
    output [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs_fr_dummy_ctrl,
    output [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs_fr_dummy_ctrl, 
    // select signals to choose the data source
    // 0 is from dummy, else from actbuff bank equal or below current PE row
    output logic [2-1: 0] compressed_act_in_sel, 
    // 0 is from dummy, else from wbuff
    output logic last_row_shadow_afifo_in_sel,
    output logic wreg_in_sel,
    /********ActBuff Ports**************/
	output [num_pe_row-1: 0][compressed_act_width-1: 0] ActBuff_data_in,
	output [num_pe_row-1: 0] ActBuff_wEn_AH, 
    output [num_pe_row-1: 0] ActBuff_rEn_AH, 
	output [num_pe_row-1: 0][ActBuff_addr_width-1: 0] ActBuff_wAddr,
    output [num_pe_row-1: 0][ActBuff_addr_width-1: 0] ActBuff_rAddr,
    /*******WeightBuff Ports************/
    output [num_pe_col-1: 0][nb_taps-1: 0] WBuff_weight_load_en,
	output [num_pe_col-1: 0][WBuff_addr_width-1: 0] WBuff_wAddr, 
	output [num_pe_col-1: 0][WBuff_addr_width-1: 0] WBuff_rAddr,
	output [num_pe_col-1: 0][weight_width-1: 0] WBuff_data_in,
	output [num_pe_col-1: 0] WBuff_wEn_AH,//active high 
    output [num_pe_col-1: 0] WBuff_rEn_AH,//active high
    output WBuff_clear_all_wregs,
    /****** OutBuff Ports**************/
    output logic [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_in_fr_dummy_ctrl_even,
    output logic [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_in_fr_dummy_ctrl_odd,
    output logic [num_pe_row-1: 0] OutBuff_wEn_even_AH,//active high
    output logic [num_pe_row-1: 0] OutBuff_wEn_odd_AH,//active high
    output logic [num_pe_row-1: 0] OutBuff_rEn_even_AH,//active high
    output logic [num_pe_row-1: 0] OutBuff_rEn_odd_AH,//active high
    output logic [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_wAddr_even,
    output logic [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_wAddr_odd,
    output logic [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_rAddr_even,
    output logic [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_rAddr_odd,
    output next_data_fr_array_valid,
    output logic OutBuff_ctrl_signal_sel,
    /***** PEArray Control Ports*********/
    // configuration
        output [total_num_pe-1: 0][4-1: 0] pe_ctrl_n_ap,
    // control ports for PAMAC
        output [total_num_pe-1: 0][3-1: 0] pe_ctrl_PAMAC_BPEB_sel,
        output [total_num_pe-1: 0] pe_ctrl_PAMAC_DFF_en,
        output [total_num_pe-1: 0] pe_ctrl_PAMAC_first_cycle,
        output [total_num_pe-1: 0] pe_ctrl_PAMAC_MDecomp,
        output [total_num_pe-1: 0] pe_ctrl_PAMAC_AWDecomp,
    // control ports for FoFIR
        output [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_current_tap,
        output [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_en,
        output [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_clr,
        output [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_in_sel,
        output [total_num_pe-1: 0] pe_ctrl_index_update_en,
        output [total_num_pe-1: 0] pe_ctrl_out_mux_sel,
        output [total_num_pe-1: 0] pe_ctrl_out_reg_en,
    // control ports for FIFOs
        output [total_num_pe-1: 0] pe_ctrl_AFIFO_write,
        output [total_num_pe-1: 0] pe_ctrl_AFIFO_read, 
        output [total_num_pe-1: 0] pe_ctrl_ACCFIFO_write,
        output [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read,
        output [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read_to_outbuffer,
        output [total_num_pe-1: 0] pe_ctrl_out_mux_sel_PE,//
        output [total_num_pe-1: 0] pe_ctrl_out_to_right_pe_en,	
        output [total_num_pe-1: 0] pe_ctrl_add_zero,
        output [total_num_pe-1: 0] pe_ctrl_feed_zero_to_accfifo,
        output [total_num_pe-1: 0] pe_ctrl_accfifo_head_to_tail,
        output [total_num_pe-1: 0] pe_ctrl_which_accfifo_for_compute,
        output [total_num_pe-1: 0] pe_ctrl_which_afifo_for_compute, 
        output [total_num_pe-1: 0] pe_ctrl_compute_AFIFO_read_delay_enable,
        output [num_pe_col-1: 0] pe_ctrl_last_row_shadow_AFIFO_write,

    /**** End of Ports to control the PE array***/

    /**** Ports from PE array for some info ****/
        input [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_PD0,
        input [total_num_pe-1: 0] pe_ctrl_AFIFO_full,
        input [total_num_pe-1: 0] pe_ctrl_AFIFO_empty,
        input [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_afifo_out,
    /**** End of Ports from PE array for some info****/

    /**** Ports for systolic chain*******************/
        input [total_num_pe-1: 0] pe_ctrl_ACCFIFO_empty,
    /****** Configuration Ports********/

    input clk
);
    // select the source of data
    initial begin
        OutBuff_ctrl_signal_sel = 1; // 
        wreg_in_sel = 0;
        last_row_shadow_afifo_in_sel = 0;
        compressed_act_in_sel = 0;
    end
    initial begin
        OutBuff_data_in_fr_dummy_ctrl_even = 0;
        OutBuff_data_in_fr_dummy_ctrl_odd = 0; 
        OutBuff_wEn_even_AH = 0;//active high
        OutBuff_wEn_odd_AH = 0;//active high
        OutBuff_rEn_even_AH = 0;//active high
        OutBuff_rEn_odd_AH = 0;//active high
        OutBuff_wAddr_even = 0;
        OutBuff_wAddr_odd = 0;
        OutBuff_rAddr_even = 0;
        OutBuff_rAddr_odd = 0;
    end
    // Instance
    ArrayConvLayerCtrl #(
            .num_pe_row(num_pe_row),
            .num_pe_col(num_pe_col)
        ) u_ArrayConvLayerCtrl(
    	.pe_data_compressed_act_in               (compressed_act_in_fr_dummy_ctrl               ),
        .pe_data_last_row_shadow_AFIFO_data_in   (last_row_shadow_AFIFO_data_in_fr_dummy_ctrl   ),
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
        .pe_ctrl_last_row_shadow_AFIFO_write     (pe_ctrl_last_row_shadow_AFIFO_write     ),
        .pe_ctrl_PD0                             (pe_ctrl_PD0                             ),
        .pe_ctrl_AFIFO_full                      (pe_ctrl_AFIFO_full                      ),
        .pe_ctrl_AFIFO_empty                     (pe_ctrl_AFIFO_empty                     ),
        .pe_data_afifo_out                       (pe_data_afifo_out                       ),
        .pe_ctrl_ACCFIFO_empty                   (pe_ctrl_ACCFIFO_empty                   ),
        .WRegs                                   (WRegs_fr_dummy_ctrl                                   ),
        .WBPRs                                   (WBPRs_fr_dummy_ctrl                                   ),
        .WETCs                                   (WETCs_fr_dummy_ctrl                                   ),
        .pe_ctrl_which_accfifo_for_compute       (pe_ctrl_which_accfifo_for_compute       ),
        .pe_ctrl_compute_AFIFO_read_delay_enable (pe_ctrl_compute_AFIFO_read_delay_enable ),
        .pe_ctrl_which_afifo_for_compute         (pe_ctrl_which_afifo_for_compute         ),
        .array_next_cycle_data_to_outbuff_valid  (next_data_fr_array_valid  ),
        .clk                                     (clk                                     )
    );
    conv_one_layer_buff_ctrl #(
            .num_pe_row(num_pe_row),
            .num_pe_col(num_pe_col)
        ) u_conv_one_layer_buff_ctrl(
        .ActBuff_data_in              (ActBuff_data_in              ),
        .ActBuff_wEn_AH               (ActBuff_wEn_AH               ),
        .ActBuff_rEn_AH               (ActBuff_rEn_AH               ),
        .ActBuff_wAddr                (ActBuff_wAddr                ),
        .ActBuff_rAddr                (ActBuff_rAddr                ),
        .WBuff_weight_load_en         (WBuff_weight_load_en         ),
        .WBuff_wAddr                  (WBuff_wAddr                  ),
        .WBuff_rAddr                  (WBuff_rAddr                  ),
        .WBuff_data_in                (WBuff_data_in                ),
        .WBuff_wEn_AH                 (WBuff_wEn_AH                 ),
        .WBuff_rEn_AH                 (WBuff_rEn_AH                 ),
        .WBuff_clear_all_wregs        (WBuff_clear_all_wregs        ),
        .clk                          (clk                          )
    );

    task dw_conv_one_layer_compute_buff_ctrl(
        input string act_file_path,
        input string weight_full_path,
        input int stride,
        input int num_ch,
        input int fm_size,
        input int kernel_size
    );
        fork
            u_conv_one_layer_buff_ctrl.dw_conv_one_layer_BuffCtrlGen(
                act_file_path,
                weight_full_path,
                stride,
                num_ch,
                fm_size,
                kernel_size
            );
            u_ArrayConvLayerCtrl.dw_conv_one_layer(
                act_file_path,
                weight_full_path,
                stride,
                num_ch,
                fm_size,
                kernel_size
            );
        join
    endtask

    task normal_conv_one_layer_compute_buff_ctrl(
        input string act_file_path,
        input string weight_full_path,
        input int num_in_ch,
        input int num_out_ch,
        input int stride,
        input int fm_size,
        input int kernel_size
    );
        fork
            u_conv_one_layer_buff_ctrl.normal_conv_one_layer_BuffCtrlGen(
                act_file_path,
                weight_full_path,
                num_in_ch,
                num_out_ch,
                stride,
                fm_size,
                kernel_size
            );
            u_ArrayConvLayerCtrl.normal_conv_one_layer(
                act_file_path,
                weight_full_path,
                num_in_ch,
                num_out_ch,
                stride,
                fm_size,
                kernel_size
            );
        join
    endtask
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