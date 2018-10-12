module PEArray#(parameter
	//PE Array parameter
	nb_pe_row = 8,
	nb_pe_col = 32,
	//PE parameter
	AFIFO_size = 8,
	ACCFIFO_size = 32,
	//parameters for FoFIR
	nb_taps = 5,
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
	/*****weight ports********/
	input [nb_pe_col * nb_taps * weight_width - 1: 0] WRegs_all_cols,
	input [nb_pe_col * nb_taps * weight_bpr_width - 1: 0] WBPRs_all_cols,
	input [nb_pe_col * nb_taps * ETC_width - 1: 0] WETCs_all_cols,
	
	/****activation ports*****/
	input [nb_pe_row * compressed_act_width -1: 0] compressed_act_in_all_rows,
	
	/***All PEs share the same control for simplicity******/
	//configuration ports
	input [4-1: 0] n_ap,

	//control ports for PAMAC
	input [3-1: 0] PAMAC_BPEB_sel,
	input PAMAC_DFF_en,
	input PAMAC_first_cycle,
	//the following two inputs are reserved 
	input PAMAC_MDecomp,//1 is mulwise, 0 is layerwise
	input PAMAC_AWDecomp,// 0 is act decomp, 1 is w decomp

	//control signals for FoFIR
	input [width_current_tap-1: 0] current_tap,
	//DRegs signals
	input [nb_taps-1: 0] DRegs_en,
	input [nb_taps-1: 0] DRegs_clr,
	input [nb_taps-1: 0] DRegs_in_sel,//0 is from left, 1 is from pamac output
	
	//DRegs indexing signals
	input index_update_en,

	//output signals
	input out_mux_sel,//0 is from PAMAC, 1 is from DRegs
	input out_reg_en,
	//FIFOs
	input AFIFO_write,
	input AFIFO_read,
	input ACCFIFO_write,
	input ACCFIFO_read,
	input ACCFIFO_read_out,
	input ACCFIFO_sel,//double buffer 
	input out_mux_sel_PE,//
	
	input clk, rst_n,

	output [nb_pe_row * output_width - 1: 0] out_to_OBF_all_rows

);

wire [compressed_act_width-1: 0] compressed_act_in[nb_pe_row-1: 0];
wire [output_width-1: 0] out_to_OBF[nb_pe_row-1: 0];
wire [weight_width * nb_taps-1: 0] WRegs[nb_pe_col-1: 0];
wire [weight_bpr_width * nb_taps-1: 0] WBPRs[nb_pe_col-1: 0];
wire [ETC_width * nb_taps-1: 0] WETCs[nb_pe_col-1: 0];
wire [output_width-1: 0] out_of_each_pe[nb_pe_row-1: 0][nb_pe_col-1: 0];
genvar row_idx, col_idx;
generate
//assign wires
for(row_idx = 0; row_idx < nb_pe_row; row_idx = row_idx + 1) begin
	assign out_to_OBF[row_idx] = out_of_each_pe[row_idx][nb_pe_col-1];
	assign compressed_act_in[row_idx] = 
		compressed_act_in_all_rows[(row_idx+1)*compressed_act_width-1 -: compressed_act_width];
	assign out_to_OBF_all_rows[(row_idx+1)*output_width-1 -: output_width] = 
		out_to_OBF[row_idx];
end

for(col_idx = 0; col_idx < nb_pe_col; col_idx = col_idx + 1) begin
	assign WRegs[col_idx] = 
		WRegs_all_cols[(col_idx+1) * (nb_taps * weight_width) -1 -: (nb_taps*weight_width)];
	assign WBPRs[col_idx] = 
		WBPRs_all_cols[(col_idx+1) * (nb_taps * weight_bpr_width) -1 -: (nb_taps*weight_bpr_width)];
	assign WETCs[col_idx] = 
		WETCs_all_cols[(col_idx+1) * (nb_taps * ETC_width) -1 -: (nb_taps*ETC_width)];
end



wire [output_width-1: 0] temppp[nb_pe_row-1: 0][nb_pe_col-1: 0];
for(row_idx = 0; row_idx < nb_pe_row; row_idx = row_idx + 1) begin
	for(col_idx = 0; col_idx < nb_pe_col; col_idx = col_idx + 1) begin
		if(col_idx == 0) begin
			assign temppp[row_idx][col_idx] = {output_width{1'b0}};
		end
		else begin
			assign temppp[row_idx][col_idx] = out_of_each_pe[row_idx][col_idx-1];
		
		end
PE #(
    .AFIFO_size			            ( AFIFO_size                             ),
    .ACCFIFO_size                   ( ACCFIFO_size                            ),
    .nb_taps                        ( nb_taps                             ),
    .activation_width               ( activation_width                            ),
    .weight_width                   ( weight_width                            ),
    .tap_width                      ( tap_width                            ),
    .ETC_width                      ( ETC_width                             ))
U_PE_0(
    .compressed_act_in              ( compressed_act_in[row_idx]             ),
    .out_fr_left_PE                 ( temppp[row_idx][col_idx]                ),
    .n_ap                           ( n_ap                          ),
    .PAMAC_BPEB_sel                 ( PAMAC_BPEB_sel                ),
    .PAMAC_DFF_en                   ( PAMAC_DFF_en                  ),
    .PAMAC_first_cycle              ( PAMAC_first_cycle             ),
    .PAMAC_MDecomp                  ( PAMAC_MDecomp                 ),
    .PAMAC_AWDecomp                 ( PAMAC_AWDecomp                ),
    .current_tap                    ( current_tap                   ),
    .DRegs_en                       ( DRegs_en                      ),
    .DRegs_clr                      ( DRegs_clr                     ),
    .DRegs_in_sel                   ( DRegs_in_sel                  ),
    .index_update_en                ( index_update_en               ),
    .out_mux_sel                    ( out_mux_sel                   ),
    .out_reg_en                     ( out_reg_en                    ),
    .WRegs                          ( WRegs[col_idx]                         ),
    .WBPRs                          ( WBPRs[col_idx]                         ),
    .WETCs                          ( WETCs[col_idx]                         ),
    .AFIFO_write                    ( AFIFO_write                   ),
    .AFIFO_read                     ( AFIFO_read                    ),
    .ACCFIFO_write                  ( ACCFIFO_write                 ),
    .ACCFIFO_read                   ( ACCFIFO_read                  ),
    .ACCFIFO_read_out               ( ACCFIFO_read_out              ),
    .ACCFIFO_sel                    ( ACCFIFO_sel                   ),
    .out_mux_sel_PE                 ( out_mux_sel_PE                ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .out_to_right_PE                ( out_of_each_pe[row_idx][col_idx]               )
);

	end
end
endgenerate



endmodule
