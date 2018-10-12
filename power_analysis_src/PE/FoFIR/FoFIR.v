module FoFIR #(parameter
	nb_taps = 5,
	activation_width = 16,
	weight_width = 16,
	tap_width = 24,
	weight_bpr_width = ((weight_width+1)/2)*3,
	act_bpr_width = ((activation_width+1)/2)*3,
	ETC_width = 4,
	width_current_tap = nb_taps > 8 ? 4 : 3,
	output_width = tap_width
)(
	//data ports
	input [weight_width*nb_taps-1: 0] WRegs,
	input [weight_bpr_width*nb_taps-1: 0] WBPRs,
	input [ETC_width*nb_taps-1: 0] WETCs,
	
	input [activation_width-1: 0] act_value,
	
	//configuration ports
	input [4-1: 0] n_ap,

	//control ports for PAMAC
	input [3-1: 0] PAMAC_BPEB_sel,
	input PAMAC_DFF_en,
	input PAMAC_first_cycle,
	//the following two inputs are reserved 
	input PAMAC_MDecomp,//1 is mulwise, 0 is layerwise
	input PAMAC_AWDecomp,// 0 is act decomp, 1 is w decomp

	//control signals for FoFIR
	input [width_current_tap-1: 0] current_tap,
	//DRegs signals
	input [nb_taps-1: 0] DRegs_en,
	input [nb_taps-1: 0] DRegs_clr,
	input [nb_taps-1: 0] DRegs_in_sel,//0 is from left, 1 is from pamac output
	
	//DRegs indexing signals
	input index_update_en,

	//output signals
	input out_mux_sel,//0 is from PAMAC, 1 is from DRegs
	input out_reg_en,

	input clk, rst_n,
	

	output [width_current_tap-1: 0] PD0,
	output [output_width-1: 0] F
	
);
wire [weight_bpr_width-1: 0] BPR_W;
wire [ETC_width-1: 0] ETC_W, ETC_A;
wire [weight_width-1: 0] W;
wire [activation_width-1: 0] A;
assign A = act_value;
wire [act_bpr_width-1: 0] BPR_A;

weights_bpr_sel #(
    .nb_weights            ( nb_taps                             ),
    .data_width                     ( weight_width                            ),
    .ETC_width                      ( ETC_width                             ),
    .width_current_tap              ( width_current_tap             ))
U_WEIGHTS_BPR_SEL_0(
    .WRegs                          ( WRegs                         ),
    .WBPRs                          ( WBPRs                         ),
    .ETCs                           ( WETCs                          ),
    .current_tap                    ( current_tap                   ),
    .W                              ( W                             ),
    .BPR_W                          ( BPR_W                         ),
    .ETC_W                          ( ETC_W                         )
);

BPEB_Enc_ETC U_BPEB_ENC_ETC_0(
    .in                             ( act_value                            ),
    .n_ap                           ( n_ap                          ),
    .BPR                            ( BPR_A                           ),
    .ETC                            ( ETC_A                           )
);
wire [width_current_tap-1: 0] current_tap_DRegs;
DRegs_indexing #(
    .nb_taps               ( nb_taps                             ),
    .width_current_tap              ( width_current_tap                 ))
U_DREGS_INDEXING_0(
    .index_update_en                ( index_update_en               ),
    .current_tap                    ( current_tap                   ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .current_tap_DRegs              ( current_tap_DRegs             ),
	.PD0							( PD0                           )
);

wire [tap_width-1: 0] results_fr_pamac, DRegs_out;
wire [tap_width-1: 0] T;
assign T = DRegs_out;
DRegs #(
    .data_width            (  tap_width                           ),
    .nb_taps                        ( nb_taps                             ),
    .width_current_tap              ( width_current_tap                 ))
U_DREGS_0(
    .results_fr_pamac               ( results_fr_pamac              ),
    .DRegs_en                       ( DRegs_en                      ),
    .DRegs_clr                      ( DRegs_clr                     ),
    .DRegs_in_sel                   ( DRegs_in_sel                  ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .current_tap_DRegs              ( current_tap_DRegs             ),
    .DRegs_out                      ( DRegs_out                     )
);

PAMAC U_PAMAC_0(
    .A                              ( A                             ),
    .W                              ( W                             ),
    .T                              ( T                             ),
    .ETC_A                          ( ETC_A                         ),
    .ETC_W                          ( ETC_W                         ),
    .BPR_W                          ( BPR_W                         ),
    .BPR_A                          ( BPR_A                         ),
    .BPEB_sel                       ( PAMAC_BPEB_sel                      ),
    .DFF_en                         ( PAMAC_DFF_en                        ),
    .first_cycle                    ( PAMAC_first_cycle                   ),
    .MDecomp                        ( PAMAC_MDecomp                       ),
    .AWDecomp                       ( PAMAC_AWDecomp                      ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .Y                              ( results_fr_pamac                             )
);


/*
PAMAC U_PAMAC_0(
    .A                              ( A                             ),
    .W                              ( W                             ),
    .T                              ( T                             ),
    .ETC_A                          ( ETC_A                         ),
    .ETC_W                          ( ETC_W                         ),
    .BPR_W                          ( BPR_W                         ),
    .BPR_A                          ( BPR_A                         ),
	.MDecomp						( PAMAC_MDecomp                 ),
	.AWDecomp						( PAMAC_AWDecomp                 ),
    .BPEB_sel                       ( PAMAC_BPEB_sel                      ),
    .DFF_en                         ( PAMAC_DFF_en                        ),
    .first_cycle                    ( PAMAC_first_cycle                   ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .Y                              ( results_fr_pamac                             )
);
*/
/*********************The output register and mux******/
reg [output_width-1: 0] out_reg;
wire [output_width-1: 0] output_mux_out;

Mux2in #(
    .L_data				           ( output_width                            ))
U_MUX2IN_OUTPUTMUX(
    .out                            ( output_mux_out                           ),
    .in0                            ( results_fr_pamac                           ),
    .in1                            ( DRegs_out                           ),
    .sel                            ( out_mux_sel                           )
);

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_reg <= 0;
	end
	else begin
		if(out_reg_en) begin
			out_reg <= output_mux_out;
		end
	end
end
assign F = out_reg;

endmodule
