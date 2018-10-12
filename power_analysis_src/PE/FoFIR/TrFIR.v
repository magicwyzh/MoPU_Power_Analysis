module TrFIR #(parameter
	nb_taps = 5,
	weight_width = 16,
	act_width = 16,
	DReg_width = 24,
	tap_width = DReg_width
)(
	input  [act_width-1: 0] act,
	input  [weight_width*nb_taps-1: 0] WRegs,
	input clk, rst_n,
	input DFF_en,
	output reg [DReg_width-1: 0] Fir_out
);

wire signed [weight_width-1: 0] Weights[nb_taps-1: 0];
wire signed [DReg_width-1: 0] DRegs[nb_taps-1: 0];
wire signed [DReg_width-1: 0] tap_out[nb_taps-1: 0];
genvar i;
generate
for(i = 0; i < nb_taps; i = i + 1) begin
	BPMAC U_BPMAC(
		.A(act),
		.W(WRegs[(i+1)*weight_width-1: i*weight_width]),
		.T(DRegs[i]),
		.Y(tap_out[i])
	);
	assign Weights[i] = WRegs[(i+1)*weight_width-1: i*weight_width];
end
for(i = 1; i < nb_taps; i = i + 1)begin

DFF_en #(
    .L_datain              ( DReg_width                            ))
    U_DFF_EN_0(
    .Q                        ( DRegs[i]                       ),
    .D                        ( tap_out[i-1]                       ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .en                             ( DFF_en                            )
);
end
assign DRegs[0] = 0;
endgenerate

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		Fir_out <= 0;
	end
	else begin
		if(DFF_en) begin
			Fir_out <= tap_out[nb_taps-1];
		end
	end
end
endmodule
