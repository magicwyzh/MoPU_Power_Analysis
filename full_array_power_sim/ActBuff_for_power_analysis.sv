module ActBuff_for_power_analysis #(parameter
	//PE Array parameter
	nb_pe_row = 16,
	nb_pe_col = 16,
	//parameters for FoFIR
	activation_width = 16,
	compressed_act_width = activation_width + 1,
	//mem_bank
	mem_bank_width = compressed_act_width,
	mem_depth = 768,
	addr_width = clogb2(mem_depth)
)(
	input [nb_pe_row-1: 0][compressed_act_width-1: 0] mem_data_in_all_rows,
	input [nb_pe_row-1: 0] wEn_AH, 
    input [nb_pe_row-1: 0] rEn_AH, 
	input [nb_pe_row-1: 0][addr_width-1: 0] wAddr,
    input [nb_pe_row-1: 0][addr_width-1: 0] rAddr,
	input clk, rst_n,

	output logic [nb_pe_row-1: 0][compressed_act_width -1: 0] compressed_act_to_pe_all_rows
);
logic [nb_pe_row-1: 0] rEn, wEn;
assign rEn = ~rEn_AH;
assign wEn = ~wEn_AH;
logic [nb_pe_row-1: 0][compressed_act_width -1: 0] compressed_act_to_pe_all_rows_D;
//reg out
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		compressed_act_to_pe_all_rows <= 0;
	end
	else begin
        for(int j = 0; j < nb_pe_row;j++) begin
		    compressed_act_to_pe_all_rows[j] <= compressed_act_to_pe_all_rows_D[j];
        end
	end
end
genvar i;
generate 
for(i = 0; i < nb_pe_row; i = i + 1) begin
	TS6N28HPCPHVTA768X17M8F ram(
		.AA(wAddr[i]),
		.D(mem_data_in_all_rows[i]),
		.WEB(wEn[i]),
		.CLKW(clk),
		.AB(rAddr[i]),
		.REB(rEn[i]),
		.CLKR(clk),
		.Q(compressed_act_to_pe_all_rows_D[i])
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
