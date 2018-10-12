module DRegs #(parameter
	data_width = 24,
	nb_taps = 5,
	width_current_tap = nb_taps > 8 ? 4 : 3
)(
	input [data_width-1: 0] results_fr_pamac,
	//control signals
	input [nb_taps-1: 0] DRegs_en,
	input [nb_taps-1: 0] DRegs_clr,
	input [nb_taps-1: 0] DRegs_in_sel,//0 is from left, 1 is from pamac output
	input clk,
	input rst_n,
	input [width_current_tap-1: 0] current_tap_DRegs,

	output [data_width-1: 0] DRegs_out
);

wire [data_width-1: 0] mux4DRegsIn_out[nb_taps-1: 0];
wire [data_width-1: 0] left_regs[nb_taps-1: 0];
reg [data_width-1: 0] DRegs[nb_taps-1:0];

genvar i;
generate
//muxes for the input of DRegs
for(i = 0; i < nb_taps;i = i + 1) begin	
	if(i == 0) begin
		assign left_regs[i] = DRegs[nb_taps-1];
	end
	else begin
		assign left_regs[i] = DRegs[i - 1];
	end
	Mux2in #(
		.L_data                ( data_width                            ))
	U_MUX2IN_DRegs_IN(
		.out                            ( mux4DRegsIn_out[i]                           ),
		.in0                            ( left_regs[i]                           ),
		.in1                            ( results_fr_pamac                           ),
		.sel                            ( DRegs_in_sel[i]                           )
	);
end
//generation of DRegs
for(i = 0; i < nb_taps; i = i + 1) begin
	always@(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			DRegs[i] <= 0;
		end
		else begin
			case({DRegs_en[i], DRegs_clr[i]})
				2'b00: begin
					DRegs[i] <= DRegs[i];
				end
				2'b01: begin
					DRegs[i] <= 0;
				end
				2'b10: begin
					DRegs[i] <= mux4DRegsIn_out[i];
				end
				default: begin
					DRegs[i] <= {data_width{1'bx}};
				end
			endcase
		end
	end
end

//generation of mux to PAMAC
case(nb_taps)
	5: begin
		Mux5in #(
			.data_width            ( data_width                            ))
		U_MUX5IN_DRREG_OUT(
			.in0                            (DRegs[0]                           ),
			.in1                            (DRegs[1]                           ),
			.in2                            (DRegs[2]                           ),
			.in3                            (DRegs[3]                           ),
			.in4                            (DRegs[4]                           ),
			.sel                            ( current_tap_DRegs                           ),
			.out                            ( DRegs_out                           )
		);
	end
	7: begin
		Mux7in #(
		.data_width			           ( data_width                            ))
		U_MUX7IN_DREG_OUT(
		.in0                            (DRegs[0]                           ),
		.in1                            (DRegs[1]                           ),
		.in2                            (DRegs[2]                           ),
		.in3                            (DRegs[3]                           ),
		.in4                            (DRegs[4]                           ),
		.in5                            (DRegs[5]                           ),
		.in6                            (DRegs[6]                           ),
		.sel                            ( current_tap_DRegs                           ),
		.out                            ( DRegs_out                           )
		);

	end
	11: begin
		Mux11in #(
			.data_width            ( data_width                            ))
		U_MUX11IN_DREG_OUT(
			.in0                            (DRegs[0]                           ),
			.in1                            (DRegs[1]                           ),
			.in2                            (DRegs[2]                           ),
			.in3                            (DRegs[3]                           ),
			.in4                            (DRegs[4]                           ),
			.in5                            (DRegs[5]                           ),
			.in6                            (DRegs[6]                           ),
			.in7                            (DRegs[7]                           ),
			.in8                            (DRegs[8]                           ),
			.in9                            (DRegs[9]                           ),
			.in10                           (DRegs[10]                          ),
			.sel                            ( current_tap_DRegs                           ),
			.out                            ( DRegs_out                           )
		);

	end
	default:begin

	end
endcase
endgenerate






endmodule
