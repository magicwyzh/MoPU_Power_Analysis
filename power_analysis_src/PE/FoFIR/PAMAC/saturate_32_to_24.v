module saturate_32_to_24(
	input [32-1: 0] in,
	output reg [24-1: 0] out
);

wire [8-1: 0] high_9_bits;
assign high_9_bits = in[32-1: 24-1];
wire high_9_bits_all_zero;
assign high_9_bits_all_zero = ~(|high_9_bits);
wire high_9_bits_all_one;
assign high_9_bits_all_one = (&high_9_bits);

always@(*) begin
	case({high_9_bits_all_one, high_9_bits_all_zero, in[31]})
		3'b001: begin
			//negative 
			out = 24'h800000;
		end
		3'b000: begin
			//positive
			out = 24'h7fffff;
		end
		3'b010, 3'b100, 3'b011, 3'b101: begin
			out = in[24-1: 0];
		end
		default: begin
			//never meet this brunch
			out = 24'bx;
		end
	endcase
end
endmodule
