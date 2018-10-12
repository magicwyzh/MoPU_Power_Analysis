//The WRegs and WBPRs are global, this module are just multiplexers
module weights_bpr_sel#(parameter
	nb_weights = 5,
	data_width = 16,
	bpr_width = ((data_width+1)/2)*3,
	ETC_width = 4,
	width_current_tap = nb_weights > 8 ? 4 : 3
)(
	input [data_width*nb_weights-1: 0] WRegs,
	input [bpr_width*nb_weights-1: 0] WBPRs,
	input [ETC_width*nb_weights-1: 0] ETCs,
	input [width_current_tap-1: 0] current_tap,
	output [data_width-1: 0] W,
	output [bpr_width-1: 0] BPR_W,
	output [ETC_width-1: 0] ETC_W
);

wire [data_width-1: 0] WRegs_array[nb_weights-1: 0];
wire [bpr_width-1: 0] WBPR_array[nb_weights-1: 0];
wire [ETC_width-1: 0] ETC_array[nb_weights-1: 0];
genvar i;
generate 
for(i=0;i<nb_weights;i=i+1) begin
	assign WRegs_array[i] = WRegs[data_width*(i+1)-1: data_width*i];
	assign WBPR_array[i] = WBPRs[bpr_width*(i+1)-1: bpr_width*i];
	assign ETC_array[i] = ETCs[ETC_width*(i+1)-1: ETC_width*i];
end

case(nb_weights)
	5: begin
		Mux5in #(
			.data_width            ( data_width                            ))
		U_MUX5IN_WREG(
			.in0                            (WRegs_array[0 ]                           ),
			.in1                            (WRegs_array[1 ]                          ),
			.in2                            (WRegs_array[2 ]                          ),
			.in3                            (WRegs_array[3 ]                          ),
			.in4                            (WRegs_array[4 ]                          ),
			.sel                            ( current_tap                           ),
			.out                            ( W                           )
		);
		Mux5in #(
			.data_width            ( bpr_width                            ))
		U_MUX5IN_WBPR(
			.in0                            ( WBPR_array[0 ]                           ),
			.in1                            ( WBPR_array[1 ]                          ),
			.in2                            ( WBPR_array[2 ]                          ),
			.in3                            ( WBPR_array[3 ]                          ),
			.in4                            ( WBPR_array[4 ]                          ),
			.sel                            ( current_tap                           ),
			.out                            ( BPR_W                           )
		);
		Mux5in #(
			.data_width            ( ETC_width                            ))
		U_MUX5IN_ETC(
			.in0                            (ETC_array[0 ]                           ),
			.in1                            (ETC_array[1 ]                          ),
			.in2                            (ETC_array[2 ]                          ),
			.in3                            (ETC_array[3 ]                          ),
			.in4                            (ETC_array[4 ]                          ),
			.sel                            ( current_tap                           ),
			.out                            ( ETC_W                           )
		);
	end
	7: begin
		Mux7in #(
			.data_width            ( data_width                            ))
		U_MUX7in_WREG(
			.in0                            (WRegs_array[0 ]                           ),
			.in1                            (WRegs_array[1 ]                          ),
			.in2                            (WRegs_array[2 ]                          ),
			.in3                            (WRegs_array[3 ]                          ),
			.in4                            (WRegs_array[4 ]                          ),
			.in5                            (WRegs_array[5 ]                          ),
			.in6                            (WRegs_array[6 ]                          ),
			.sel                            ( current_tap                           ),
			.out                            ( W                           )
		);
		Mux7in #(
			.data_width            ( bpr_width                            ))
		U_MUX7in_WBPR(
			.in0                            ( WBPR_array[0 ]                           ),
			.in1                            ( WBPR_array[1 ]                          ),
			.in2                            ( WBPR_array[2 ]                          ),
			.in3                            ( WBPR_array[3 ]                          ),
			.in4                            ( WBPR_array[4 ]                          ),
			.in5                            ( WBPR_array[5 ]                          ),
			.in6                            ( WBPR_array[6 ]                          ),
			.sel                            ( current_tap                           ),
			.out                            ( BPR_W                           )
		);
		Mux7in #(
			.data_width            ( ETC_width                            ))
		U_MUX7in_ETC(
			.in0                            (ETC_array[0 ]                           ),
			.in1                            (ETC_array[1 ]                          ),
			.in2                            (ETC_array[2 ]                          ),
			.in3                            (ETC_array[3 ]                          ),
			.in4                            (ETC_array[4 ]                          ),
			.in5                            (ETC_array[5 ]                          ),
			.in6                            (ETC_array[6 ]                          ),
			.sel                            ( current_tap                           ),
			.out                            ( ETC_W                           )
		);
	end
	11: begin
		Mux11in #(
			.data_width            ( data_width                            ))
		U_MUX11in_WREG(
			.in0                            (WRegs_array[0 ]                           ),
			.in1                            (WRegs_array[1 ]                          ),
			.in2                            (WRegs_array[2 ]                          ),
			.in3                            (WRegs_array[3 ]                          ),
			.in4                            (WRegs_array[4 ]                          ),
			.in5                            (WRegs_array[5 ]                          ),
			.in6                            (WRegs_array[6 ]                          ),
			.in7                            (WRegs_array[7 ]                          ),
			.in8                            (WRegs_array[8 ]                          ),
			.in9                            (WRegs_array[9 ]                          ),
			.in10                           (WRegs_array[10 ]                          ),
			.sel                            ( current_tap                           ),
			.out                            ( W                           )
		);
		Mux11in #(
			.data_width            ( bpr_width                            ))
		U_MUX11in_WBPR(
			.in0                            ( WBPR_array[0 ]                           ),
			.in1                            ( WBPR_array[1 ]                          ),
			.in2                            ( WBPR_array[2 ]                          ),
			.in3                            ( WBPR_array[3 ]                          ),
			.in4                            ( WBPR_array[4 ]                          ),
			.in5                            ( WBPR_array[5 ]                          ),
			.in6                            ( WBPR_array[6 ]                          ),
			.in7                            (WBPR_array[7 ]                          ),
			.in8                            (WBPR_array[8 ]                          ),
			.in9                            (WBPR_array[9 ]                          ),
			.in10                           (WBPR_array[10 ]                          ),
			.sel                            ( current_tap                           ),
			.out                            ( BPR_W                           )
		);
		Mux11in #(
			.data_width            ( ETC_width                            ))
		U_MUX11in_ETC(
			.in0                            (ETC_array[0 ]                           ),
			.in1                            (ETC_array[1 ]                          ),
			.in2                            (ETC_array[2 ]                          ),
			.in3                            (ETC_array[3 ]                          ),
			.in4                            (ETC_array[4 ]                          ),
			.in5                            (ETC_array[5 ]                          ),
			.in6                            (ETC_array[6 ]                          ),
			.in7                            (ETC_array[7 ]                          ),
			.in8                            (ETC_array[8 ]                          ),
			.in9                            (ETC_array[9 ]                          ),
			.in10                           (ETC_array[10]                          ),
			.sel                            ( current_tap                           ),
			.out                            ( ETC_W                           )
		);
	end
	default: begin
		
	end
endcase


endgenerate


endmodule
