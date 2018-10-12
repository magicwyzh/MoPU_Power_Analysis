module actQueueDataPath #(parameter
		nb_data = 16,
    	L_data = 17,//12(data)+15(idx)
		SRAM_IMPL = 0,
    	L_addr = clogb2(nb_data),
		word_width = L_data,
		stk_height = nb_data,
		stk_ptr_width = L_addr
)(
	output [word_width-1: 0] DataOut,
	input [word_width-1: 0] DataIn,
	input [stk_ptr_width-1: 0] write_ptr, read_ptr,
	input write_to_stk, read_fr_stk,
	input clk
);

generate
if(SRAM_IMPL == 0) begin
rf2pModel #(
    .nb_data						(nb_data                        ),
    .L_data                         (L_data                         ),
	.L_addr							(L_addr							))
regfile(
    .rData                          ( DataOut                         ),
    .wData                          ( DataIn                         ),
    .clk                            ( clk                           ),
	//the ram model is negtive enabled
    .wEn                            ( ~write_to_stk                           ),
    .rEn                            ( ~read_fr_stk                           ),
    .wAddr                          ( write_ptr                         ),
    .rAddr                          ( read_ptr                         )
);
end
else begin
	if(nb_data == 32 && L_data == 24)
	TS6N28HPCPHVTA32X24M4F ram(
		.AA(write_ptr),
		.D(DataIn),
		.WEB(~write_to_stk),
		.CLKW(clk),
		.AB(read_ptr),
		.REB(~read_fr_stk),
		.CLKR(clk),
		.Q(DataOut)
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
//***********************************************************************

endmodule
