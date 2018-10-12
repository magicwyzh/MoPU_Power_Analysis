module Mux11in #(parameter
	data_width = 16
)(
	input [data_width-1: 0] in0,
	input [data_width-1: 0] in1,
	input [data_width-1: 0] in2,
	input [data_width-1: 0] in3,
	input [data_width-1: 0] in4,
	input [data_width-1: 0] in5,
	input [data_width-1: 0] in6,
	input [data_width-1: 0] in7,
	input [data_width-1: 0] in8,
	input [data_width-1: 0] in9,
	input [data_width-1: 0] in10,
	input [4-1: 0] sel,
	output [data_width-1: 0] out
);
reg [data_width-1: 0] temp;
always@(*) begin
	case(sel)
		4'd0: begin
			temp = in0;
		end
		4'd1: begin
			temp = in1;
		end
		4'd2: begin
			temp = in2;
		end
		4'd3: begin
			temp = in3;
		end
		4'd4: begin
			temp = in4;
		end
		4'd5: begin
			temp = in5;
		end
		4'd6: begin
			temp = in6;
		end
		4'd7: begin
			temp = in7;
		end
		4'd8: begin
			temp = in8;
		end
		4'd9: begin
			temp = in9;
		end
		4'd10: begin
			temp = in10;
		end
		default: begin
			temp = {data_width{1'bx}};
		end
	endcase
end
assign out = temp;
endmodule