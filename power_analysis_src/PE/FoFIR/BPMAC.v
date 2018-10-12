module BPMAC(
	input signed [16-1: 0] A,W,
	input signed [24-1: 0] T,
	output signed [24-1: 0] Y
);
wire signed [32-1: 0] temp;
assign temp = A * W + T;
saturate_32_to_24 U_SATURATE_32_TO_24_0(
    .in                             ( temp                            ),
    .out                            ( Y                           )
);


endmodule 
