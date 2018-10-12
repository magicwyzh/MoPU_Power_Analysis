module SRAM_8192x16bits #(parameter
	nb_data = 8192,
	L_data = 16,//12(data)+15(idx)
	L_addr = clogb2(nb_data)
)(
	output [L_data-1: 0] rData,
	input [L_data-1: 0] wData,
	input clk,
	input wEn, rEn,
	input [L_addr-1: 0] wAddr, rAddr

);


wire rEn_for_each_ram[4-1: 0];
wire wEn_for_each_ram[4-1: 0];
wire [L_data-1: 0] rData_buf[4-1: 0];
genvar i;
generate
for(i = 0; i < 4; i = i + 1) begin
	assign rEn_for_each_ram[i] = rAddr[L_addr-1 -: 2] == i ? rEn : 1;
	assign wEn_for_each_ram[i] = wAddr[L_addr-1 -: 2] == i ? wEn : 1;
	TS6N28HPCPHVTA2048X16M8S ram(
		.AA(wAddr[L_addr-2-1: 0]),
		.D(wData),
		.WEB(wEn_for_each_ram[i]),
		.CLKW(clk),
		.AB(rAddr[L_addr-2-1: 0]),
		.REB(rEn_for_each_ram[i]),
		.CLKR(clk),
		.Q(rData_buf[i])
	);	

end
endgenerate
reg [2-1: 0] delayed_rAddr_high_bit;

always@(posedge clk) begin
	delayed_rAddr_high_bit <= rAddr[L_addr-1 -: 2];
end



Mux4in #(
    .data_width            ( L_data                            ))
U_MUX4IN_0(
    .in0                            ( rData_buf[0]                           ),
    .in1                            ( rData_buf[1]                           ),
    .in2                            ( rData_buf[2]                           ),
    .in3                            ( rData_buf[3]                         ),
    .sel                            ( delayed_rAddr_high_bit                           ),
    .out                            ( rData                           )
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
