module Adder #(parameter
	L_datain1 = 32,
	L_datain2 = 32,
	L_dataout = 32,
	res_bits = L_dataout - L_datain2
)(
	output signed [L_dataout-1: 0] out,
	input signed [L_datain1-1: 0] in1,
	input signed [L_datain2-1: 0] in2,
	input carry
);
assign out = in1 +  in2 + carry;
endmodule
