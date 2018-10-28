module WBuff_for_power_analysis #(parameter
	nb_pe_col = 16,
	nb_taps = 11,
	weight_width = 16,
    activation_width = weight_width,
	ETC_width = 4,
	weight_bpr_width = ((weight_width+1)/2)*3,
	buffer_depth = 72,
	buffer_width = 16,
	buffer_addr_width = clogb2(buffer_depth)
)(
	output [nb_pe_col-1: 0][nb_taps * weight_width - 1: 0] WRegs,
	output [nb_pe_col-1: 0][nb_taps * weight_bpr_width - 1: 0] WBPRs,
	output [nb_pe_col-1: 0][nb_taps * ETC_width - 1: 0] WETCs,
    output [nb_pe_col-1: 0][activation_width-1: 0] last_pe_row_data_in,
	input [nb_pe_col-1: 0][nb_taps-1: 0] weight_load_en,
	input clk, rst_n,
	input [nb_pe_col-1: 0][buffer_addr_width-1: 0] wAddr, rAddr,
	input [nb_pe_col-1: 0][buffer_width-1: 0] buffer_data_in,
	input [nb_pe_col-1: 0] buffer_wEn_AH,//active high 
    input [nb_pe_col-1: 0] buffer_rEn_AH,//active high
    input clear_all_wregs,
	input [4-1: 0] n_ap
);
logic [nb_pe_col-1: 0] buffer_wEn, buffer_rEn;
assign buffer_wEn = ~buffer_wEn_AH;
assign buffer_rEn = ~buffer_rEn_AH;
genvar i;
generate
for(i = 0; i < nb_pe_col;i = i + 1) begin
WBuffer_Bank #(
    .nb_taps(nb_taps),
    .weight_width(weight_width),
    .ETC_width(ETC_width)
) WBuffer_Bank(
	.WRegs               (WRegs[i]               ),
    .WBPRs               (WBPRs[i]               ),
    .WETCs               (WETCs[i]               ),
    .last_pe_row_data_in (last_pe_row_data_in[i] ),
    .weight_load_en      (weight_load_en[i]      ),
    .clk                 (clk                 ),
    .rst_n               (rst_n               ),
    .wAddr               (wAddr[i]               ),
    .rAddr               (rAddr[i]               ),
    .buffer_data_in      (buffer_data_in[i]      ),
    .buffer_wEn          (buffer_wEn[i]          ),
    .buffer_rEn          (buffer_rEn[i]          ),
    .clear_all_wregs     (clear_all_wregs     ),
    .n_ap                (n_ap                )
);

end
endgenerate
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
