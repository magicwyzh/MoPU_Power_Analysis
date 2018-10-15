module PEArray_for_power_analysis #(parameter
    num_pe_row = 1,
    num_pe_col = 1,
    total_num_pe = num_pe_row * num_pe_col,
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
        /**** Ports to control the PE array (started with ``pe_ctrl/data")*****/
        // AFIFO data
            input [num_pe_row-1: 0][compressed_act_width-1: 0] pe_data_compressed_act_in,
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
        /**** End of Ports to control the PE array***/

        /**** Ports from PE array for some info ****/
            output [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_PD0,
            output [total_num_pe-1: 0] pe_ctrl_AFIFO_full,
            output [total_num_pe-1: 0] pe_ctrl_AFIFO_empty,
            output [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_afifo_out,
        /**** End of Ports from PE array for some info****/

        /**** Ports of some weights info*****************/
            input [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs,
            input [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs,
            input [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs,
        /**** End of ports for weights info**************/

        /**** Ports for systolic chain*******************/
            output [num_pe_row-1: 0][output_width-1:0] out_fr_rightest_PE_even_col,    // %2 = 0
            output [num_pe_row-1: 0][output_width-1:0] out_fr_rightest_PE_odd_col,     // %2 = 1
            output [total_num_pe-1: 0] pe_ctrl_ACCFIFO_empty,
        /****Configuration ports*************************/
            input [4-1: 0] n_ap,

            input clk,
            input rst_n
);

    genvar gen_r, gen_c, gen_idx_1d;
    logic [output_width-1: 0] out_fr_single_pe[num_pe_row-1: 0][num_pe_col-1: 0];
    logic [output_width-1: 0] out_to_single_pe[num_pe_row-1: 0][num_pe_col-1: 0];
    generate
    // assume num_pe_col is even
    for(gen_r = 0; gen_r<num_pe_row;gen_r++) begin
        assign out_fr_rightest_PE_even_col[gen_r] = out_fr_single_pe[gen_r][num_pe_col-2];
        assign out_fr_rightest_PE_odd_col[gen_r] = out_fr_single_pe[gen_r][num_pe_col-1];
        for(gen_c = 0; gen_c <= num_pe_row; gen_c+=2) begin
            if(gen_c > 0) begin
                //assign out_to_single_pe[gen_r][gen_c] = out_fr_single_pe[gen_r][gen_c - 1];
                assign out_to_single_pe[gen_r][gen_c] = out_fr_single_pe[gen_r][gen_c - 2];
                assign out_to_single_pe[gen_r][gen_c + 1] = out_fr_single_pe[gen_r][gen_c - 1];
            end
            else begin
                //gen_c = 0
                assign out_to_single_pe[gen_r][gen_c] = 0;
                assign out_to_single_pe[gen_r][gen_c+1] = 0;
            end
        end
    end
    for(gen_r = 0; gen_r < num_pe_row; gen_r++) begin
        for(gen_c = 0; gen_c < num_pe_col; gen_c++) begin
            //gen_idx_1d = gen_c + gen_r * num_pe_col;
            PE_for_power_analysis #(
                .nb_taps(nb_taps),
                .activation_width(activation_width),
                .weight_width(weight_width),
                .tap_width(tap_width),
                .ETC_width(ETC_width))
            u_PE_for_power_analysis(
            	.compressed_act_in    (pe_data_compressed_act_in[gen_r]    ),
                .out_fr_left_PE       (out_to_single_pe[gen_r][gen_c]        ),
                .n_ap                 (n_ap                 ),
                .PAMAC_BPEB_sel       (pe_ctrl_PAMAC_BPEB_sel[gen_c+gen_r*num_pe_col]       ),
                .PAMAC_DFF_en         (pe_ctrl_PAMAC_DFF_en[gen_c+gen_r*num_pe_col]         ),
                .PAMAC_first_cycle    (pe_ctrl_PAMAC_first_cycle[gen_c+gen_r*num_pe_col]    ),
                .PAMAC_MDecomp        (pe_ctrl_PAMAC_MDecomp[gen_c+gen_r*num_pe_col]        ),
                .PAMAC_AWDecomp       (pe_ctrl_PAMAC_AWDecomp[gen_c+gen_r*num_pe_col]       ),
                .current_tap          (pe_ctrl_current_tap[gen_c+gen_r*num_pe_col]          ),
                .DRegs_en             (pe_ctrl_DRegs_en[gen_c+gen_r*num_pe_col]             ),
                .DRegs_clr            (pe_ctrl_DRegs_clr[gen_c+gen_r*num_pe_col]            ),
                .DRegs_in_sel         (pe_ctrl_DRegs_in_sel[gen_c+gen_r*num_pe_col]         ),
                .index_update_en      (pe_ctrl_index_update_en[gen_c+gen_r*num_pe_col]      ),
                .out_mux_sel          (pe_ctrl_out_mux_sel[gen_c+gen_r*num_pe_col]          ),
                .out_reg_en           (pe_ctrl_out_reg_en[gen_c+gen_r*num_pe_col]           ),
                .WRegs                (WRegs[gen_c]                ),
                .WBPRs                (WBPRs[gen_c]                ),
                .WETCs                (WETCs[gen_c]                ),
                .AFIFO_write          (pe_ctrl_AFIFO_write[gen_c+gen_r*num_pe_col]          ),
                .AFIFO_read           (pe_ctrl_AFIFO_read[gen_c+gen_r*num_pe_col]           ),
                .AFIFO_full           (pe_ctrl_AFIFO_full[gen_c+gen_r*num_pe_col]),
                .AFIFO_empty          (pe_ctrl_AFIFO_empty[gen_c+gen_r*num_pe_col]),
                .afifo_data_out        (pe_data_afifo_out[gen_c+gen_r*num_pe_col]),
                .ACCFIFO_write        (pe_ctrl_ACCFIFO_write[gen_c+gen_r*num_pe_col]        ),
                .ACCFIFO_read_0         (pe_ctrl_ACCFIFO_read[gen_c+gen_r*num_pe_col]         ),
                .ACCFIFO_read_1          (pe_ctrl_ACCFIFO_read_to_outbuffer[gen_c+gen_r*num_pe_col] ),
                .out_mux_sel_PE       (pe_ctrl_out_mux_sel_PE[gen_c+gen_r*num_pe_col]       ),
                .out_to_right_pe_en   (pe_ctrl_out_to_right_pe_en[gen_c+gen_r*num_pe_col]   ),
                .add_zero             (pe_ctrl_add_zero[gen_c+gen_r*num_pe_col]             ),
                .feed_zero_to_accfifo (pe_ctrl_feed_zero_to_accfifo[gen_c+gen_r*num_pe_col] ),
                .accfifo_head_to_tail (pe_ctrl_accfifo_head_to_tail[gen_c+gen_r*num_pe_col] ),
                //.ACCFIFO_read_ctrl_src_sel  (pe_ctrl_ACCFIFO_read_ctrl_src_sel[gen_c+gen_r*num_pe_col]),
                .which_accfifo_for_compute (pe_ctrl_which_accfifo_for_compute[gen_c+gen_r*num_pe_col]),
                .clk                  (clk                  ),
                .rst_n                (rst_n                ),
                .PD0                  (pe_ctrl_PD0[gen_c+gen_r*num_pe_col]                  ),
                .out_to_right_PE      (out_fr_single_pe[gen_r][gen_c]      ),
                .ACCFIFO_empty        (pe_ctrl_ACCFIFO_empty[gen_c+gen_r*num_pe_col]        )
            );
            
        end
    end
    endgenerate



endmodule