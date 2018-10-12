module DRegs_indexing #(parameter
	nb_taps = 5,
	width_current_tap = nb_taps > 8 ? 4 : 3
)(
	//control ports from controller
	input index_update_en,
	input [width_current_tap-1: 0] current_tap,
	input clk, rst_n,
	output [width_current_tap-1: 0] PD0,
	output [width_current_tap-1: 0] current_tap_DRegs
);

reg [width_current_tap-1: 0] D0_position;
//wire [width_current_tap-1: 0] PD0;
wire [width_current_tap-1: 0] new_D0_position;
assign PD0 = D0_position;
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		D0_position <= 0;
	end
	else begin
		if(index_update_en) begin
			D0_position <= new_D0_position;
		end
	end
end
/****************new D0 position generation**************/
wire [width_current_tap-1: 0] PD0_minus_1;
wire [width_current_tap-1: 0] PD0_plus_n_tap_minus_1;
assign PD0_minus_1 = PD0 - 1;//even if it is less than zero
assign PD0_plus_n_tap_minus_1 = PD0 + (nb_taps -1);
wire PD0_is_zero;
assign PD0_is_zero = PD0 == 0;
assign new_D0_position = PD0_is_zero ? PD0_plus_n_tap_minus_1 : PD0_minus_1;


/*********current_tap_DRegs generation********************/
wire [width_current_tap: 0] current_tap_plus_PD0;
assign current_tap_plus_PD0 = current_tap + PD0;
wire signed [width_current_tap+1: 0] current_tap_plus_PD0_minus_ntap;
assign current_tap_plus_PD0_minus_ntap = $signed({1'b0, current_tap_plus_PD0}) - $signed(nb_taps);
wire sign;
assign sign = current_tap_plus_PD0_minus_ntap[width_current_tap+1];
assign current_tap_DRegs = sign == 1'b1 ? current_tap_plus_PD0[width_current_tap-1: 0] : current_tap_plus_PD0_minus_ntap[width_current_tap-1: 0];


endmodule
