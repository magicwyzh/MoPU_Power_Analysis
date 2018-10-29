`timescale 1ns/1ns
module FPAP_Ctrl_tb #(
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
)();
    // select signals to choose the data source
    // 0 is from dummy, else from actbuff bank equal or below current PE row
    logic [2-1: 0] compressed_act_in_sel; 
    // 0 is from dummy, else from wbuff
    logic last_row_shadow_afifo_in_sel;
    logic wreg_in_sel;
    /********ActBuff Ports**************/
	logic [num_pe_row-1: 0][compressed_act_width-1: 0] ActBuff_data_in;
	logic [num_pe_row-1: 0] ActBuff_wEn_AH; 
    logic [num_pe_row-1: 0] ActBuff_rEn_AH; 
	logic [num_pe_row-1: 0][ActBuff_addr_width-1: 0] ActBuff_wAddr;
    logic [num_pe_row-1: 0][ActBuff_addr_width-1: 0] ActBuff_rAddr;
    /*******WeightBuff Ports************/
    logic [num_pe_col-1: 0][nb_taps-1: 0] WBuff_weight_load_en;
	logic [num_pe_col-1: 0][WBuff_addr_width-1: 0] WBuff_wAddr; 
	logic [num_pe_col-1: 0][WBuff_addr_width-1: 0] WBuff_rAddr;
	logic [num_pe_col-1: 0][weight_width-1: 0] WBuff_data_in;
	logic [num_pe_col-1: 0] WBuff_wEn_AH;//active high 
    logic [num_pe_col-1: 0] WBuff_rEn_AH;//active high
    logic WBuff_clear_all_wregs;
    logic clk;
    logic rst_n;

    // input data ports from the dummy_ctrl
    logic [num_pe_row-1: 0][compressed_act_width-1: 0] compressed_act_in_fr_dummy_ctrl;
    logic [num_pe_col-1: 0][compressed_act_width-1: 0] last_row_shadow_AFIFO_data_in_fr_dummy_ctrl;
    logic [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs_fr_dummy_ctrl;
    logic [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs_fr_dummy_ctrl;
    logic [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs_fr_dummy_ctrl; 
    /****** OutBuff Ports**************/
    logic [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_out_even;
    logic [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_out_odd;
    logic [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_in_fr_dummy_ctrl_even;
    logic [num_pe_row-1: 0][OutBuff_data_width-1: 0] OutBuff_data_in_fr_dummy_ctrl_odd;
    logic [num_pe_row-1: 0] OutBuff_wEn_even_AH;//active high
    logic [num_pe_row-1: 0] OutBuff_wEn_odd_AH;//active high
    logic [num_pe_row-1: 0] OutBuff_rEn_even_AH;//active high
    logic [num_pe_row-1: 0] OutBuff_rEn_odd_AH;//active high
    logic [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_wAddr_even;
    logic [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_wAddr_odd;
    logic [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_rAddr_even;
    logic [num_pe_row-1: 0][OutBuff_addr_width-1: 0] OutBuff_rAddr_odd;
    logic next_data_fr_array_valid;
    logic OutBuff_ctrl_signal_sel;   

    /***** PEArray Control Ports*********/
    // configuration
        logic [total_num_pe-1: 0][4-1: 0] pe_ctrl_n_ap;
    // control ports for PAMAC
        logic [total_num_pe-1: 0][3-1: 0] pe_ctrl_PAMAC_BPEB_sel;
        logic [total_num_pe-1: 0] pe_ctrl_PAMAC_DFF_en;
        logic [total_num_pe-1: 0] pe_ctrl_PAMAC_first_cycle;
        logic [total_num_pe-1: 0] pe_ctrl_PAMAC_MDecomp;
        logic [total_num_pe-1: 0] pe_ctrl_PAMAC_AWDecomp;
    // control ports for FoFIR
        logic [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_current_tap;
        logic [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_en;
        logic [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_clr;
        logic [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_in_sel;
        logic [total_num_pe-1: 0] pe_ctrl_index_update_en;
        logic [total_num_pe-1: 0] pe_ctrl_out_mux_sel;
        logic [total_num_pe-1: 0] pe_ctrl_out_reg_en;
    // control ports for FIFOs
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_write;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_read; 
        logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_write;
        logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read;
        logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read_to_outbuffer;
        logic [total_num_pe-1: 0] pe_ctrl_out_mux_sel_PE;//
        logic [total_num_pe-1: 0] pe_ctrl_out_to_right_pe_en;	
        logic [total_num_pe-1: 0] pe_ctrl_add_zero;
        logic [total_num_pe-1: 0] pe_ctrl_feed_zero_to_accfifo;
        logic [total_num_pe-1: 0] pe_ctrl_accfifo_head_to_tail;
        logic [total_num_pe-1: 0] pe_ctrl_which_accfifo_for_compute;
        logic [total_num_pe-1: 0] pe_ctrl_which_afifo_for_compute; 
        logic [total_num_pe-1: 0] pe_ctrl_compute_AFIFO_read_delay_enable;
        logic [num_pe_col-1: 0] pe_ctrl_last_row_shadow_AFIFO_write;

    /**** End of Ports to control the PE array***/

    /**** Ports from PE array for some info ****/
        logic [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_PD0;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_full;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_empty;
        logic [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_afifo_out;
    /**** End of Ports from PE array for some info****/

    /**** Ports for systolic chain*******************/
        logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_empty;
    /****** Configuration Ports********/
    


    // Instance
    FPAP_for_power_analysis #(
            .num_pe_row(num_pe_row),
            .num_pe_col(num_pe_col)
        )u_FPAP_for_power_analysis(
    	.compressed_act_in_fr_dummy_ctrl             (compressed_act_in_fr_dummy_ctrl             ),
        .last_row_shadow_AFIFO_data_in_fr_dummy_ctrl (last_row_shadow_AFIFO_data_in_fr_dummy_ctrl ),
        .WRegs_fr_dummy_ctrl                         (WRegs_fr_dummy_ctrl                         ),
        .WBPRs_fr_dummy_ctrl                         (WBPRs_fr_dummy_ctrl                         ),
        .WETCs_fr_dummy_ctrl                         (WETCs_fr_dummy_ctrl                         ),
        .compressed_act_in_sel                       (compressed_act_in_sel                       ),
        .last_row_shadow_afifo_in_sel                (last_row_shadow_afifo_in_sel                ),
        .wreg_in_sel                                 (wreg_in_sel                                 ),
        .ActBuff_data_in                             (ActBuff_data_in                             ),
        .ActBuff_wEn_AH                              (ActBuff_wEn_AH                              ),
        .ActBuff_rEn_AH                              (ActBuff_rEn_AH                              ),
        .ActBuff_wAddr                               (ActBuff_wAddr                               ),
        .ActBuff_rAddr                               (ActBuff_rAddr                               ),
        .WBuff_weight_load_en                        (WBuff_weight_load_en                        ),
        .WBuff_wAddr                                 (WBuff_wAddr                                 ),
        .WBuff_rAddr                                 (WBuff_rAddr                                 ),
        .WBuff_data_in                               (WBuff_data_in                               ),
        .WBuff_wEn_AH                                (WBuff_wEn_AH                                ),
        .WBuff_rEn_AH                                (WBuff_rEn_AH                                ),
        .WBuff_clear_all_wregs                       (WBuff_clear_all_wregs                       ),
        .OutBuff_data_out_even                       (OutBuff_data_out_even                       ),
        .OutBuff_data_out_odd                        (OutBuff_data_out_odd                        ),
        .OutBuff_data_in_fr_dummy_ctrl_even          (OutBuff_data_in_fr_dummy_ctrl_even          ),
        .OutBuff_data_in_fr_dummy_ctrl_odd           (OutBuff_data_in_fr_dummy_ctrl_odd           ),
        .OutBuff_wEn_even_AH                         (OutBuff_wEn_even_AH                         ),
        .OutBuff_wEn_odd_AH                          (OutBuff_wEn_odd_AH                          ),
        .OutBuff_rEn_even_AH                         (OutBuff_rEn_even_AH                         ),
        .OutBuff_rEn_odd_AH                          (OutBuff_rEn_odd_AH                          ),
        .OutBuff_wAddr_even                          (OutBuff_wAddr_even                          ),
        .OutBuff_wAddr_odd                           (OutBuff_wAddr_odd                           ),
        .OutBuff_rAddr_even                          (OutBuff_rAddr_even                          ),
        .OutBuff_rAddr_odd                           (OutBuff_rAddr_odd                           ),
        .next_data_fr_array_valid                    (next_data_fr_array_valid                    ),
        .OutBuff_ctrl_signal_sel                     (OutBuff_ctrl_signal_sel                     ),
        .pe_ctrl_n_ap                                (pe_ctrl_n_ap                                ),
        .pe_ctrl_PAMAC_BPEB_sel                      (pe_ctrl_PAMAC_BPEB_sel                      ),
        .pe_ctrl_PAMAC_DFF_en                        (pe_ctrl_PAMAC_DFF_en                        ),
        .pe_ctrl_PAMAC_first_cycle                   (pe_ctrl_PAMAC_first_cycle                   ),
        .pe_ctrl_PAMAC_MDecomp                       (pe_ctrl_PAMAC_MDecomp                       ),
        .pe_ctrl_PAMAC_AWDecomp                      (pe_ctrl_PAMAC_AWDecomp                      ),
        .pe_ctrl_current_tap                         (pe_ctrl_current_tap                         ),
        .pe_ctrl_DRegs_en                            (pe_ctrl_DRegs_en                            ),
        .pe_ctrl_DRegs_clr                           (pe_ctrl_DRegs_clr                           ),
        .pe_ctrl_DRegs_in_sel                        (pe_ctrl_DRegs_in_sel                        ),
        .pe_ctrl_index_update_en                     (pe_ctrl_index_update_en                     ),
        .pe_ctrl_out_mux_sel                         (pe_ctrl_out_mux_sel                         ),
        .pe_ctrl_out_reg_en                          (pe_ctrl_out_reg_en                          ),
        .pe_ctrl_AFIFO_write                         (pe_ctrl_AFIFO_write                         ),
        .pe_ctrl_AFIFO_read                          (pe_ctrl_AFIFO_read                          ),
        .pe_ctrl_ACCFIFO_write                       (pe_ctrl_ACCFIFO_write                       ),
        .pe_ctrl_ACCFIFO_read                        (pe_ctrl_ACCFIFO_read                        ),
        .pe_ctrl_ACCFIFO_read_to_outbuffer           (pe_ctrl_ACCFIFO_read_to_outbuffer           ),
        .pe_ctrl_out_mux_sel_PE                      (pe_ctrl_out_mux_sel_PE                      ),
        .pe_ctrl_out_to_right_pe_en                  (pe_ctrl_out_to_right_pe_en                  ),
        .pe_ctrl_add_zero                            (pe_ctrl_add_zero                            ),
        .pe_ctrl_feed_zero_to_accfifo                (pe_ctrl_feed_zero_to_accfifo                ),
        .pe_ctrl_accfifo_head_to_tail                (pe_ctrl_accfifo_head_to_tail                ),
        .pe_ctrl_which_accfifo_for_compute           (pe_ctrl_which_accfifo_for_compute           ),
        .pe_ctrl_which_afifo_for_compute             (pe_ctrl_which_afifo_for_compute             ),
        .pe_ctrl_compute_AFIFO_read_delay_enable     (pe_ctrl_compute_AFIFO_read_delay_enable     ),
        .pe_ctrl_last_row_shadow_AFIFO_write         (pe_ctrl_last_row_shadow_AFIFO_write         ),
        .pe_ctrl_PD0                                 (pe_ctrl_PD0                                 ),
        .pe_ctrl_AFIFO_full                          (pe_ctrl_AFIFO_full                          ),
        .pe_ctrl_AFIFO_empty                         (pe_ctrl_AFIFO_empty                         ),
        .pe_data_afifo_out                           (pe_data_afifo_out                           ),
        .pe_ctrl_ACCFIFO_empty                       (pe_ctrl_ACCFIFO_empty                       ),
        .clk                                         (clk                                         ),
        .rst_n                                       (rst_n                                       )
    );

    FPAP_Ctrl DUT(
    	.compressed_act_in_fr_dummy_ctrl             (compressed_act_in_fr_dummy_ctrl             ),
        .last_row_shadow_AFIFO_data_in_fr_dummy_ctrl (last_row_shadow_AFIFO_data_in_fr_dummy_ctrl ),
        .WRegs_fr_dummy_ctrl                         (WRegs_fr_dummy_ctrl                         ),
        .WBPRs_fr_dummy_ctrl                         (WBPRs_fr_dummy_ctrl                         ),
        .WETCs_fr_dummy_ctrl                         (WETCs_fr_dummy_ctrl                         ),
        .compressed_act_in_sel                       (compressed_act_in_sel                       ),
        .last_row_shadow_afifo_in_sel                (last_row_shadow_afifo_in_sel                ),
        .wreg_in_sel                                 (wreg_in_sel                                 ),
        .ActBuff_data_in                             (ActBuff_data_in                             ),
        .ActBuff_wEn_AH                              (ActBuff_wEn_AH                              ),
        .ActBuff_rEn_AH                              (ActBuff_rEn_AH                              ),
        .ActBuff_wAddr                               (ActBuff_wAddr                               ),
        .ActBuff_rAddr                               (ActBuff_rAddr                               ),
        .WBuff_weight_load_en                        (WBuff_weight_load_en                        ),
        .WBuff_wAddr                                 (WBuff_wAddr                                 ),
        .WBuff_rAddr                                 (WBuff_rAddr                                 ),
        .WBuff_data_in                               (WBuff_data_in                               ),
        .WBuff_wEn_AH                                (WBuff_wEn_AH                                ),
        .WBuff_rEn_AH                                (WBuff_rEn_AH                                ),
        .WBuff_clear_all_wregs                       (WBuff_clear_all_wregs                       ),
        .OutBuff_data_in_fr_dummy_ctrl_even          (OutBuff_data_in_fr_dummy_ctrl_even          ),
        .OutBuff_data_in_fr_dummy_ctrl_odd           (OutBuff_data_in_fr_dummy_ctrl_odd           ),
        .OutBuff_wEn_even_AH                         (OutBuff_wEn_even_AH                         ),
        .OutBuff_wEn_odd_AH                          (OutBuff_wEn_odd_AH                          ),
        .OutBuff_rEn_even_AH                         (OutBuff_rEn_even_AH                         ),
        .OutBuff_rEn_odd_AH                          (OutBuff_rEn_odd_AH                          ),
        .OutBuff_wAddr_even                          (OutBuff_wAddr_even                          ),
        .OutBuff_wAddr_odd                           (OutBuff_wAddr_odd                           ),
        .OutBuff_rAddr_even                          (OutBuff_rAddr_even                          ),
        .OutBuff_rAddr_odd                           (OutBuff_rAddr_odd                           ),
        .next_data_fr_array_valid                    (next_data_fr_array_valid                    ),
        .OutBuff_ctrl_signal_sel                     (OutBuff_ctrl_signal_sel                     ),
        .pe_ctrl_n_ap                                (pe_ctrl_n_ap                                ),
        .pe_ctrl_PAMAC_BPEB_sel                      (pe_ctrl_PAMAC_BPEB_sel                      ),
        .pe_ctrl_PAMAC_DFF_en                        (pe_ctrl_PAMAC_DFF_en                        ),
        .pe_ctrl_PAMAC_first_cycle                   (pe_ctrl_PAMAC_first_cycle                   ),
        .pe_ctrl_PAMAC_MDecomp                       (pe_ctrl_PAMAC_MDecomp                       ),
        .pe_ctrl_PAMAC_AWDecomp                      (pe_ctrl_PAMAC_AWDecomp                      ),
        .pe_ctrl_current_tap                         (pe_ctrl_current_tap                         ),
        .pe_ctrl_DRegs_en                            (pe_ctrl_DRegs_en                            ),
        .pe_ctrl_DRegs_clr                           (pe_ctrl_DRegs_clr                           ),
        .pe_ctrl_DRegs_in_sel                        (pe_ctrl_DRegs_in_sel                        ),
        .pe_ctrl_index_update_en                     (pe_ctrl_index_update_en                     ),
        .pe_ctrl_out_mux_sel                         (pe_ctrl_out_mux_sel                         ),
        .pe_ctrl_out_reg_en                          (pe_ctrl_out_reg_en                          ),
        .pe_ctrl_AFIFO_write                         (pe_ctrl_AFIFO_write                         ),
        .pe_ctrl_AFIFO_read                          (pe_ctrl_AFIFO_read                          ),
        .pe_ctrl_ACCFIFO_write                       (pe_ctrl_ACCFIFO_write                       ),
        .pe_ctrl_ACCFIFO_read                        (pe_ctrl_ACCFIFO_read                        ),
        .pe_ctrl_ACCFIFO_read_to_outbuffer           (pe_ctrl_ACCFIFO_read_to_outbuffer           ),
        .pe_ctrl_out_mux_sel_PE                      (pe_ctrl_out_mux_sel_PE                      ),
        .pe_ctrl_out_to_right_pe_en                  (pe_ctrl_out_to_right_pe_en                  ),
        .pe_ctrl_add_zero                            (pe_ctrl_add_zero                            ),
        .pe_ctrl_feed_zero_to_accfifo                (pe_ctrl_feed_zero_to_accfifo                ),
        .pe_ctrl_accfifo_head_to_tail                (pe_ctrl_accfifo_head_to_tail                ),
        .pe_ctrl_which_accfifo_for_compute           (pe_ctrl_which_accfifo_for_compute           ),
        .pe_ctrl_which_afifo_for_compute             (pe_ctrl_which_afifo_for_compute             ),
        .pe_ctrl_compute_AFIFO_read_delay_enable     (pe_ctrl_compute_AFIFO_read_delay_enable     ),
        .pe_ctrl_last_row_shadow_AFIFO_write         (pe_ctrl_last_row_shadow_AFIFO_write         ),
        .pe_ctrl_PD0                                 (pe_ctrl_PD0                                 ),
        .pe_ctrl_AFIFO_full                          (pe_ctrl_AFIFO_full                          ),
        .pe_ctrl_AFIFO_empty                         (pe_ctrl_AFIFO_empty                         ),
        .pe_data_afifo_out                           (pe_data_afifo_out                           ),
        .pe_ctrl_ACCFIFO_empty                       (pe_ctrl_ACCFIFO_empty                       ),
        .clk                                         (clk                                         )
    );
    
    //clock
    initial begin
        clk = 0;
        forever begin
            #10 clk = ~clk;
        end
    end

    /************ Helper Variables********************/
    int kernel_size_per_layer[52] = '{3,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1,3,1,1};
    int is_depthwise[52] = '{0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0};
    int fm_size_per_layer[52] = '{226,114,112,112,114,56,56,58,56,56,58,28,28,30,28,28,30,28,28,30,14,14,16,14,14,16,14,14,16,14,14,16,14,14,16,14,14,16,14,14,16,7,7,9,7,7,9,7,7,9,7,7};
    int in_ch_per_layer[52] = '{3,32,32,16,96,96,24,144,144,24,144,144,32,192,192,32,192,192,32,192,192,64,384,384,64,384,384,64,384,384,64,384,384,96,576,576,96,576,576,96,576,576,160,960,960,160,960,960,160,960,960,320};
    int out_ch_per_layer[52] = '{32,32,16,96,96,24,144,144,24,144,144,32,192,192,32,192,192,32,192,192,64,384,384,64,384,384,64,384,384,64,384,384,96,576,576,96,576,576,96,576,576,160,960,960,160,960,960,160,960,960,320,1280};
    int stride_per_layer[52] = '{2,1,1,1,2,1,1,1,1,1,2,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1};

    int start_layer;
    int end_layer;
    int current_layer;

    /******Main**********/
    initial begin
        string act_file_path;
        string act_dir_path;
        string weight_file_path;
        string weight_file_name;
        string weight_full_path;
        int kernel_size;
        string layer_str;
        int log_fp;
        int total_op_this_layer;
        logic [64-1: 0] start_time;
        logic [64-1: 0] end_time;
        int cycle_this_layer;
        start_layer = 1;
        end_layer = 3;
        act_dir_path = "C:/Users/jy/Desktop/mopu-testbench/testdata/mobilenet";
        weight_file_path = {act_dir_path, "/weights"};
        rst_n = 1;
        #5;
        rst_n = 0;
        #20;
        rst_n = 1;
        @(posedge clk);
        for(current_layer = start_layer; current_layer<end_layer;current_layer++) begin
            kernel_size = kernel_size_per_layer[current_layer];
            if(stride_per_layer[current_layer] != 1) begin
                continue;
            end
            $display("@%t, Start the %d-th layer(%s).", $time, current_layer, 
                        is_depthwise[current_layer] == 1 ? "DW_Conv" : "NormalConv");
            layer_str.itoa(current_layer);
            act_file_path = {act_dir_path, "/act_conv_", layer_str};
            if(is_depthwise[current_layer] == 1) begin
                act_file_path = {act_file_path, "_dw"};
            end
            weight_file_name = {"conv", layer_str, "weight.dat"};
            weight_full_path = {weight_file_path, "/", weight_file_name};
            if(is_depthwise[current_layer] == 1) begin
                DUT.dw_conv_one_layer_compute_buff_ctrl(
                    act_file_path,
                    weight_full_path,
                    stride_per_layer[current_layer],
                    out_ch_per_layer[current_layer],
                    fm_size_per_layer[current_layer],
                    kernel_size_per_layer[current_layer]
                );
            end
            else begin
                DUT.normal_conv_one_layer_compute_buff_ctrl(
                    act_file_path,
                    weight_full_path,
                    in_ch_per_layer[current_layer],
                    out_ch_per_layer[current_layer],
                    stride_per_layer[current_layer],
                    fm_size_per_layer[current_layer],
                    kernel_size_per_layer[current_layer]
                );
            end
        end
        $finish;
    end

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