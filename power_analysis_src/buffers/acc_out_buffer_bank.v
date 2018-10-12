module acc_out_buffer_bank#(parameter
	//PE Array parameter
	nb_pe_row = 8,
	pe_out_width = 24,
	buffer_width = 16,
	buffer_depth = 8192,
	buffer_addr_width = clogb2(buffer_depth)

)(
	input [pe_out_width-1: 0] out_fr_pe,
	input [buffer_addr_width-1: 0] wAddr, rAddr,
	input wEn, rEn,
	input clk, rst_n,
	input adder_src_sel,
	output [buffer_width-1: 0] buffer_out
	
);

wire [buffer_width-1: 0] buffer_out_Q;
wire signed [pe_out_width+1-1: 0] temp;
wire [buffer_width-1: 0] saturated_temp;
assign temp = $signed(out_fr_pe) + (adder_src_sel == 0 ? $signed(buffer_out_Q) : 0);



DFF_en #(
    .L_datain              ( buffer_width                            ))
U_DFF_EN_0(
    .Q                        ( buffer_out_Q                       ),
    .D                        ( buffer_out                       ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .en                             ( 1'b1                            )
);

saturate #(
    .L_datain              ( pe_out_width+1                            ),
    .L_dataout                      ( buffer_width                            ))
U_SATURATE_0(
    .in                       ( temp                     ),
    .out                      ( saturated_temp                  )
);

SRAM_8192x16bits ram(
    .rData                          ( buffer_out                         ),
    .wData                          ( saturated_temp                         ),
    .clk                            ( clk                           ),
    .wEn                            ( wEn                           ),
    .rEn                            ( rEn                          ),
    .wAddr                          ( wAddr                         ),
    .rAddr                          ( rAddr                         )
	);	

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
