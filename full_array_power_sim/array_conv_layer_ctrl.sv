module ArrayConvLayerCtrl#(parameter
    num_pe_row = 4,
    num_pe_col = 4,
    total_num_pe = num_pe_row * num_pe_col,
    //parameter for conv layer controller
    max_outch_per_time = 256,
    ACCFIFO_size = 32,
    tiled_col_size = ACCFIFO_size,
    inch_group_size = 16,
    outch_group_size = (max_outch_per_time + num_pe_col - 1) / num_pe_col,
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
        /**** Ports from conv_one_row_ctrl to control the PE array (started with ``pe_ctrl/data")*****/
        // AFIFO data
            output [num_pe_row-1: 0][compressed_act_width-1: 0] pe_data_compressed_act_in,
            output [num_pe_col-1: 0][compressed_act_width-1: 0] pe_data_last_row_shadow_AFIFO_data_in,
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
            output [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read, //read when computing 
            output [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read_to_outbuffer,//read when let data goto out buffer
            output [total_num_pe-1: 0] pe_ctrl_out_mux_sel_PE,// 0 is from ACCFIFO, 1 is from left PE
            output [total_num_pe-1: 0] pe_ctrl_out_to_right_pe_en,	
            output [total_num_pe-1: 0] pe_ctrl_add_zero,
            output [total_num_pe-1: 0] pe_ctrl_feed_zero_to_accfifo,
            output [total_num_pe-1: 0] pe_ctrl_accfifo_head_to_tail,
            output [num_pe_col-1: 0] pe_ctrl_last_row_shadow_AFIFO_write,
        /**** End of Ports to control the PE array***/

        /**** Ports from PE array for some info ****/
            input [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_PD0,
            input [total_num_pe-1: 0] pe_ctrl_AFIFO_full,
            input [total_num_pe-1: 0] pe_ctrl_AFIFO_empty,
            input [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_afifo_out,
            input [total_num_pe-1: 0] pe_ctrl_ACCFIFO_empty,
        /**** End of Ports from PE array for some info****/

        /**** Ports of some weights info, generated by this module*****************/
            output logic [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs,
            output logic [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs,
            output logic [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs,
        /**** End of ports for weights info**************/

        /***** Ports from this module to schedule the whole convolutional layer***/
            output logic [total_num_pe-1: 0] pe_ctrl_which_accfifo_for_compute,
            output logic [total_num_pe-1: 0] pe_ctrl_compute_AFIFO_read_delay_enable,
            output logic [total_num_pe-1: 0] pe_ctrl_which_afifo_for_compute,
        /******* End of Conv Layer Ctrl Ports********/
            output array_next_cycle_data_to_outbuff_valid,
            input clk
    );
    int kernel_size_to_row_ctrl;
    int quantized_bits_to_row_ctrl;
    logic [total_num_pe-1: 0] first_acc_flag;
    logic [4-1: 0] n_ap;
    /****Instance of ConvOneRowCtrl*****/
    ArrayConvOneRowCtrl #(
        .num_pe_col(num_pe_col),
        .num_pe_row(num_pe_row),
        .nb_taps(nb_taps),
        .activation_width(activation_width),
        .weight_width(weight_width),
        .tap_width(tap_width),
        .ETC_width(ETC_width)
    ) ConvOneRowCtrl(
    	.pe_data_compressed_act_in              (pe_data_compressed_act_in              ),
        .pe_data_last_row_shadow_AFIFO_data_in  (pe_data_last_row_shadow_AFIFO_data_in  ),
        .pe_ctrl_n_ap                           (pe_ctrl_n_ap                           ),
        .pe_ctrl_PAMAC_BPEB_sel                 (pe_ctrl_PAMAC_BPEB_sel                 ),
        .pe_ctrl_PAMAC_DFF_en                   (pe_ctrl_PAMAC_DFF_en                   ),
        .pe_ctrl_PAMAC_first_cycle              (pe_ctrl_PAMAC_first_cycle              ),
        .pe_ctrl_PAMAC_MDecomp                  (pe_ctrl_PAMAC_MDecomp                  ),
        .pe_ctrl_PAMAC_AWDecomp                 (pe_ctrl_PAMAC_AWDecomp                 ),
        .pe_ctrl_current_tap                    (pe_ctrl_current_tap                    ),
        .pe_ctrl_DRegs_en                       (pe_ctrl_DRegs_en                       ),
        .pe_ctrl_DRegs_clr                      (pe_ctrl_DRegs_clr                      ),
        .pe_ctrl_DRegs_in_sel                   (pe_ctrl_DRegs_in_sel                   ),
        .pe_ctrl_index_update_en                (pe_ctrl_index_update_en                ),
        .pe_ctrl_out_mux_sel                    (pe_ctrl_out_mux_sel                    ),
        .pe_ctrl_out_reg_en                     (pe_ctrl_out_reg_en                     ),
        .pe_ctrl_AFIFO_write                    (pe_ctrl_AFIFO_write                    ),
        .pe_ctrl_AFIFO_read                     (pe_ctrl_AFIFO_read                     ),
        .pe_ctrl_ACCFIFO_write                  (pe_ctrl_ACCFIFO_write                  ),
        .pe_ctrl_ACCFIFO_read                   (pe_ctrl_ACCFIFO_read                   ),
        .pe_ctrl_ACCFIFO_read_to_outbuffer      (pe_ctrl_ACCFIFO_read_to_outbuffer      ),
        .pe_ctrl_out_mux_sel_PE                 (pe_ctrl_out_mux_sel_PE                 ),
        .pe_ctrl_out_to_right_pe_en             (pe_ctrl_out_to_right_pe_en             ),
        .pe_ctrl_add_zero                       (pe_ctrl_add_zero                       ),
        .pe_ctrl_feed_zero_to_accfifo           (pe_ctrl_feed_zero_to_accfifo           ),
        .pe_ctrl_accfifo_head_to_tail           (pe_ctrl_accfifo_head_to_tail           ),
        .pe_ctrl_last_row_shadow_AFIFO_write    (pe_ctrl_last_row_shadow_AFIFO_write    ),
        .pe_ctrl_PD0                            (pe_ctrl_PD0                            ),
        .pe_ctrl_AFIFO_full                     (pe_ctrl_AFIFO_full                     ),
        .pe_ctrl_AFIFO_empty                    (pe_ctrl_AFIFO_empty                    ),
        .pe_data_afifo_out                      (pe_data_afifo_out                      ),
        .pe_ctrl_ACCFIFO_empty                  (pe_ctrl_ACCFIFO_empty                  ),
        .WRegs                                  (WRegs                                  ),
        .WBPRs                                  (WBPRs                                  ),
        .WETCs                                  (WETCs                                  ),
        .clk                                    (clk                                    ),
        .kernel_size                            (kernel_size_to_row_ctrl                            ),
        .quantized_bits                         (quantized_bits_to_row_ctrl                         ),
        .first_acc_flag                         (first_acc_flag                         ),
        .n_ap                                   (n_ap                                   ),
        .array_next_cycle_data_to_outbuff_valid (array_next_cycle_data_to_outbuff_valid )
    );
    
    /**** End of ConvOneRowCtrl Instance****/

    /**** Variable to load data from file***/
    logic [weight_width-1: 0] weights_this_layer[3*3*512*512];// set up enough space for weights

    /*** some debug signals**/
    logic is_dw_convolving;
    logic is_loading_fr_accfifo;
    logic is_normal_convolving;

    /**** Utils functions and tasks*******/
    task clear_WRegs();
        WRegs = 0;
        WBPRs = 0;
        WETCs = 0;
    endtask
    // this task load weights from file and also set the 'kernel_size_to_row_ctrl'
    task load_weights_this_layer_from_file(
        input string file_path,
        input int kernel_size
    );
        kernel_size_to_row_ctrl = kernel_size;
        $readmemh(file_path, weights_this_layer);
    endtask
    // load not only WRegs, but also WETCs & WBPRs
    task load_WRegs(
        input int co,
        input int ci,
        input int k_row,
        input int nb_ci,
        input int kernel_size,
        input logic [4-1: 0] n_ap,
        input int pe_col_idx
    );
    for(int i = 0; i < kernel_size; i ++ ) begin
        WRegs[pe_col_idx][(i+1)*weight_width-1 -: weight_width] = find_weight(co, ci, k_row, i, nb_ci, kernel_size );
        BPEB_Enc_task( WRegs[pe_col_idx][(i+1)*weight_width-1 -: weight_width],
                    n_ap,
                    WBPRs[pe_col_idx][(i+1)*weight_bpr_width-1 -: weight_bpr_width],
                    WETCs[pe_col_idx][(i+1)*ETC_width-1 -: ETC_width]
        );
    end
    //$display("Enter Load_WRegs, pe_col_idx = %d, WETCs = 0x%x", pe_col_idx, WETCs);
    endtask

    function [weight_width-1: 0] find_weight(input int co, input int ci, input int kH, input int kW, 
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
    //called to check before start the dw_conv of this channel
    function logic is_dw_conv_zero_weights_channel(input int ch_idx);
        logic [weight_width-1: 0] temp;
        for(int i = 0; i < kernel_size_to_row_ctrl; i++) begin
            for(int j = 0; j < kernel_size_to_row_ctrl; j++) begin
                temp = find_weight(
                    ch_idx, //co 
                    0, //ci
                    j, //kernel_row
                    i, //kernel_col
                    1, //nb_ci
                    kernel_size_to_row_ctrl //kernel_size
                    );
                if(temp != 0)begin
                    return 0;
                end
            end
        end
        return 1;
    endfunction
    // the give out results procedure is not in this task!!
    // Should Remember to change the accfifo after accfifo giveout results!
    task normal_conv_one_infm_tile(
        input int end_of_cin_idx_in_group,
        input int first_cout,
        input int last_cout,
        input int num_convolved_rows,
        input int cin_start_idx,
        input int end_cin_idx,
        input int tiled_row_start,
        input int end_row_idx,
        input int tiled_col_start,
        input int end_col_idx,
        input int cout_start_idx,
        input int end_cout_idx,
        input int num_inch,
        input int num_outch,
        input int fm_size,
        input string infm_file_path
    );
        string infm_file_full_path; // should figure out the file name
        string file_name;
        int infm_col_tile_idx;
        int infm_row_idx;
        logic [total_num_pe-1: 0] first_acc_flag_score_board;
        first_acc_flag_score_board = {total_num_pe{1'b1}};
        is_normal_convolving = 1;
        infm_col_tile_idx = tiled_col_start / ACCFIFO_size;
        for(int cin_inner_group_idx = 0; cin_inner_group_idx < end_of_cin_idx_in_group; cin_inner_group_idx++) begin
            for(int kernel_row = 0; kernel_row < kernel_size_to_row_ctrl; kernel_row++) begin
                //load weights to PE Array
                normal_conv_load_WRegs(
                    cout_start_idx + first_cout,
                    cout_start_idx + last_cout,
                    cin_inner_group_idx+cin_start_idx,
                    kernel_row,
                    num_inch
                );
                // load act_this_row from file~
                if((fm_size - kernel_size_to_row_ctrl + 1) > num_pe_row/2) begin 
                    for(int pe_row_idx = 0; pe_row_idx<num_pe_row; pe_row_idx++) begin
                        infm_row_idx = tiled_row_start + pe_row_idx+kernel_row;
                        if(infm_row_idx < (fm_size - kernel_size_to_row_ctrl + 1)) begin
                            file_name = generate_act_dump_file_name(
                                cin_start_idx + cin_inner_group_idx,
                                infm_row_idx, 
                                infm_col_tile_idx
                            );
                            infm_file_full_path = {infm_file_path, "/", file_name};
                            ConvOneRowCtrl.load_compressed_act_rows_from_file(pe_row_idx, infm_file_full_path);
                        end
                        else begin
                            ConvOneRowCtrl.load_zero_act_row_to_act_this_row(pe_row_idx, fm_size);
                        end
                    end
                end
                else begin
                    // feed the upper half together with the bottom half by same data
                    for(int pe_row_idx = 0; pe_row_idx < (num_pe_row / 2); pe_row_idx++) begin
                        infm_row_idx = tiled_row_start + pe_row_idx+kernel_row;
                        if(infm_row_idx < (fm_size - kernel_size_to_row_ctrl + 1)) begin
                            file_name = generate_act_dump_file_name(
                                cin_start_idx + cin_inner_group_idx,
                                infm_row_idx, 
                                infm_col_tile_idx
                            );
                            infm_file_full_path = {infm_file_path, "/", file_name};
                            ConvOneRowCtrl.load_compressed_act_rows_from_file(pe_row_idx, infm_file_full_path);
                            // copy the results to the bottome half
                            ConvOneRowCtrl.load_compressed_act_rows_from_file(pe_row_idx+(num_pe_row/2), infm_file_full_path);
                        end
                        else begin
                            ConvOneRowCtrl.load_zero_act_row_to_act_this_row(pe_row_idx, fm_size);
                            ConvOneRowCtrl.load_zero_act_row_to_act_this_row(pe_row_idx+(num_pe_row/2), fm_size);
                        end
                    end
                end
                @(posedge clk) #(`HOLD_TIME_DELTA); // why wait? because if not wait, the normal_conv_one_row_task will get wrong wregs...why??
                // compute control
                //first_acc_flag = (kernel_row == 0 && cin_inner_group_idx == 0)? {total_num_pe{1'b1}} : 0;
                // set the first acc flag = 1 if never compute.
                for(int j = 0; j < num_pe_col; j++) begin
                    for(int i = 0; i < num_pe_row; i++) begin
                        if(first_acc_flag_score_board[i * num_pe_col + j] == 1 && WETCs[j] != 0) begin
                            first_acc_flag[i*num_pe_col + j] = 1;
                            first_acc_flag_score_board[i*num_pe_col + j] = 0;
                        end
                        else begin
                            first_acc_flag[i*num_pe_col + j] = 0;
                        end
                    end
                end
                // computing start!
                is_normal_convolving = 1;
                ConvOneRowCtrl.array_normal_conv_one_row_task();
                is_normal_convolving = 0;
            end
        end
        
    endtask

    function string generate_act_dump_file_name(
        input int infm_ch_idx,
        input int infm_row_idx,
        input int infm_col_tile_idx
    );
        string file_name, ch_str,row_str, col_tile_idx_str;
        ch_str.itoa(infm_ch_idx);
        row_str.itoa(infm_row_idx);
        col_tile_idx_str.itoa(infm_col_tile_idx);
        file_name = {"act_dump_ch", ch_str, "_row", row_str, "_tile_idx", col_tile_idx_str, ".dat"};
        return file_name;
    endfunction
    task normal_conv_load_WRegs(
        input int co_start,
        input int co_end, //unreachable index
        input int ci,
        input int krow, 
        input int num_inch
    );
        int cout;

        for(int cc = 0; cc < num_pe_col; cc++) begin
            cout = co_start + cc;
            if(cout >= co_end) begin
                WRegs[cc] = 0;
                WBPRs[cc] = 0;
                WETCs[cc] = 0;
                break; //WRegs/BPRs/ETCs all be zero
            end
            for(int i = 0; i<kernel_size_to_row_ctrl;i++) begin
                WRegs[cc][(i+1)*weight_width-1 -: weight_width] = find_weight(cout, ci, krow, i, num_inch, kernel_size_to_row_ctrl);
                //$display("cc=%d, ksize = %d, i = %d, wregs[cc][i]=%x", cc, kernel_size_to_row_ctrl, i,WRegs[cc][(i+1)*weight_width-1 -: weight_width] );
                BPEB_Enc_task(WRegs[cc][(i+1)*weight_width-1 -: weight_width],
                            n_ap,
                            WBPRs[cc][(i+1)*weight_bpr_width-1 -: weight_bpr_width],
                            WETCs[cc][(i+1)*ETC_width-1 -: ETC_width]
                );
            end
        end
    endtask
    // dw_conv of one infm tile and then give out results, just like in array_dw_conv_one_row_ctrl_4x4_tb.sv
    // the load_infm2d_buffer should called before this task
    // the ch_idx param here is just to figure out which weights channel should be used
    task dw_conv_one_infm_tile(
        input int infm2d_start_row,
        input int ch_idx
    );
        // do not tackle specially when the WRegs are all zero, because the singlePEScheduler 
        // will not let it compute, but just get data from afifo and do inner-array transfer
        // all pe columns share the same wregs
        for(int cc = 0; cc<num_pe_col; cc++) begin
            load_WRegs(ch_idx, 0/*ci*/, 0/*krow*/, 1/*nb_ci*/, kernel_size_to_row_ctrl, n_ap, cc); 
        end
        @(posedge clk) #(`HOLD_TIME_DELTA); // make sure the wregs are new
        pe_ctrl_compute_AFIFO_read_delay_enable = {total_num_pe{1'b1}};
        first_acc_flag = {total_num_pe{1'b1}};
        fork
            ConvOneRowCtrl.load_infm2d_to_array_accord_workload(infm2d_start_row);
            ConvOneRowCtrl.array_dw_conv_one_row_task(1);
            ConvOneRowCtrl.feed_last_pe_row_shadow_afifo(infm2d_start_row+num_pe_row);
        join
        @(posedge clk) #(`HOLD_TIME_DELTA);
        first_acc_flag = 0;
        for(int krow = 1; krow < kernel_size_to_row_ctrl;krow++) begin
            for(int cc = 0; cc<num_pe_col; cc++) begin
                load_WRegs(ch_idx, 0, krow, 1, kernel_size_to_row_ctrl, n_ap, cc); 
            end
            @(posedge clk) #(`HOLD_TIME_DELTA); // make sure the wregs are new
            pe_ctrl_which_afifo_for_compute = ~pe_ctrl_which_afifo_for_compute;
            pe_ctrl_compute_AFIFO_read_delay_enable = krow == (kernel_size_to_row_ctrl-1)? 0 : {total_num_pe{1'b1}}; 
            fork
                ConvOneRowCtrl.array_dw_conv_one_row_task(0);
                begin
                    if(krow!=kernel_size_to_row_ctrl-1) begin
                        ConvOneRowCtrl.feed_last_pe_row_shadow_afifo(infm2d_start_row+num_pe_row+krow);
                    end
                end
            join
        end
        first_acc_flag = 0;
        pe_ctrl_compute_AFIFO_read_delay_enable = 0;
    endtask
    
    task conv_one_row_ctrl_load_infm2d_fr_file(
        input string infm2d_file_path,
        input int ch_idx,
        input int fm_size
    );
        string file_name;
        string infm2d_full_path;
        string num_str;
        num_str.itoa(ch_idx);
        file_name = {"act_dump_ch", num_str, ".dat"};
        infm2d_full_path = {infm2d_file_path, "/", file_name};
        ConvOneRowCtrl.load_infm2d_from_file(infm2d_full_path, fm_size, fm_size);
    endtask

    function int min(input int a, input int b);
        return a > b ? b : a;
    endfunction

    task init_double_accfifo_output();
        ConvOneRowCtrl.array_init_accfifo_output();
        pe_ctrl_which_accfifo_for_compute = ~pe_ctrl_which_accfifo_for_compute;
        ConvOneRowCtrl.array_init_accfifo_output();
        pe_ctrl_which_accfifo_for_compute = ~pe_ctrl_which_accfifo_for_compute;
    endtask
    /****** The interface for outside controller********/
    task dw_conv_one_layer(
        //just a file_path, not a file name, the file name should be
        // act_dump_ch<ch_idx>.dat
        input string infm2d_file_path,
        // the weight_file_full_path should contain the file name 
        input string weight_file_full_path,
        input int stride,
        input int nb_ch,
        input int fm_size,
        input int kernel_size
    );
        int base_row, act_row_idx_for_this_pe;
        int end_row_idx;
        int num_convolved_rows;
        logic is_first_conv_stage;
        int out_ch_idx_step;
        clear_WRegs();
        pe_ctrl_which_accfifo_for_compute = 0;
        pe_ctrl_which_afifo_for_compute = 0;
        if(stride!=1) begin
            $display("Stride!=1 is not supported now!");
            return;
        end
        // load weights from file
        load_weights_this_layer_from_file(weight_file_full_path,kernel_size);
        init_double_accfifo_output();
        // figure out workload of each column
        ConvOneRowCtrl.dw_conv_pe_workload_gen(
            fm_size,
            stride,
            kernel_size_to_row_ctrl
        );
        is_first_conv_stage = 1;
        if((fm_size - kernel_size + 1) < (num_pe_row/2)) begin
            out_ch_idx_step = 4;
        end
        else begin
            out_ch_idx_step = 1;
        end
        for(int out_ch_idx = 0; out_ch_idx < nb_ch; out_ch_idx+=out_ch_idx_step) begin
            if(is_dw_conv_zero_weights_channel(out_ch_idx)) begin
                continue;
            end
            conv_one_row_ctrl_load_infm2d_fr_file(infm2d_file_path, out_ch_idx, fm_size);
            for(int tiled_row_start = 0; tiled_row_start < fm_size; tiled_row_start += num_pe_row*stride) begin
                $display("@%t, (out_ch_idx, tiled_row_start) = (%d,%d)", $time, out_ch_idx, tiled_row_start);
                end_row_idx =  min(tiled_row_start + (num_pe_row-1)*stride + kernel_size_to_row_ctrl, fm_size);
                fork
                    begin
                        is_dw_convolving = 1;
                        dw_conv_one_infm_tile(tiled_row_start, out_ch_idx);
                        is_dw_convolving = 0;
                    end
                    begin
                        if(!is_first_conv_stage) begin
                            is_loading_fr_accfifo = 1;
                            ConvOneRowCtrl.array_give_out_results();
                            is_loading_fr_accfifo = 0;
                        end
                        else begin
                            is_first_conv_stage = 0;
                        end
                    end
                join
                pe_ctrl_which_accfifo_for_compute = ~pe_ctrl_which_accfifo_for_compute;
            end
        end
        // load out the last tile results
        is_loading_fr_accfifo = 1;
        ConvOneRowCtrl.array_give_out_results();
        is_loading_fr_accfifo = 0;
    endtask

    // for normal conv, one tile is a 3-D tensor, which some channels of infm groupped together
    //loop variables..
    int cout_start_idx;
    int tiled_col_start;
    int tiled_row_start;
    int cin_start_idx;
    task normal_conv_one_layer(
        // the infm_file_path is just a path to the file, without the filename
        // the file name should be "act_dump_ch<inch_idx>_row<row_idx>_tile_idx<tile_idx>.dat"
        input string infm_file_path,
        input string weight_file_full_path,
        input int num_inch,
        input int num_outch,
        input int stride,
        input int fm_size,
        input int kernel_size
    );
        logic is_first_conv_stage;
        int end_cout_idx;
        int end_cin_idx;
        int end_row_idx;
        int end_col_idx;
        int num_cout_group;
        int first_cout;
        int last_cout;
        int end_of_cin_idx_in_group;
        int num_convolved_rows;
        int cout_this_time_range;
        int cout_start_idx_onetime_step;
        clear_WRegs();
        is_first_conv_stage = 1;
        if(stride!= 1) begin
            $display("Stride!=1 is not supported now!");
            return;
        end
        num_cout_group = (num_outch + max_outch_per_time - 1) / max_outch_per_time;
        load_weights_this_layer_from_file(weight_file_full_path, kernel_size);
        pe_ctrl_which_accfifo_for_compute = 0;
        pe_ctrl_which_afifo_for_compute = 0;
        init_double_accfifo_output();
        is_first_conv_stage = 1;
        for(cout_start_idx = 0; cout_start_idx < num_outch; cout_start_idx+=max_outch_per_time) begin
            for(tiled_col_start = 0; tiled_col_start<fm_size; tiled_col_start += tiled_col_size * stride)begin
                for(tiled_row_start = 0; tiled_row_start<fm_size; tiled_row_start+=num_pe_row*stride) begin
                    for(cin_start_idx = 0; cin_start_idx < num_inch; cin_start_idx+=inch_group_size) begin
                        $display("@%t, (cout_start_idx, tiled_col_start, tiled_row_start, cin_start_idx) = (%d, %d,%d,%d)",
                                $time, cout_start_idx, tiled_col_start, tiled_row_start, cin_start_idx
                            );
                        end_cout_idx = min(cout_start_idx+max_outch_per_time, num_outch);
                        end_cin_idx = min(cin_start_idx+inch_group_size, num_inch);
                        // in python model, should pick up a weight buffer:
                        // total_weights[cout_start_idx: end_cout_idx, cin_start_idx:end_cin_idx]
                        // leave this part code later
                        end_row_idx = min(tiled_row_start + (num_pe_row-1)*stride + kernel_size_to_row_ctrl, fm_size);
                        end_col_idx = min(tiled_col_start + (ACCFIFO_size-1)*stride + kernel_size_to_row_ctrl, fm_size);
                        num_convolved_rows = end_row_idx - tiled_row_start;
                        // in python model, then should pick up a act_buffer:
                        // infm[0:1, cin_start_idx:end_cin_idx, tiled_row_start:end_row_idx, tiled_col_start:end_col_idx]
                        if(((cout_start_idx/max_outch_per_time) == (num_cout_group-1)) && (num_outch % max_outch_per_time != 0)) begin
                            //the last cout group.
                            cout_this_time_range = num_outch % max_outch_per_time;
                        end
                        else begin
                            cout_this_time_range = max_outch_per_time;
                        end
                        if((fm_size - kernel_size_to_row_ctrl + 1) > num_pe_row/2) begin 
                            cout_start_idx_onetime_step = num_pe_col;
                        end
                        else begin
                            cout_start_idx_onetime_step = 2 * num_pe_col;
                        end
                        for(int cout_start_idx_onetime = 0; cout_start_idx_onetime < cout_this_time_range; cout_start_idx_onetime+=cout_start_idx_onetime_step) begin
                            first_cout = cout_start_idx_onetime;
                            last_cout = min(cout_start_idx_onetime+num_pe_col, num_outch);
                            end_of_cin_idx_in_group = ((cin_start_idx + inch_group_size) < num_inch) ? inch_group_size : (num_inch-cin_start_idx);
                            fork
                                normal_conv_one_infm_tile(
                                    end_of_cin_idx_in_group,
                                    first_cout,
                                    last_cout,
                                    num_convolved_rows,
                                    cin_start_idx,
                                    end_cin_idx,
                                    tiled_row_start,
                                    end_row_idx,
                                    tiled_col_start,
                                    end_col_idx,
                                    cout_start_idx,
                                    end_cout_idx,
                                    num_inch,
                                    num_outch,
                                    fm_size,
                                    infm_file_path
                                );
                                begin
                                    if(!is_first_conv_stage) begin
                                        is_loading_fr_accfifo = 1;
                                        ConvOneRowCtrl.array_give_out_results();
                                        is_loading_fr_accfifo = 0;
                                    end
                                    else begin
                                        is_first_conv_stage = 0;
                                    end
                                end
                            join
                            pe_ctrl_which_accfifo_for_compute = ~pe_ctrl_which_accfifo_for_compute;
                        end
                    end
                end
            end
        end
        is_loading_fr_accfifo = 1;
        ConvOneRowCtrl.array_give_out_results();
        is_loading_fr_accfifo = 0;
    endtask

    /**** Init some signals*******/
    initial begin
        pe_ctrl_which_accfifo_for_compute = 0;
        kernel_size_to_row_ctrl = 3;
        quantized_bits_to_row_ctrl = 8;
        first_acc_flag = 0;
        n_ap = 0;
        WRegs = 0;
        WETCs = 0;
        WBPRs = 0;
        pe_ctrl_which_afifo_for_compute = 0;
        pe_ctrl_compute_AFIFO_read_delay_enable = 0;
        is_normal_convolving = 0;
        is_dw_convolving = 0;
        is_loading_fr_accfifo = 0;
    end
endmodule