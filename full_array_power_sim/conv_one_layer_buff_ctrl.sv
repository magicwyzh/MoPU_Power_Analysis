`timescale 1ns/1ns
module conv_one_layer_buff_ctrl#(
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
    /********ActBuff Ports**************/
	output logic [num_pe_row-1: 0][compressed_act_width-1: 0] ActBuff_data_in,
	output logic [num_pe_row-1: 0] ActBuff_wEn_AH, 
    output logic [num_pe_row-1: 0] ActBuff_rEn_AH, 
	output logic [num_pe_row-1: 0][ActBuff_addr_width-1: 0] ActBuff_wAddr,
    output logic [num_pe_row-1: 0][ActBuff_addr_width-1: 0] ActBuff_rAddr,
    /*******WeightBuff Ports************/
    output logic [num_pe_col-1: 0][nb_taps-1: 0] WBuff_weight_load_en,
	output logic [num_pe_col-1: 0][WBuff_addr_width-1: 0] WBuff_wAddr, 
	output logic [num_pe_col-1: 0][WBuff_addr_width-1: 0] WBuff_rAddr,
	output logic [num_pe_col-1: 0][weight_width-1: 0] WBuff_data_in,
	output logic [num_pe_col-1: 0] WBuff_wEn_AH,//active high 
    output logic [num_pe_col-1: 0] WBuff_rEn_AH,//active high
    output logic WBuff_clear_all_wregs,

    input clk
);
/**** Variable to load data from file***/
    logic [weight_width-1: 0] weights_this_layer[3*3*512*512];// set up enough space for weights
    logic [compressed_act_width-1: 0] act_this_row[num_pe_row][$];
    logic [activation_width-1: 0] infm2d_buffer[]; //dynamic array
    int infm2d_height;
    int infm2d_width;

/**** Utils function*****/
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
    function int min(input int a, input int b);
        return a > b ? b : a;
    endfunction
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
/***** Utils Tasks to load data from file****/
    task load_zero_act_row_to_act_this_row(
        input int pe_row_idx, 
        input int fm_size
        );
        logic [activation_width-1: 0] r;
        r = fm_size;
        act_this_row[pe_row_idx].delete();
        act_this_row[pe_row_idx].push_back({1'b1, r});// whole row of zero.
    endtask
    task dw_conv_load_infm2d_fr_file(
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
        load_infm2d_from_file(infm2d_full_path, fm_size, fm_size);
    endtask
    task load_weights_this_layer_from_file(
        input string file_path
    );
        $readmemh(file_path, weights_this_layer);
    endtask
    task load_compressed_act_rows_from_file(
        input int pe_row_idx, 
        input string file_full_path
        );
        int n;
        logic [compressed_act_width-1: 0] r;
        int fp;
        fp = $fopen(file_full_path, "r");
        // when is_compressed is assert, each file is a file of a row
        if(fp==0) begin
            $display("@%t, load_compressed_act_rows:Error Open file:%s", $time, file_full_path);
            $stop;
        end
        act_this_row[pe_row_idx].delete();
        while(!$feof(fp)) begin
            n = $fscanf(fp, "%x\n", r);
            act_this_row[pe_row_idx].push_back(r);
        end
        $fclose(fp);
    endtask
    task load_infm2d_from_file(
        input string file_full_path, 
        input int infm_height,
        input int infm_width
        );
        int n;
        int pix;
        logic [activation_width-1: 0] r;
        int fp;
        infm2d_width = infm_width;
        infm2d_height = infm_height;
        pix = 0;
        if(!(infm2d_buffer.size() == infm_height * infm_width)) begin
            infm2d_buffer.delete();
            infm2d_buffer = new [infm_height*infm_width];
        end
        fp = $fopen(file_full_path, "r");
        if(fp==0) begin
            $display("@%t, load_infm2d_from_file:Error Open file:%s", $time, file_full_path);
            $stop;
        end
        while(!$feof(fp)) begin
            n = $fscanf(fp, "%x\n", r);
            infm2d_buffer[pix] = r;
            pix++;
        end
        $fclose(fp);
    endtask
    /****** DWConv Workload Gen******/
    int pe_workload_start_col[num_pe_col-1:0];
    int pe_workload_end_col[num_pe_col-1:0];
    int pe_workload_out_size[num_pe_col-1: 0];
    task dw_conv_pe_workload_gen(
        input int inp_col_size,
        input int stride,
        input int kernel_size
    );
        int outp_col_size;
    	int per_pe_output_col;
	    int res;
        int out_size[num_pe_col];

        outp_col_size =  ((inp_col_size - kernel_size) /stride ) + 1;
	    per_pe_output_col = outp_col_size / num_pe_col;
        if(per_pe_output_col > 0) begin
            res = outp_col_size % per_pe_output_col;
        end
        else begin
            res = outp_col_size;
        end
        for(int i = 0; i<num_pe_col; i++) begin
            out_size[i] = per_pe_output_col;
            if(i < res) begin
                out_size[i] += 1;
            end
            pe_workload_out_size[i] = out_size[i];
        end
        pe_workload_start_col[0] = 0;
        pe_workload_end_col[0] = kernel_size+(out_size[0]-1)*stride -1;
        for(int i = 1; i < num_pe_col; i++) begin
            pe_workload_start_col[i] = pe_workload_end_col[i-1] - (stride==2?0:1);
            pe_workload_end_col[i] = pe_workload_start_col[i] + kernel_size + (out_size[i]-1)*stride-1;
        end
    endtask
    /****** WBuff R/W tasks*********/
    task clear_WRegs(); 
        WBuff_clear_all_wregs = 1;
        @(posedge clk);
        WBuff_clear_all_wregs = 0;
    endtask

    task automatic WBuff_Bank_Load_Out_WRegs(
        input int bank_idx,
        input int kernel_size,
        input int start_addr
    );
        WBuff_weight_load_en[bank_idx] = 0;
        for(int k = 0; k < kernel_size; k++) begin    
            WBuff_rAddr[bank_idx] = start_addr + k;
            WBuff_rEn_AH[bank_idx] = 1;
            @(posedge clk);
            WBuff_rEn_AH[bank_idx] = 0;
            WBuff_weight_load_en[bank_idx] = 0;
            WBuff_weight_load_en[bank_idx][k] = 1'b1;
        end
        @(posedge clk);
        WBuff_weight_load_en[bank_idx] = 0;
    endtask

    task automatic WBuff_Bank_Save_In_DwConv_Weights(
        input int bank_idx,
        input int kernel_size,
        input int ch_idx,
        input int start_addr
    ); 
        for(int k_row = 0; k_row < kernel_size; k_row++) begin
            for(int k_col = 0; k_col < kernel_size; k_col++) begin
                WBuff_wAddr[bank_idx] = start_addr + k_row*kernel_size + k_col;
                WBuff_wEn_AH[bank_idx] = 1;
                WBuff_data_in[bank_idx] = find_weight(
                                                        ch_idx, //co 
                                                        0, //ci
                                                        k_row, //kernel_row
                                                        k_col, //kernel_col
                                                        1, //nb_ci
                                                        kernel_size //kernel_size
                                                    );
                @(posedge clk);
            end
        end
        WBuff_wEn_AH[bank_idx] = 0;
        WBuff_wAddr[bank_idx] = 0;
    endtask
    task automatic WBuff_Bank_Save_In_NormalConv_Weights(
        input int bank_idx, 
        input int kernel_size, 
        input int in_ch_idx,
        input int out_ch_idx,
        input int num_cin,
        input int start_addr
    );
        for(int k_row = 0; k_row < kernel_size; k_row++) begin
            for(int k_col = 0; k_col < kernel_size; k_col++) begin
                WBuff_wAddr[bank_idx] = start_addr + k_row*kernel_size + k_col;
                WBuff_wEn_AH[bank_idx] = 1;
                WBuff_data_in[bank_idx] = find_weight(
                                                        out_ch_idx, //co 
                                                        in_ch_idx, //ci
                                                        k_row, //kernel_row
                                                        k_col, //kernel_col
                                                        num_cin, //nb_ci
                                                        kernel_size //kernel_size
                                                    );
                @(posedge clk);
            end
        end
        WBuff_wEn_AH[bank_idx] = 0;
    endtask
    task WBuff_Save_In_NormalConv_Weights(
        input int kernel_size,
        input int in_ch_idx,
        input int out_ch_start_idx,
        input int num_out_ch_effective,
        input int num_cin,
        input int start_addr
    );
        begin:isolation_wbuff_save_in_normal_conv
            for(int c = 0; c < num_pe_col; c++) begin
                fork
                    automatic int cc = c;
                    begin
                        if(cc < num_out_ch_effective) begin
                            WBuff_Bank_Save_In_NormalConv_Weights(
                                cc,//bank_idx
                                kernel_size,
                                in_ch_idx,
                                out_ch_start_idx + cc, //out_ch_idx
                                num_cin,
                                start_addr
                            );
                        end
                    end
                join_none
            end
            wait fork;
        end:isolation_wbuff_save_in_normal_conv
    endtask

    task automatic WBuff_Load_Out_WRegs(
        input int kernel_size,
        input int start_addr
    );
        begin:isolation_load_out_wreg
            for(int c = 0; c < num_pe_col; c++) begin
                fork
                    automatic int cc = c;
                    begin
                        WBuff_Bank_Load_Out_WRegs(
                            cc,
                            kernel_size,
                            start_addr
                        );
                    end
                join_none
            end
            wait fork;
        end:isolation_load_out_wreg
    endtask

    task WBuff_Save_In_DwConv_Weights(
        input int kernel_size,
        input int ch_idx,
        input int start_addr
    );
        begin:isolation_wbuff_save_in_dwconv
            for(int c = 0; c < num_pe_col; c++) begin
                fork
                    automatic int cc = c;
                    begin
                        WBuff_Bank_Save_In_DwConv_Weights(
                            cc,
                            kernel_size,
                            ch_idx,
                            start_addr
                        );
                    end
                join_none
            end
            wait fork;
        end:isolation_wbuff_save_in_dwconv
    endtask

    // never call this task together with WBuff_load_Out_WRegs
    task feed_last_pe_row_shadow_afifo(
        input int infm2d_row
    );
        // feed to address 32 and load out~
        if(infm2d_row >= infm2d_height) begin
            return;
        end
        begin:isolation_feed_last_pe_row
            for(int c = 0; c < num_pe_col; c++) begin
                fork
                    automatic int cc = c;
                    feed_last_pe_row_shadow_fifo_col_accord_workload(
                        infm2d_row,
                        cc
                    );
                join_none
            end
            wait fork;
        end:isolation_feed_last_pe_row
    endtask

    // feed to start address of 32 and load out
    task automatic feed_last_pe_row_shadow_fifo_col_accord_workload(
        input int infm2d_row,
        input int pe_col_idx
    );
        if(pe_workload_out_size[pe_col_idx] <= 0) begin
            return;
        end 
        WBuff_wAddr[pe_col_idx] = 31;
        WBuff_rAddr[pe_col_idx] = 31;
        for(int i = pe_workload_start_col[pe_col_idx]; i < pe_workload_end_col[pe_col_idx]; i++) begin
            WBuff_data_in[pe_col_idx] = infm2d_buffer[infm2d_row*infm2d_width + i];
            WBuff_wEn_AH[pe_col_idx] = 1;
            WBuff_wAddr[pe_col_idx] += 1;
            if(WBuff_wAddr[pe_col_idx] == 72) begin
                WBuff_wAddr[pe_col_idx] = 32;
            end
            if(i > pe_workload_start_col[pe_col_idx]) begin
                WBuff_rEn_AH[pe_col_idx] = 1;
                WBuff_rAddr[pe_col_idx] += 1;
                if(WBuff_rAddr[pe_col_idx] == 72) begin
                    WBuff_rAddr[pe_col_idx] = 32;
                end
            end
            @(posedge clk);
        end
        WBuff_wEn_AH = 0;
        // read the last one 
        WBuff_rAddr[pe_col_idx] += 1;
        if(WBuff_rAddr[pe_col_idx] == 72) begin
            WBuff_rAddr[pe_col_idx] = 32;
        end
        @(posedge clk)
        WBuff_rEn_AH = 0;
    endtask

    /*** ActBuff R/W procedure*****/
    task load_infm2d_to_array(
        input int infm2d_start_row
    );
        // prevent corruption
        if(infm2d_start_row >= infm2d_height) begin
            return;
        end
        // since each act will be used for only once from ActBuff, then we just save each 
        // act into the ActBuff at addr 0 and then read out at once.
        for(int i = 0;i < infm2d_width; i++) begin
            for(int j = 0; j < num_pe_row; j++) begin
                // sanity check
                if((infm2d_start_row + j)>=infm2d_height) begin
                    continue;
                end
                // write
                ActBuff_data_in[j] = infm2d_buffer[(infm2d_start_row+j)*infm2d_width+i];
                ActBuff_wEn_AH[j] = 1;
                ActBuff_wAddr[j] = i;
                // read
                if(i > 0) begin
                    ActBuff_rEn_AH[j] = 1;
                    ActBuff_rAddr[j] = i - 1;
                end
            end
            // read after the first data is out
            @(posedge clk);
        end
        // stop write
        ActBuff_wEn_AH = 0;
        // read the last data
        for(int j = 0; j < num_pe_row; j++) begin
            if((infm2d_start_row + j)>=infm2d_height) begin
                continue;
            end
            ActBuff_rEn_AH[j] = 1;
            ActBuff_rAddr[j] = infm2d_width-1;
        end
        @(posedge clk);
        ActBuff_rEn_AH = 0;
    endtask

    task ActBuff_NormalConv_RW_Procedure(
        input int infm_tiled_row_start,
        input int fm_size,
        input int kernel_row,
        input int kernel_size,
        input string infm_file_path,
        input int in_ch_idx,
        input int infm_col_tile_idx,
        input logic first_time_of_this_infm_tile,
        // each inner group occupy depth of 32(ACCFIFO_SIZE), 
        // this is to let infm data of different inch stay in different start address
        input int cin_inner_group_idx
    );
        string infm_file_full_path; 
        string file_name;
        int infm_row_idx;
        // load act_this_row from file~

        for(int pe_row_idx = 0; pe_row_idx<num_pe_row; pe_row_idx++) begin
            infm_row_idx = infm_tiled_row_start + pe_row_idx+kernel_row;
            if(infm_row_idx < (fm_size - kernel_size + 1)) begin
                file_name = generate_act_dump_file_name(
                    in_ch_idx,//cin_start_idx + cin_inner_group_idx,
                    infm_row_idx, 
                    infm_col_tile_idx
                );
                infm_file_full_path = {infm_file_path, "/", file_name};
                load_compressed_act_rows_from_file(pe_row_idx, infm_file_full_path);
            end
            else begin
                load_zero_act_row_to_act_this_row(pe_row_idx, fm_size);
            end
        end

        // ActBuff RW procedure
        begin:isolation_actbuff_normalconv_rw
            for(int pe_row_idx = 0; pe_row_idx<num_pe_row; pe_row_idx++) begin
                fork
                    automatic int rr = pe_row_idx;
                    automatic int infm_row_idx_auto = infm_tiled_row_start + pe_row_idx + kernel_row;
                    begin
                        infm_row_idx = infm_tiled_row_start + rr + kernel_row;
                        if(infm_row_idx_auto < (fm_size - kernel_size + 1)) begin
                            ActBuff_Bank_NormalConv_RW_Procedure(
                                rr, 
                                first_time_of_this_infm_tile,
                                cin_inner_group_idx
                            );
                        end
                    end
                join_none
            end
            wait fork;
        end:isolation_actbuff_normalconv_rw
    endtask

    task automatic ActBuff_Bank_NormalConv_RW_Procedure(
        input int pe_row_idx,
        input logic first_time_of_this_infm_tile,
        input int cin_inner_group_idx
    );
        ActBuff_rEn_AH[pe_row_idx] = 0;
        for(int i = 0; i < act_this_row[pe_row_idx].size(); i++) begin
            //if(first_time_of_this_infm_tile) begin=
            if(first_time_of_this_infm_tile) begin
                ActBuff_wAddr[pe_row_idx] = cin_inner_group_idx * ACCFIFO_size + i; 
                ActBuff_data_in[pe_row_idx] = act_this_row[pe_row_idx][i];
                ActBuff_wEn_AH[pe_row_idx] = 1;
            end
            if(i > 0) begin
                #1;
                ActBuff_rAddr[pe_row_idx] = cin_inner_group_idx * ACCFIFO_size + i - 1;
                ActBuff_rEn_AH[pe_row_idx] = 1;
            end
            @(posedge clk);
        end
        ActBuff_wEn_AH[pe_row_idx] = 0;
        ActBuff_rEn_AH[pe_row_idx] = 1;
        ActBuff_rAddr[pe_row_idx] = cin_inner_group_idx * ACCFIFO_size + act_this_row[pe_row_idx].size() - 1;
        @(posedge clk);
        ActBuff_rEn_AH[pe_row_idx] = 0;
    endtask
    /**** Conv Utils******/
    task dw_conv_one_infm_tile_BuffCtrlGen(
        input int infm2d_start_row,
        input int ch_idx,
        input int kernel_size
    );
        WBuff_Load_Out_WRegs(
            kernel_size,
            0//start_addr
        );
        @(posedge clk); // make sure the wregs are new
        fork
            load_infm2d_to_array(infm2d_start_row);
            feed_last_pe_row_shadow_afifo(infm2d_start_row+num_pe_row);
        join
        @(posedge clk);
        for(int krow = 1; krow < kernel_size;krow++) begin
            WBuff_Load_Out_WRegs(
                kernel_size,
                krow*kernel_size//start_addr
            );
            if(krow!=kernel_size-1) begin
                feed_last_pe_row_shadow_afifo(infm2d_start_row+num_pe_row+krow);
            end
        end
    endtask
    // the give out results procedure is not in this task!!
    // Should Remember to change the accfifo after accfifo giveout results!
    task normal_conv_one_infm_tile_BuffCtrlGen(
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
        input string infm_file_path,
        input int kernel_size,
        input logic first_time_of_this_infm_tile
    );
        string infm_file_full_path; // should figure out the file name
        string file_name;
        int infm_col_tile_idx;
        int infm_row_idx;
        infm_col_tile_idx = tiled_col_start / ACCFIFO_size;
        for(int cin_inner_group_idx = 0; cin_inner_group_idx < end_of_cin_idx_in_group; cin_inner_group_idx++) begin
            //$display("@%t, start save in normalConv Weights",$time);
            WBuff_Save_In_NormalConv_Weights(
                kernel_size,
                cin_inner_group_idx + cin_start_idx,
                cout_start_idx+first_cout,
                last_cout - first_cout,  //num_out_ch_effective,
                num_inch,
                0 //start_addr
            );
            //$display("@%t, End save in normalConv Weights",$time);
            for(int kernel_row = 0; kernel_row < kernel_size; kernel_row++) begin
                fork
                    WBuff_Load_Out_WRegs(
                        kernel_size,
                        kernel_row*kernel_size //start_addr
                    );
                    ActBuff_NormalConv_RW_Procedure(
                        tiled_row_start,
                        fm_size, 
                        kernel_row,
                        kernel_size,
                        infm_file_path,
                        cin_start_idx + cin_inner_group_idx,
                        infm_col_tile_idx,
                        first_time_of_this_infm_tile,
                        cin_inner_group_idx
                    );
                join
            end
        end
    endtask

    /****** The interface for outside controller********/
    task dw_conv_one_layer_BuffCtrlGen(
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
        int out_ch_idx_step;
        clear_WRegs();
        if(stride!=1) begin
            $display("Stride!=1 is not supported now!");
            return;
        end
        // load weights from file
        load_weights_this_layer_from_file(weight_file_full_path);
        // figure out workload of each column
        dw_conv_pe_workload_gen(
            fm_size,
            stride,
            kernel_size
        );
        if((fm_size - kernel_size + 1) < (num_pe_row/2)) begin
            // should still be 1 because the BuffCtrl do not simulate the Array Division
            //out_ch_idx_step = 4;
            out_ch_idx_step = 1; 
        end
        else begin
            out_ch_idx_step = 1;
        end
        for(int out_ch_idx = 0; out_ch_idx < nb_ch; out_ch_idx+=out_ch_idx_step) begin
            dw_conv_load_infm2d_fr_file(infm2d_file_path, out_ch_idx, fm_size);
            WBuff_Save_In_DwConv_Weights(
                    kernel_size,
                    out_ch_idx,
                    0//start_addr
                );
            // now weights are in address 0~9
            for(int tiled_row_start = 0; tiled_row_start < fm_size; tiled_row_start += num_pe_row*stride) begin
                end_row_idx =  min(tiled_row_start + (num_pe_row-1)*stride + kernel_size, fm_size);
                fork
                    begin
                        dw_conv_one_infm_tile_BuffCtrlGen(tiled_row_start, out_ch_idx, kernel_size);
                    end
                join
            end
        end
    endtask

    // for normal conv, one tile is a 3-D tensor, which some channels of infm groupped together
    //loop variables..
    int cout_start_idx;
    int tiled_col_start;
    int tiled_row_start;
    int cin_start_idx;
    task normal_conv_one_layer_BuffCtrlGen(
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
        if(stride!= 1) begin
            $display("Stride!=1 is not supported now!");
            return;
        end
        num_cout_group = (num_outch + max_outch_per_time - 1) / max_outch_per_time;
        load_weights_this_layer_from_file(weight_file_full_path);
        for(cout_start_idx = 0; cout_start_idx < num_outch; cout_start_idx+=max_outch_per_time) begin
            for(tiled_col_start = 0; tiled_col_start<fm_size; tiled_col_start += tiled_col_size * stride)begin
                for(tiled_row_start = 0; tiled_row_start<fm_size; tiled_row_start+=num_pe_row*stride) begin
                    for(cin_start_idx = 0; cin_start_idx < num_inch; cin_start_idx+=inch_group_size) begin
                        /*
                        $display("@%t, (cout_start_idx, tiled_col_start, tiled_row_start, cin_start_idx) = (%d, %d,%d,%d)",
                                $time, cout_start_idx, tiled_col_start, tiled_row_start, cin_start_idx
                            );
                        */
                        end_cout_idx = min(cout_start_idx+max_outch_per_time, num_outch);
                        end_cin_idx = min(cin_start_idx+inch_group_size, num_inch);
                        // in python model, should pick up a weight buffer:
                        // total_weights[cout_start_idx: end_cout_idx, cin_start_idx:end_cin_idx]
                        // leave this part code later
                        end_row_idx = min(tiled_row_start + (num_pe_row-1)*stride + kernel_size, fm_size);
                        end_col_idx = min(tiled_col_start + (ACCFIFO_size-1)*stride + kernel_size, fm_size);
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
                        if((fm_size - kernel_size + 1) > num_pe_row/2) begin 
                            cout_start_idx_onetime_step = num_pe_col;
                        end
                        else begin
                            //cout_start_idx_onetime_step = 2 * num_pe_col; // not model array reuse..
                            cout_start_idx_onetime_step = num_pe_col;
                        end
                        for(int cout_start_idx_onetime = 0; cout_start_idx_onetime < cout_this_time_range; cout_start_idx_onetime+=cout_start_idx_onetime_step) begin
                            first_cout = cout_start_idx_onetime;
                            last_cout = min(cout_start_idx_onetime+num_pe_col, num_outch);
                            end_of_cin_idx_in_group = ((cin_start_idx + inch_group_size) < num_inch) ? inch_group_size : (num_inch-cin_start_idx);
                            normal_conv_one_infm_tile_BuffCtrlGen(
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
                                infm_file_path,
                                kernel_size,
                                cout_start_idx_onetime == 0 ? 1 : 0//first_time_of_this_infm_tile, only write at the first time
                            );
                            
                        end
                    end
                end
            end
        end
    endtask




    /******Signal Initializations***********/
    initial begin
        ActBuff_data_in = 0;
        ActBuff_wEn_AH = 0;
        ActBuff_rEn_AH = 0;
        ActBuff_wAddr = 0;
        ActBuff_rAddr = 0;
        WBuff_weight_load_en = 0;
        WBuff_wAddr = 0;
        WBuff_rAddr = 0;
        WBuff_data_in = 0;
        WBuff_wEn_AH = 0;
        WBuff_rEn_AH = 0;
        WBuff_clear_all_wregs = 0;
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