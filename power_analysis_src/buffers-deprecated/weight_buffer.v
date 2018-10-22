module weight_buffer #(parameter
	nb_pe_col = 32,
	nb_taps = 5,
	weight_width = 16,
	ETC_width = 4,
	weight_bpr_width = ((weight_width+1)/2)*3,
	buffer_depth = 72,
	buffer_width = 16,
	buffer_addr_width = clogb2(buffer_depth)
)(
	output [nb_pe_col*nb_taps * weight_width - 1: 0] WRegs,
	output [nb_pe_col*nb_taps * weight_bpr_width - 1: 0] WBPRs,
	output [nb_pe_col*nb_taps * ETC_width - 1: 0] WETCs,
    output [nb_pe_col-1: 0]
	input [nb_taps-1: 0] weight_load_en,
	input clk, rst_n,
	input [buffer_addr_width-1: 0] wAddr, rAddr,
	input [nb_pe_col-1:0][buffer_width-1: 0] buffer_data_in,
	input [nb_pe_col-1: 0] buffer_wEn, 
    input [nb_pe_col-1: 0] buffer_rEn,
	input [4-1: 0] n_ap
);

genvar i;
generate
for(i = 0; i < nb_pe_col ;i = i + 1) begin
weightBuffer_bank #(
    .nb_taps               ( nb_taps                             ),
    .weight_width                   ( weight_width                            ),
    .ETC_width                      ( ETC_width                             ),
    .buffer_depth                   ( buffer_depth                            ),
    .buffer_width                   ( buffer_width                            ))
U_WEIGHTBUFFER_BANK_0(
    .WRegs                          ( WRegs[(i+1)*(nb_taps*weight_width)-1 -: (nb_taps*weight_width)]                         ),
    .WBPRs                          ( WBPRs[(i+1)*(nb_taps*weight_bpr_width)-1 -: (nb_taps*weight_bpr_width)]                           ),
    .WETCs                          ( WETCs[(i+1)*(nb_taps*ETC_width)-1 -: (nb_taps*ETC_width)]                          ),
    .weight_load_en                 ( weight_load_en                ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .wAddr                          ( wAddr                         ),
    .rAddr                          ( rAddr                         ),
    .buffer_data_in                 ( buffer_data_in[buffer_width*(i+1)-1 -:buffer_width]                ),
    .buffer_wEn                     ( buffer_wEn                    ),
    .buffer_rEn                     ( buffer_rEn                    ),
    .n_ap                           ( n_ap                          )
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
