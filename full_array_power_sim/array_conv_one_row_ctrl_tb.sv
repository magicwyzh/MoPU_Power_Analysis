`timescale 1ns/1ns
module array_conv_one_row_ctrl_tb #(parameter 
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
    )();

           /**** Ports to control the PE array (started with ``pe_ctrl/data")*****/
        // AFIFO data
        logic [num_pe_row-1: 0][compressed_act_width-1: 0] pe_data_compressed_act_in;
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
    /**** End of Ports to control the PE array***/

    /**** Ports from PE array for some info ****/
        logic [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_PD0;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_full;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_empty;
        logic [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_afifo_out;
    /**** End of Ports from PE array for some info****/

    /**** Ports of some weights info*****************/
        logic [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs;
        logic [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs;
        logic [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs;
    /**** End of ports for weights info**************/

    /**** Transactions with global scheduler *******/
        logic clk;
        logic array_conv_one_row_start;
        logic array_conv_one_row_done;
        int kernel_size; 
        int quantized_bits; 
        logic first_acc_flag;
        logic [4-1:0] n_ap;
        logic rst_n;
        logic [num_pe_row-1: 0][output_width-1:0] out_fr_rightest_PE;
        logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_empty;
    /**** End of Transactions with global scheduler*****/



    ArrayConvOneRowCtrl #(
        .num_pe_col(num_pe_col),
        .num_pe_row(num_pe_row))
    DUT_Ctrl(
    	.pe_data_compressed_act_in    (pe_data_compressed_act_in    ),
        .pe_ctrl_n_ap                 (pe_ctrl_n_ap                 ),
        .pe_ctrl_PAMAC_BPEB_sel       (pe_ctrl_PAMAC_BPEB_sel       ),
        .pe_ctrl_PAMAC_DFF_en         (pe_ctrl_PAMAC_DFF_en         ),
        .pe_ctrl_PAMAC_first_cycle    (pe_ctrl_PAMAC_first_cycle    ),
        .pe_ctrl_PAMAC_MDecomp        (pe_ctrl_PAMAC_MDecomp        ),
        .pe_ctrl_PAMAC_AWDecomp       (pe_ctrl_PAMAC_AWDecomp       ),
        .pe_ctrl_current_tap          (pe_ctrl_current_tap          ),
        .pe_ctrl_DRegs_en             (pe_ctrl_DRegs_en             ),
        .pe_ctrl_DRegs_clr            (pe_ctrl_DRegs_clr            ),
        .pe_ctrl_DRegs_in_sel         (pe_ctrl_DRegs_in_sel         ),
        .pe_ctrl_index_update_en      (pe_ctrl_index_update_en      ),
        .pe_ctrl_out_mux_sel          (pe_ctrl_out_mux_sel          ),
        .pe_ctrl_out_reg_en           (pe_ctrl_out_reg_en           ),
        .pe_ctrl_AFIFO_write          (pe_ctrl_AFIFO_write          ),
        .pe_ctrl_AFIFO_read           (pe_ctrl_AFIFO_read           ),
        .pe_ctrl_ACCFIFO_write        (pe_ctrl_ACCFIFO_write        ),
        .pe_ctrl_ACCFIFO_read         (pe_ctrl_ACCFIFO_read         ),
        .pe_ctrl_ACCFIFO_read_to_outbuffer (pe_ctrl_ACCFIFO_read_to_outbuffer),
        .pe_ctrl_out_mux_sel_PE       (pe_ctrl_out_mux_sel_PE       ),
        .pe_ctrl_out_to_right_pe_en   (pe_ctrl_out_to_right_pe_en   ),
        .pe_ctrl_add_zero             (pe_ctrl_add_zero             ),
        .pe_ctrl_feed_zero_to_accfifo (pe_ctrl_feed_zero_to_accfifo ),
        .pe_ctrl_accfifo_head_to_tail (pe_ctrl_accfifo_head_to_tail ),
        .pe_ctrl_PD0                  (pe_ctrl_PD0                  ),
        .pe_ctrl_AFIFO_full           (pe_ctrl_AFIFO_full           ),
        .pe_ctrl_AFIFO_empty          (pe_ctrl_AFIFO_empty          ),
        .pe_data_afifo_out            (pe_data_afifo_out            ),
        .pe_ctrl_ACCFIFO_empty        (pe_ctrl_ACCFIFO_empty),
        .WRegs                        (WRegs                        ),
        .WBPRs                        (WBPRs                        ),
        .WETCs                        (WETCs                        ),
        .clk                          (clk                          ),
        .array_conv_one_row_start     (array_conv_one_row_start     ),
        .array_conv_one_row_done      (array_conv_one_row_done      ),
        .kernel_size                  (kernel_size                  ),
        .quantized_bits               (quantized_bits               ),
        .first_acc_flag               (first_acc_flag               ),
        .n_ap                         (n_ap                         )
    );
    
    PEArray_for_power_analysis #(
            .num_pe_row(num_pe_row),
            .num_pe_col(num_pe_col))
        u_PEArray_for_power_analysis(
    	.pe_data_compressed_act_in    (pe_data_compressed_act_in    ),
        .pe_ctrl_n_ap                 (pe_ctrl_n_ap                 ),
        .pe_ctrl_PAMAC_BPEB_sel       (pe_ctrl_PAMAC_BPEB_sel       ),
        .pe_ctrl_PAMAC_DFF_en         (pe_ctrl_PAMAC_DFF_en         ),
        .pe_ctrl_PAMAC_first_cycle    (pe_ctrl_PAMAC_first_cycle    ),
        .pe_ctrl_PAMAC_MDecomp        (pe_ctrl_PAMAC_MDecomp        ),
        .pe_ctrl_PAMAC_AWDecomp       (pe_ctrl_PAMAC_AWDecomp       ),
        .pe_ctrl_current_tap          (pe_ctrl_current_tap          ),
        .pe_ctrl_DRegs_en             (pe_ctrl_DRegs_en             ),
        .pe_ctrl_DRegs_clr            (pe_ctrl_DRegs_clr            ),
        .pe_ctrl_DRegs_in_sel         (pe_ctrl_DRegs_in_sel         ),
        .pe_ctrl_index_update_en      (pe_ctrl_index_update_en      ),
        .pe_ctrl_out_mux_sel          (pe_ctrl_out_mux_sel          ),
        .pe_ctrl_out_reg_en           (pe_ctrl_out_reg_en           ),
        .pe_ctrl_AFIFO_write          (pe_ctrl_AFIFO_write          ),
        .pe_ctrl_AFIFO_read           (pe_ctrl_AFIFO_read           ),
        .pe_ctrl_ACCFIFO_write        (pe_ctrl_ACCFIFO_write        ),
        .pe_ctrl_ACCFIFO_read         (pe_ctrl_ACCFIFO_read         ),
        .pe_ctrl_ACCFIFO_read_to_outbuffer         (pe_ctrl_ACCFIFO_read_to_outbuffer         ),
        .pe_ctrl_out_mux_sel_PE       (pe_ctrl_out_mux_sel_PE       ),
        .pe_ctrl_out_to_right_pe_en   (pe_ctrl_out_to_right_pe_en   ),
        .pe_ctrl_add_zero             (pe_ctrl_add_zero             ),
        .pe_ctrl_feed_zero_to_accfifo (pe_ctrl_feed_zero_to_accfifo ),
        .pe_ctrl_accfifo_head_to_tail (pe_ctrl_accfifo_head_to_tail ),
        .pe_ctrl_which_accfifo_for_compute(pe_ctrl_which_accfifo_for_compute),
        .pe_ctrl_PD0                  (pe_ctrl_PD0                  ),
        .pe_ctrl_AFIFO_full           (pe_ctrl_AFIFO_full           ),
        .pe_ctrl_AFIFO_empty          (pe_ctrl_AFIFO_empty          ),
        .pe_data_afifo_out            (pe_data_afifo_out            ),
        .WRegs                        (WRegs                        ),
        .WBPRs                        (WBPRs                        ),
        .WETCs                        (WETCs                        ),
        .out_fr_rightest_PE           (out_fr_rightest_PE           ),
        .pe_ctrl_ACCFIFO_empty        (pe_ctrl_ACCFIFO_empty        ),
        .n_ap                         (n_ap                         ),
        .clk                          (clk                          ),
        .rst_n                        (rst_n                        )
    );
    
    initial begin
        clk = 0;
        forever 
            #10 clk = ~clk;
    end
    /**Init something**/
    initial begin
        pe_ctrl_which_accfifo_for_compute = 0;
        array_conv_one_row_start = 0;
        kernel_size = 3;
        quantized_bits = 8;
        first_acc_flag = 0;
        n_ap = 0;
        rst_n = 1;
        WRegs[0] = 0;
        WETCs[0] = 0;
        WBPRs[0] = 0;
    end

    /*** some signals for easy debuggging**/
    logic is_loading_fr_accfifo;
    logic is_convolving;

    /**Main***/
    
    initial begin
        string file_name;
        string file_path;
        
        is_loading_fr_accfifo = 0;
        is_convolving = 0;
        file_path = "C:/Users/dell/Desktop/mopu-testbench/testdata/mobilenet/act_conv_3";
        file_name = "test2.dat";
        file_path = {file_path, "/", file_name};
        #5;
        rst_n = 0; 
        first_acc_flag = 1;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        pe_ctrl_which_accfifo_for_compute[0] = 0;
        for(int i = 0; i < kernel_size; i++) begin
            WRegs[0][i*weight_width +: weight_width] = i+1;
            BPEB_Enc_task(
                WRegs[0][i*weight_width +: weight_width], /*in*/
                n_ap, 
                WBPRs[0][i*weight_bpr_width +: weight_bpr_width], /**encoded results**/
                WETCs[0][i*ETC_width +: ETC_width]
            );
        end
        DUT_Ctrl.load_compressed_act_rows_from_file(0, file_path);
        @(posedge clk);
        is_convolving = 1;
        DUT_Ctrl.array_normal_conv_one_row_task();
        is_convolving = 0;
        repeat(5) begin
            @(posedge clk);
        end
        is_convolving = 1;
        first_acc_flag = 0;
        //then should be accumulating partial sum.
        DUT_Ctrl.array_normal_conv_one_row_task();
        is_convolving = 0;
        repeat(5) begin
            @(posedge clk);
        end
        pe_ctrl_which_accfifo_for_compute[0] = 1;
        @(posedge clk);
        fork
            begin
                is_loading_fr_accfifo = 1;
                DUT_Ctrl.single_pe_give_out_results(0, 0);
                is_loading_fr_accfifo = 0;
            end
            begin
                is_convolving = 1;
                first_acc_flag = 1;
                DUT_Ctrl.array_normal_conv_one_row_task();
                //is_convolving = 0;
                //repeat(5) @(posedge clk);
                //is_convolving = 1;
                first_acc_flag = 0;
                DUT_Ctrl.array_normal_conv_one_row_task();
                is_convolving = 0;
            end
        join
        repeat(5) begin
            @(posedge clk);
        end
        pe_ctrl_which_accfifo_for_compute[0] = 0;

        $finish;
    end
    task BPEB_Enc_task(
        input [16-1: 0] in,
        input [4-1: 0] n_ap,
        output [8*3-1: 0] encoded_result,
        output [4-1: 0] ETC
        
    ); 
    begin
        for(int i = 0; i < 8; i++ ) begin
            if(i >= n_ap) begin
                encoded_result[3*i+1] = in[2*i];
                encoded_result[3*i+2] = in[2*i+1];
                encoded_result[3*i] = i==0 ? 0 : in[2*i-1];
            end
            else begin
                //abandoned terms
                encoded_result[3*i+2 -: 3] = 3'b000;
            end
        end
    
        ETC = 0;
        for(int t=0; t < 8; t++) begin
            if(encoded_result[3*(t+1)-1 -: 3] != 3'b000 && encoded_result[3*(t+1)-1 -: 3] != 3'b111) begin
                ETC += 1;
            end
        end
    end
    endtask
    
    
endmodule