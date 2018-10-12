`timescale 1ns/1ns
module ArrayConvOneRowCtrl #(parameter
    num_pe_row = 2,
    num_pe_col = 2,
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
            output logic [num_pe_row-1: 0][compressed_act_width-1: 0] pe_data_compressed_act_in,
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
            output logic [total_num_pe-1: 0] pe_ctrl_AFIFO_write,
            output logic [total_num_pe-1: 0] pe_ctrl_AFIFO_read, 
            output [total_num_pe-1: 0] pe_ctrl_ACCFIFO_write,
            output [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read, //read when computing 
            output logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read_to_outbuffer,//read when let data goto out buffer
            output logic [total_num_pe-1: 0] pe_ctrl_out_mux_sel_PE,//
            output logic [total_num_pe-1: 0] pe_ctrl_out_to_right_pe_en,	
            output [total_num_pe-1: 0] pe_ctrl_add_zero,
            output logic [total_num_pe-1: 0] pe_ctrl_feed_zero_to_accfifo,
            output logic [total_num_pe-1: 0] pe_ctrl_accfifo_head_to_tail,
        /**** End of Ports to control the PE array***/

        /**** Ports from PE array for some info ****/
            input [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_PD0,
            input [total_num_pe-1: 0] pe_ctrl_AFIFO_full,
            input [total_num_pe-1: 0] pe_ctrl_AFIFO_empty,
            input [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_afifo_out,
            input [total_num_pe-1: 0] pe_ctrl_ACCFIFO_empty,
        /**** End of Ports from PE array for some info****/

        /**** Ports of some weights info*****************/
            input [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs,
            input [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs,
            input [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs,
        /**** End of ports for weights info**************/

        /**** Transactions with global scheduler *******/
            input clk,
            input array_conv_one_row_start,
            output logic array_conv_one_row_done,
            input int kernel_size, 
            input int quantized_bits, 
            input first_acc_flag,
            input [4-1:0] n_ap
        /**** End of Transactions with global scheduler*****/
    );
    genvar gen_i, gen_j, gen_idx_1d;

    /****** Utils signals for debugging********************/
    logic waiting_for_each_row_finish;
    /******* End of utils signals for debugging*************/

    /******** Variables saving act and ctrl info************/
    logic [compressed_act_width-1: 0] act_this_row[num_pe_row][$];
    logic PAMAC_MDecomp;
    logic PAMAC_AWDecomp;
    // when 2d infm is not compressed, use this to save
    logic [activation_width-1: 0] infm2d_buffer[]; //dynamic array
    int infm2d_height;
    int infm2d_width;
    /******** End of Variables saving data and ctrl info*****/

    /******** Tasks for loading act/infm2d_buffer and so on***************/
    // load act for normal conv
        task load_compressed_act_rows_from_file(
            input int pe_row_idx, 
            input string file_full_path
            );
            int n;
            logic [compressed_act_width-1: 0] r;
            int fp;
            fp = $fopen(file_full_path, "r");
            // when is_compressed is assert, each file is a file of a row
            act_this_row[pe_row_idx].delete();
            while(!$feof(fp)) begin
                n = $fscanf(fp, "%x\n", r);
                act_this_row[pe_row_idx].push_back(r);
            end
            $fclose(fp);
        endtask
    // for potential implementation of depthwise conv
        task load_infm2d_from_file(
            input string file_full_path, 
            input int infm_height,
            input int infm_width
            );
            int n;
            int pix;
            logic [activation_width-1: 0] r;
            int fp;
            pix = 0;
            if(!(infm2d_buffer.size() == infm_height * infm_width)) begin
                infm2d_buffer.delete();
                infm2d_buffer = new [infm_height*infm_width];
            end
            fp = $fopen(file_full_path, "r");
            while(!$feof(fp)) begin
                n = $fscanf(fp, "%x\n", r);
                infm2d_buffer[pix] = r;
                pix++;
            end

            $fclose(fp);
        endtask

        task automatic feed_infm2d_to_single_pe(
            input int infm2d_row,
            input int infm2d_start_col,
            input int infm2d_end_col,
            input int pe_array_row_idx,
            input int pe_array_col_idx
        );
            //feed several cols of a row in infm2d to a specific PE.
            for(int c = infm2d_start_col; c<=infm2d_end_col;c++) begin
                pe_ctrl_AFIFO_write[pe_array_row_idx*num_pe_col+pe_array_col_idx] = 1;
                pe_data_compressed_act_in[pe_array_row_idx] = {1'b0, infm2d_buffer[infm2d_row*infm2d_width+c]};
                @(posedge clk);
            end
            pe_ctrl_AFIFO_write[pe_array_row_idx*num_pe_col+pe_array_col_idx] = 0;
        endtask

        task load_infm2d_to_array_col(
            input int infm2d_start_row, //the end col should be start_col+num_pe_row
            input int infm2d_start_col, 
            input int infm2d_end_col,
            input int pe_array_col_idx
        );
            //not check whether the afifo is deep enough. assume they are deep enough.
            begin:isolation
                for(int r_offset = 0; r_offset < num_pe_row; r_offset++) begin
                    fork
                        automatic int r_offset_temp = r_offset;
                        begin
                            feed_infm2d_to_single_pe(
                                infm2d_start_row + r_offset,
                                infm2d_start_col,
                                infm2d_end_col,
                                r_offset_temp, 
                                pe_array_col_idx
                                );
                        end
                    join_none
                end
                wait fork;
            end:isolation
        endtask


    /******** End of tasks for loading act and so on********/


    /******** Wires between array scheduler and SinglePEScheduler****/
    //from pe_scheduler to array_scheduler
        logic single_pe_done[num_pe_row-1: 0][num_pe_col-1: 0]; 
    // from array_scheduler to pe_scheduler, let it exit current scheduling
        logic act_feed_done[num_pe_row-1: 0]; 
        logic single_pe_scheduler_start[num_pe_row-1: 0][num_pe_col-1: 0]; 
        logic clr_pe_scheduler_done;
    /******** End of Wires between array scheduler and SinglePEScheduler****/

    /********** Instances of many SinglePEScheduler *****************/

    generate
        for(gen_i = 0; gen_i < num_pe_row; gen_i++) begin
            for(gen_j = 0; gen_j < num_pe_row; gen_j++) begin
                //gen_idx_1d = gen_j + gen_i * num_pe_col;
                SinglePEScheduler #(
                    .nb_taps                        ( nb_taps                             ),
                    .activation_width               ( activation_width                            ),
                    .compressed_act_width           ( compressed_act_width            ),
                    .weight_width                   ( weight_width                            ),
                    .tap_width                      ( tap_width                            ),
                    .ETC_width                      ( ETC_width                             ),
                    .width_current_tap              ( width_current_tap))
                U_SINGLE_PE_SCHEDULER(
                    .clk(clk), // <-
                    .PAMAC_BPEB_sel(pe_ctrl_PAMAC_BPEB_sel[gen_j+gen_i*num_pe_col]),
                    .PAMAC_DFF_en(pe_ctrl_PAMAC_DFF_en[gen_j+gen_i*num_pe_col]),
                    .PAMAC_first_cycle(pe_ctrl_PAMAC_first_cycle[gen_j+gen_i*num_pe_col]),
                    .PAMAC_MDecomp(PAMAC_MDecomp), // <-
                    .PAMAC_AWDecomp(PAMAC_AWDecomp), // <-
                    .current_tap(pe_ctrl_current_tap[gen_j+gen_i*num_pe_col]),
                    .DRegs_en(pe_ctrl_DRegs_en[gen_j+gen_i*num_pe_col]),
                    .DRegs_clr(pe_ctrl_DRegs_clr[gen_j+gen_i*num_pe_col]),
                    .DRegs_in_sel(pe_ctrl_DRegs_in_sel[gen_j+gen_i*num_pe_col]),
                    .index_update_en(pe_ctrl_index_update_en[gen_j+gen_i*num_pe_col]),
                    .out_mux_sel(pe_ctrl_out_mux_sel[gen_j+gen_i*num_pe_col]),
                    .out_reg_en(pe_ctrl_out_reg_en[gen_j+gen_i*num_pe_col]),
                    .AFIFO_read(pe_ctrl_AFIFO_read[gen_j+gen_i*num_pe_col]),
                    .ACCFIFO_write(pe_ctrl_ACCFIFO_write[gen_j+gen_i*num_pe_col]),
                    .ACCFIFO_read(pe_ctrl_ACCFIFO_read[gen_j+gen_i*num_pe_col]),
                    //.out_to_right_pe_en(pe_ctrl_out_to_right_pe_en[gen_j+gen_i*num_pe_col]),
                    .add_zero(pe_ctrl_add_zero[gen_j+gen_i*num_pe_col]),
                    .feed_zero_to_accfifo(pe_ctrl_feed_zero_to_accfifo[gen_j+gen_i*num_pe_col]),
                    .accfifo_head_to_tail(pe_ctrl_accfifo_head_to_tail[gen_j+gen_i*num_pe_col]),
                    .PD0(pe_ctrl_PD0[gen_j+gen_i*num_pe_col]), // <-
                    .AFIFO_empty(pe_ctrl_AFIFO_empty[gen_j+gen_i*num_pe_col]), // <-
                    .afifo_out(pe_data_afifo_out), // <-
                    // interact with array scheduler
                    .this_pe_done(single_pe_done[gen_i][gen_j]), 
                    .act_feed_done(act_feed_done[gen_i]), // <-
                    .start(single_pe_scheduler_start[gen_i][gen_j]), // <- 
                    .WRegs_packed(WRegs[gen_j]),
                    .WETCs_packed(WETCs[gen_j]),
                    .WBPRs_packed(WBPRs[gen_j]),
                    .* // n_ap, quantized_bits, kernel_size, clr_pe_scheduler_done
                );
            end
        end

    endgenerate

    /********** End of Instances of many SinglePEScheduler *****************/

    /********** Signals for array control to find whether to feed data or not****/
    logic afifo_full_exist[num_pe_row];
    generate
        for(gen_i = 0; gen_i < num_pe_row; gen_i++) begin
            assign afifo_full_exist[gen_i] = | pe_ctrl_AFIFO_full[gen_i * num_pe_col: (gen_i+1)*num_pe_col-1];
        end
    endgenerate
    /********** End of signals for array control ********************************/

    /******** Instance of a general array scheduler (It is implemented by a task) ********/
    
    function logic all_act_rows_empty();
        for(int i = 0; i < num_pe_row; i++) begin
            if(act_this_row[i].size() > 0) begin
                return 0;
            end
        end
        return 1;
    endfunction
    function logic all_pe_done();
        for(int i = 0; i<num_pe_row; i++) begin
            for(int j = 0; j < num_pe_col; j++) begin
                if(single_pe_done[i][j] != 1)
                    return 0;
            end
        end
        return 1;
    endfunction
    
    task automatic single_pe_give_out_results(
        input int pe_row_idx, 
        input int pe_col_idx
    );
        int idx_1d;
        idx_1d = pe_row_idx * num_pe_col + pe_col_idx;
        pe_ctrl_out_mux_sel_PE[idx_1d] = 0;//select to get data from accfifo
        pe_ctrl_out_to_right_pe_en[idx_1d] = 0;
        while(!pe_ctrl_ACCFIFO_empty[idx_1d]) begin
            pe_ctrl_ACCFIFO_read_to_outbuffer[idx_1d] = 1;
            @(posedge clk);
            pe_ctrl_out_to_right_pe_en[idx_1d] = 1;
        end
        pe_ctrl_ACCFIFO_read_to_outbuffer[idx_1d] = 0;
        @(posedge clk);
        pe_ctrl_out_to_right_pe_en[idx_1d] = 0;
    endtask

    task automatic array_normal_conv_one_row_task();
        // interact with all pes in the array
        // when come to this task, the act_this_row should have already been loaded from file
        $display("@%d, come to array_normal_conv_one_row", $time);
        clear_act_feed_done();
        array_conv_one_row_done = 0;
        for(int c = 0; c < num_pe_col; c++) begin
            // this column don't need to compute
            for(int r = 0; r < num_pe_row; r++) begin
                single_pe_scheduler_start[r][c] = WETCs[c] == 0 ? 0 : 1;
            end
        end
        @(posedge clk);
        // parallel tasks issue
        begin: isolation_process
            for(int r = 0; r < num_pe_row; r++) begin
                fork
                    //need this automatic var rr because otherwise 
                    //the feed_act_to_pe_row will get param = num_pe_row 
                    //rather than the expected value
                    automatic int rr = r;
                    begin
                        feed_act_to_pe_row(rr);
                    end
                join_none
            end
            // then wait for the tasks finishes
            wait fork;
        end:isolation_process
        while(!all_pe_done()) begin
            waiting_for_each_row_finish = 1;
            @(posedge clk);
            #1;
        end
        // clear all signals
        clear_act_feed_done();
        waiting_for_each_row_finish = 0;
        clear_all_pe_start();
        clr_pe_scheduler_done = 1;
        @(posedge clk);
        clr_pe_scheduler_done = 0;
    endtask

    task automatic feed_act_to_pe_row(input int row_idx);
        for(int act_idx = 0; act_idx < act_this_row[row_idx].size(); act_idx++) begin
            #1;
            while(afifo_full_exist[row_idx]) begin
                pe_ctrl_AFIFO_write[row_idx*num_pe_col+:num_pe_col] = 0;
                @(posedge clk);
                #1;
            end
            // can push act to afifo now
            for(int pe_col_idx = 0; pe_col_idx < num_pe_col; pe_col_idx++) begin
                pe_ctrl_AFIFO_write[row_idx*num_pe_col+pe_col_idx] = single_pe_scheduler_start[row_idx][pe_col_idx];
            end
            pe_data_compressed_act_in[row_idx] = act_this_row[row_idx][act_idx];
            $display("@%d, act_idx = %d, write data=%x", $time, act_idx, act_this_row[row_idx][act_idx]);
            @(posedge clk);
            // clear
        end
        pe_ctrl_AFIFO_write[row_idx*num_pe_col +: num_pe_col] = 0;
        act_feed_done[row_idx] = 1;
    endtask
    // always block to start this module
    always@(posedge array_conv_one_row_start) begin
        $display("@%d, come to array_conv_one_row_start trigged always", $time);
        array_normal_conv_one_row_task();
        //triggered by a start signal and then return a synchronized done signal...
        array_conv_one_row_done = 1; 
        @(posedge clk);
        array_conv_one_row_done = 0;
    end
    /******** End of Instance of a general array scheduler**/



    /*********Wire connections for some outputs*************/
    
    generate
        for(gen_i = 0; gen_i < total_num_pe;gen_i++)begin
            assign pe_ctrl_n_ap[gen_i] = n_ap;
            assign pe_ctrl_PAMAC_MDecomp = PAMAC_MDecomp;
            assign pe_ctrl_PAMAC_AWDecomp = PAMAC_AWDecomp;
        end
    endgenerate
    /*********  End of Wire connections  ****************/

    /********* Utils tasks and signals*************************/
    task clear_all_pe_start();
        for(int i = 0; i<num_pe_row; i++) begin
            for(int j = 0; j < num_pe_col; j++) begin
                single_pe_scheduler_start[i][j] = 0;
            end
        end
    endtask
    task clear_act_feed_done();
        foreach(act_feed_done[i]) begin
            act_feed_done[i] = 0;
        end
    endtask
    //this task just for test
    task automatic print_act_row(input int pe_row_idx);
        string s, num_str;
        $display("The %d-th row is:", pe_row_idx);
        for(int i = 0; i < act_this_row[pe_row_idx].size();i++)begin
            num_str.hextoa(act_this_row[pe_row_idx][i]);
            s = {s, ", ", num_str};
        end
        $display(s);
    endtask
    /**************Init some states**********/
    initial begin
        pe_ctrl_ACCFIFO_read_to_outbuffer = 0;
        pe_ctrl_AFIFO_write = 0;
        waiting_for_each_row_finish = 0;
        clr_pe_scheduler_done = 0;
        array_conv_one_row_done = 0;
        pe_ctrl_out_to_right_pe_en = 0;
        pe_ctrl_out_mux_sel_PE = 0;
        infm2d_height = -1;
        infm2d_width = -1;
        for(int tt = 0; tt <num_pe_row; tt++)
            pe_data_compressed_act_in[tt] = 0;
        for(int tt = 0; tt < num_pe_row; tt++) begin
            for(int ttt = 0; ttt < num_pe_col;ttt++)begin
                single_pe_scheduler_start[tt][ttt] = 0;
            end
            act_feed_done[tt] = 0;
        end
        PAMAC_MDecomp = 0;
        PAMAC_AWDecomp = 0;
    end
endmodule