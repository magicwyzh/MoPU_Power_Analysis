module BPEB_Enc_ETC(
	input [16-1: 0] in,
	input [4-1: 0] n_ap,
	output reg [8*3-1: 0] BPR,
	output [4-1: 0] ETC
);
genvar i;
generate
wire [8*3-1: 0] encoded_result;
wire [8-1: 0] is_essential_term_temp;
reg [8-1: 0] is_essential_term;
for(i = 0; i < 8;i = i + 1)begin
	assign encoded_result[3*i+1] = in[2*i];
	assign encoded_result[3*i+2] = in[2*i + 1];
	if(i > 0) begin
		assign encoded_result[3*i] = in[2*i-1];
	end
	else begin
		assign encoded_result[3*i] = 0;
	end
	assign is_essential_term_temp[i] = (encoded_result[3*i+2:3*i] == 3'b000)||(encoded_result[3*i+2:3*i] == 3'b111)? 0 : 1;
end
endgenerate

always@(*) begin
	case(n_ap)
		4'd0: begin
			BPR = encoded_result;
			is_essential_term = is_essential_term_temp;
		end
		4'd1: begin
			BPR[3*1-1: 0] = 0;
			BPR[3*8-1: 3*1] = encoded_result[3*8-1: 3*1];
			is_essential_term[1-1: 0] = 0;
			is_essential_term[8-1: 1] = is_essential_term_temp[8-1: 1];

		end
		4'd2: begin
			BPR[3*2-1: 0] = 0;
			BPR[3*8-1: 3*2] = encoded_result[3*8-1: 3*2];
			is_essential_term[2-1: 0] = 0;
			is_essential_term[8-1: 2] = is_essential_term_temp[8-1: 2];
		end
		4'd3: begin
			BPR[3*3-1: 0] = 0;
			BPR[3*8-1: 3*3] = encoded_result[3*8-1: 3*3];
			is_essential_term[3-1: 0] = 0;
			is_essential_term[8-1: 3] = is_essential_term_temp[8-1: 3];
		end
		4'd4: begin
			BPR[3*4-1: 0] = 0;
			BPR[3*8-1: 3*4] = encoded_result[3*8-1: 3*4];
			is_essential_term[4-1: 0] = 0;
			is_essential_term[8-1: 4] = is_essential_term_temp[8-1: 4];
		end
		4'd5: begin
			BPR[3*5-1: 0] = 0;
			BPR[3*8-1: 3*5] = encoded_result[3*8-1: 3*5];
			is_essential_term[5-1: 0] = 0;
			is_essential_term[8-1: 5] = is_essential_term_temp[8-1: 5];
		end
		4'd6: begin
			BPR[3*6-1: 0] = 0;
			BPR[3*8-1: 3*6] = encoded_result[3*8-1: 3*6];
			is_essential_term[6-1: 0] = 0;
			is_essential_term[8-1: 6] = is_essential_term_temp[8-1: 6];
		end
		default: begin
			//approximate computing with larger than 6 is almost not possible
			//to be used
			BPR = 24'bx;
		end
	endcase
end


/**********Generate the ETC********************/
assign ETC = ((is_essential_term[0] + 
			 is_essential_term[1]) + 
			 (is_essential_term[2] + 
			 is_essential_term[3])) + 
			 ((is_essential_term[4] + 
			 is_essential_term[5]) + 
			 (is_essential_term[6] + 
			 is_essential_term[7]));
endmodule
