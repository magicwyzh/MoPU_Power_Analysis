module act_buffer #(parameter
	//PE Array parameter
	nb_pe_row = 8,
	nb_pe_col = 32,
	//parameters for FoFIR
	activation_width = 16,
	compressed_act_width = activation_width + 1,
	//mem_bank
	mem_bank_width = compressed_act_width,
	mem_depth = 768,
	addr_width = clogb2(mem_depth)
)(
	input [nb_pe_row * compressed_act_width-1: 0] mem_data_in_all_rows,
	input wEn, rEn, 
	input [addr_width-1: 0] wAddr, rAddr,
	input clk, rst_n,

	output reg [nb_pe_row * compressed_act_width -1: 0] compressed_act_to_pe_all_rows

);
wire [nb_pe_row * compressed_act_width -1: 0] compressed_act_to_pe_all_rows_D;
//reg out
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		compressed_act_to_pe_all_rows <= 0;
	end
	else begin
		compressed_act_to_pe_all_rows <= compressed_act_to_pe_all_rows_D;
	end
end
genvar i;
generate 
for(i = 0; i < nb_pe_row; i = i + 1) begin
	TS6N28HPCPHVTA768X17M8F ram(
		.AA(wAddr),
		.D(mem_data_in_all_rows[(i+1)*compressed_act_width-1 -: compressed_act_width]),
		.WEB(wEn),
		.CLKW(clk),
		.AB(rAddr),
		.REB(rEn),
		.CLKR(clk),
		.Q(compressed_act_to_pe_all_rows_D[(i+1)*compressed_act_width-1 -: compressed_act_width])
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
