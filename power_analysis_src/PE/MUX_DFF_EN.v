module MUX_DFF_en #(parameter
data_width = 24
)(
	input [data_width-1: 0] in1,
	input [data_width-1: 0] in2,
	input sel,
	output  [data_width-1: 0] out,
	input clk, 
	input rst_n,
	input en
);

wire [data_width-1: 0] mux_out;
Mux2in #(
    .L_data                ( data_width                            ))
U_MUX2IN_0(
    .out                            ( mux_out                           ),
    .in0                            ( in1                           ),
    .in1                            ( in2                           ),
    .sel                            ( sel                           )
);

DFF_en #(
    .L_datain              ( data_width                           ))
U_DFF_EN_0(
    .Q                        (  out                      ),
    .D                        (   mux_out                     ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .en                             ( en                            )
);


endmodule
