module Mux4in #(parameter
	data_width = 16
)(
	input [data_width-1: 0] in0,
	input [data_width-1: 0] in1,
	input [data_width-1: 0] in2,
	input [data_width-1: 0] in3,
	input [2-1: 0] sel,
	output [data_width-1: 0] out
);
reg [data_width-1: 0] temp;
always@(*) begin
	case(sel)
		2'd0: begin
			temp = in0;
		end
		2'd1: begin
			temp = in1;
		end
		2'd2: begin
			temp = in2;
		end
		2'd3: begin
			temp = in3;
		end
		default: begin
			temp = {data_width{1'bx}};
		end
	endcase
end
assign out = temp;
endmodule