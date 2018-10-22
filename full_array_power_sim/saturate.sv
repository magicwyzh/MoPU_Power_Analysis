module saturate #(parameter
	L_datain = 24,
	L_dataout = 16,
	maxNum = {1'b0,{(L_dataout-1){1'b1}}},
	minNum = {1'b1,{(L_dataout-1){1'b0}}},
	L_redundant = L_datain-L_dataout
)(
	input signed [L_datain-1: 0] in,
	output reg signed [L_dataout-1 : 0] out
);
logic [L_redundant: 0] highBits;
assign highBits = in[L_datain-1: L_dataout-1];
logic gt,lt;
assign gt = highBits[L_redundant] == 1'b0 && (|highBits[L_redundant-1:0]) != 1'b0;//must be 000000xx if positive
assign lt = highBits[L_redundant] ==1'b1 && (&highBits[L_redundant-1:0]) != 1'b1; //must be 111111xx if negative
always@(*)begin
case({gt,lt})
	2'b00: out = in[L_dataout-1: 0];
	2'b10: out = maxNum;
	2'b01: out = minNum;
	default: out = {(L_dataout){1'bx}};
endcase
end

endmodule
