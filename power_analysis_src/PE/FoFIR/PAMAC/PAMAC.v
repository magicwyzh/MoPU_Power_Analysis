module PAMAC(
	//data signal
	input [16-1: 0] A, W,
	input [24-1: 0] T,
	input [4-1: 0] ETC_A, ETC_W,
	input [8*3-1: 0] BPR_W, BPR_A,
	//control signal
	input [3-1: 0] BPEB_sel,
	input DFF_en,
	input first_cycle, 
	input MDecomp,
	input AWDecomp,
	input clk, rst_n,
	output [24-1: 0] Y
);

wire [3-1: 0] shift_ctrl;
assign shift_ctrl = BPEB_sel;

wire double, neg;
wire mul_sel;
PAMAC_AP U_PAMAC_AP_0(
    .A                              ( A                             ),
    .W                              ( W                             ),
    .T                              ( T                             ),
    .mul_sel                        ( mul_sel                       ),
    .Y                              ( Y                             ),
    .shift_ctrl                     ( shift_ctrl                    ),
    .double                         ( double                        ),
    .neg                            ( neg                           ),
    .first_cycle                    ( first_cycle                   ),
    .DFF_en							( DFF_en                ),
	.clk							( clk   ),
    .rst_n                          ( rst_n                         )
);

PAMAC_CP U_PAMAC_CP_0(
    .double                         ( double                        ),
    .neg                            ( neg                           ),
    .mul_sel                        ( mul_sel                       ),
    .ETC_A                          ( ETC_A                         ),
    .ETC_W                          ( ETC_W                         ),
    .BPR_W                          ( BPR_W                         ),
    .BPR_A                          ( BPR_A                         ),
    .BPEB_sel                       ( BPEB_sel                      ),
	.MDecomp						( MDecomp                       ),
	.AWDecomp						( AWDecomp                      )
);

endmodule
