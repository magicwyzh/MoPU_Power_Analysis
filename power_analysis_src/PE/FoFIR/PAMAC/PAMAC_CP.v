module PAMAC_CP(
	output double, neg, mul_sel,
	input [4-1: 0] ETC_A, ETC_W,
	input [8*3-1: 0] BPR_W, BPR_A,
	input MDecomp,
	input AWDecomp,
	input [3-1: 0] BPEB_sel
);

wire mulwise_mul_sel;
assign mulwise_mul_sel= ETC_A > ETC_W ? 1'b1 : 1'b0;
wire awdecomp_mul_sel;
assign awdecomp_mul_sel = AWDecomp;
assign mul_sel = MDecomp == 1'b1 ? mulwise_mul_sel : awdecomp_mul_sel;
//assign mul_sel = ETC_A > ETC_W ? 1'b1 : 1'b0;

wire [8*3-1: 0] BPR;
assign BPR = mul_sel ? BPR_W : BPR_A;

reg [3-1: 0] current_BPEB;
always@(*) begin
	case(BPEB_sel) 
		3'd0: begin
			current_BPEB = BPR[3*1-1: 3*0];
		end
		3'd1: begin
			current_BPEB = BPR[3*2-1: 3*1];
		end
		3'd2: begin
			current_BPEB = BPR[3*3-1: 3*2];
		end
		3'd3: begin
			current_BPEB = BPR[3*4-1: 3*3];
		end
		3'd4: begin
			current_BPEB = BPR[3*5-1: 3*4];
		end
		3'd5: begin
			current_BPEB = BPR[3*6-1: 3*5];
		end
		3'd6: begin
			current_BPEB = BPR[3*7-1: 3*6];
		end
		3'd7: begin
			current_BPEB = BPR[3*8-1: 3*7];
		end

	endcase
end

assign double = (current_BPEB == 3'b011 || current_BPEB == 3'b100) ? 1'b1 : 1'b0;
assign neg = (current_BPEB == 3'b100 || current_BPEB == 3'b101 || current_BPEB == 3'b110) ? 1'b1 : 1'b0;
endmodule
