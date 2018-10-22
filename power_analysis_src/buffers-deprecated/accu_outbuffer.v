module accu_outbuffer#(parameter
	//PE Array parameter
	nb_pe_row = 8,
	pe_out_width = 24,
	buffer_width = 16,
	buffer_depth = 8192,
	buffer_addr_width = clogb2(buffer_depth)

)(
	input [nb_pe_row * pe_out_width-1: 0] out_fr_pe_array,
	input [buffer_addr_width-1: 0] wAddr, rAddr,
	input wEn, rEn,
	input clk, rst_n,

	output [nb_pe_row * buffer_width-1: 0] buffer_out_all_rows
	
);

genvar i;
generate
for(i = 0; i < nb_pe_row; i=i+1 ) begin

acc_out_buffer_bank #(
    .nb_pe_row             ( nb_pe_row                             ),
    .pe_out_width                   ( pe_out_width                            ),
    .buffer_width                   ( buffer_width                            ),
    .buffer_depth                   ( buffer_depth                          ))
U_ACC_OUT_BUFFER_BANK_0(
    .out_fr_pe                      ( out_fr_pe_array[(i+1)*pe_out_width-1 -: pe_out_width] ),
    .wAddr                          ( wAddr                         ),
    .rAddr                          ( rAddr                         ),
    .wEn                            ( wEn                           ),
    .rEn                            ( rEn                           ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .buffer_out                     ( buffer_out_all_rows[(i+1)*buffer_width-1 -:buffer_width]),
	.adder_src_sel					( 1'b0)
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
