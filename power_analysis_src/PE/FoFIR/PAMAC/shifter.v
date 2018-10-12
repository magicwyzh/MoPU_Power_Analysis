module left_shifter(
	input [16-1: 0] in_data,
	output reg [32-1: 0] out_data,
	input [3-1: 0] shift_ctrl
);

wire [32-1: 0] in_data_expand;
assign in_data_expand = {{16{in_data[16-1]}}, in_data};

always@(*) begin
	case(shift_ctrl)
		3'd0: begin
			out_data = in_data_expand << 0;
		end
		3'd1: begin
			out_data = in_data_expand << 2;
		end
		3'd2: begin
			out_data = in_data_expand << 4;
		end
		3'd3: begin
			out_data = in_data_expand << 6;
		end
		3'd4: begin
					out_data = in_data_expand << 8;
				end
		3'd5: begin
					out_data = in_data_expand << 10;
				end
		3'd6: begin
					out_data = in_data_expand << 12;
				end
		3'd7: begin
					out_data = in_data_expand << 14;
				end
		default:begin
			out_data = 32'bx;
		end
	endcase
end
endmodule
