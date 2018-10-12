module PAMAC_AP(
	input [16-1: 0] A, W, 
	input [24-1: 0] T,
	input mul_sel,
	output [24-1: 0] Y,
	input [3-1: 0] shift_ctrl,
	input double, neg, first_cycle, DFF_en,
	input clk, 
	input rst_n
);


wire [16-1: 0] mux0_out;
Mux2in #(
    .L_data						    ( 16                            ))
U_MUX2IN_0(
    .out                            ( mux0_out                           ),
    .in0                            ( W                      ),
    .in1                            ( A                           ),
    .sel                           ( mul_sel                          )
);


wire [32-1: 0] shifter_out;
left_shifter U_LEFT_SHIFTER_0(
    .in_data                        ( mux0_out                       ),
    .out_data                       ( shifter_out                      ),
    .shift_ctrl                     ( shift_ctrl                    )
);

wire [32-1: 0] mux1_out;
Mux2in #(
    .L_data						    ( 32                            ))
U_MUX2IN_1(
    .out                            ( mux1_out                           ),
    .in0                            ( shifter_out                      ),
    .in1                            ( shifter_out << 1                           ),
    .sel                           ( double                          )
);

wire [32-1: 0] mux2_out;
Mux2in #(
    .L_data						    ( 32                            ))
U_MUX2IN_2(
    .out                            ( mux2_out                           ),
    .in0                            ( mux1_out                      ),
    .in1                            ( ~mux1_out             ),
    .sel                           ( neg                          )
);

wire [32-1: 0] mux3_out;
wire [32-1: 0] DFF_out;
Mux2in #(
    .L_data						    ( 32                            ))
U_MUX2IN_3(
    .out                            ( mux3_out                           ),
    .in0                            (DFF_out                   ),
    .in1                            ( {{8{T[23]}},T}             ),
    .sel                           ( first_cycle                          )
);


wire [32-1: 0] adder_out;
Adder #(
    .L_datain1             ( 32                            ),
    .L_datain2                      ( 32                            ),
    .L_dataout                      ( 32                            ))
U_ADDER_0(
    .out                      ( adder_out                     ),
    .in1                      ( mux2_out    ),
    .in2                      ( mux3_out                     ),
    .carry                          ( neg                         )
);

DFF_en #(
    .L_datain			            ( 32                            ))
U_DFF_EN_0(
    .Q                        ( DFF_out                       ),
    .D                        ( adder_out                       ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .en                             ( DFF_en                            )
);




saturate_32_to_24 U_SATURATE_32_TO_24_0(
    .in                             ( adder_out                            ),
    .out                            ( Y                           )
);


endmodule
