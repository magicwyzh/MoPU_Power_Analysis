module Mux2in #(parameter
	L_data = 16
)(
	output [L_data-1: 0] out,
	input [L_data-1: 0] in0, in1,
	input sel
);
assign out = sel == 1'b0 ? in0 : in1;
endmodule
