module PEArrayDataInWrapper #(parameter 
    num_pe_row = 16,
    num_pe_col = 16,
    nb_taps = 11,
    total_num_pe = num_pe_row * num_pe_col,
    activation_width = 16,
	compressed_act_width = activation_width + 1,
    weight_width = 16,
    ETC_width = 4,
    weight_bpr_width = ((weight_width+1)/2)*3
)(  
    // wrapped out to the PE Array
        output [num_pe_row-1: 0][compressed_act_width-1: 0] pe_data_compressed_act_in,
        output [num_pe_col-1: 0][compressed_act_width-1: 0] pe_data_last_row_shadow_AFIFO_data_in,
        output [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs,
        output [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs,
        output [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs,  
    // Input from my dummy ctrl
        input [num_pe_row-1: 0][compressed_act_width-1: 0] compressed_act_in_fr_dummy_ctrl,
        input [num_pe_col-1: 0][compressed_act_width-1: 0] last_row_shadow_AFIFO_data_in_fr_dummy_ctrl,
        input [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs_fr_dummy_ctrl,
        input [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs_fr_dummy_ctrl,
        input [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs_fr_dummy_ctrl,  
    // Input from all ActBuffBank
        input [num_pe_row-1: 0][compressed_act_width-1: 0] compressed_act_in_fr_actbuff,
    // Input from WeightBuffBank
        input [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs_fr_wbuff,
        input [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs_fr_wbuff,
        input [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs_fr_wbuff,
        input [num_pe_col-1: 0][compressed_act_width-1: 0] last_row_shadow_AFIFO_data_in_fr_wbuff,
    // Sel signals for Mux
        // 0 is from dummy, else from actbuff bank equal or below current PE row
        input [2-1: 0] compressed_act_in_sel, 
        // 0 is from dummy, else from wbuff
        input last_row_shadow_afifo_in_sel,
        input wreg_in_sel
);

genvar gen_r, gen_c;
generate 
    /*** Mux for PE AFIFO in*****/
    for(gen_r = 0; gen_r < num_pe_row; gen_r++) begin
        if(gen_r<num_pe_row-2) begin
            Mux4in #(
                .data_width(compressed_act_width)
            ) u_Mux4in(
                .in0 ( compressed_act_in_fr_dummy_ctrl[gen_r] ),
                .in1 ( compressed_act_in_fr_actbuff[gen_r] ),
                .in2 ( compressed_act_in_fr_actbuff[gen_r+1] ),
                .in3 ( compressed_act_in_fr_actbuff[gen_r+2] ),
                .sel ( compressed_act_in_sel ),
                .out ( pe_data_compressed_act_in[gen_r] )
            );
        end
        else if(gen_r == num_pe_row-2) begin
            Mux4in #(
                .data_width(compressed_act_width)
            ) u_Mux4in(
                .in0 ( compressed_act_in_fr_dummy_ctrl[gen_r] ),
                .in1 ( compressed_act_in_fr_actbuff[gen_r] ),
                .in2 ( compressed_act_in_fr_actbuff[gen_r+1] ),
                .in3 ( compressed_act_in_fr_actbuff[0] ),
                .sel ( compressed_act_in_sel ),
                .out ( pe_data_compressed_act_in[gen_r] )
            );           
        end
        else begin
            //gen_r == num_pe_row - 1
            Mux4in #(
                .data_width(compressed_act_width)
            ) u_Mux4in(
                .in0 ( compressed_act_in_fr_dummy_ctrl[gen_r] ),
                .in1 ( compressed_act_in_fr_actbuff[gen_r] ),
                .in2 ( compressed_act_in_fr_actbuff[0] ),
                .in3 ( compressed_act_in_fr_actbuff[1] ),
                .sel ( compressed_act_in_sel ),
                .out ( pe_data_compressed_act_in[gen_r] )
            );                       
        end        
    end
    /**** MUX for last PE Row Data In and WRegs/BPRs/ETCs******/
    for(gen_c = 0; gen_c < num_pe_col; gen_c++) begin
        assign pe_data_last_row_shadow_AFIFO_data_in[gen_c] = last_row_shadow_afifo_in_sel == 0 ? 
                last_row_shadow_AFIFO_data_in_fr_dummy_ctrl[gen_c] : last_row_shadow_AFIFO_data_in_fr_wbuff[gen_c];
        assign WRegs[gen_c] = wreg_in_sel == 0 ? WRegs_fr_dummy_ctrl[gen_c] : WRegs_fr_wbuff[gen_c];
        assign WETCs[gen_c] = wreg_in_sel == 0 ? WETCs_fr_dummy_ctrl[gen_c] : WETCs_fr_wbuff[gen_c];
        assign WBPRs[gen_c] = wreg_in_sel == 0 ? WBPRs_fr_dummy_ctrl[gen_c] : WBPRs_fr_wbuff[gen_c];
    end
endgenerate
endmodule