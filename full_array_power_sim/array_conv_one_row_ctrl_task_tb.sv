module array_conv_one_row_ctrl_task_tb #(parameter
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
    )();
        /**** Ports to control the PE array (started with ``pe_ctrl/data")*****/
        // AFIFO data
        logic [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_compressed_act_in;
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
        logic [total_num_pe-1: 0] pe_ctrl_out_mux_sel_PE;//
        logic [total_num_pe-1: 0] pe_ctrl_out_to_right_pe_en;	
        logic [total_num_pe-1: 0] pe_ctrl_add_zero;
    /**** End of Ports to control the PE array***/

    /**** Ports from PE array for some info ****/
        logic [total_num_pe-1: 0] pe_ctrl_PD0;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_full;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_empty;
        logic [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_afifo_out;
    /**** End of Ports from PE array for some info****/

    /**** Transactions with global scheduler *******/
        logic clk;
        logic array_conv_one_row_start;
        logic array_conv_one_row_done;
        logic kernel_size; 
        logic quantized_bits; 
        logic [4-1:0] n_ap;
    /**** End of Transactions with global scheduler*****/



    ArrayConvOneRowCtrl DUT(.*);

    initial begin
        DUT.load_compressed_act_rows_from_file(0, "C:/Users/wyzh/Desktop/power_analysis_data/pruned_alex/act_conv_4/act_dump_ch0_row10.dat");
        DUT.load_compressed_act_rows_from_file(1, "C:/Users/wyzh/Desktop/power_analysis_data/pruned_alex/act_conv_4/act_dump_ch0_row11.dat");
        DUT.print_act_row(0);
        DUT.print_act_row(1);
    end
endmodule