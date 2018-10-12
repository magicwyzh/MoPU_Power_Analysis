module bit_parallel_MAC(
	input signed [16-1: 0] A,W,
	input signed [24-1: 0] T,
	input clk, rst_n,
	output reg [24-1: 0] Y_Q
);

wire signed [32-1: 0] temp;
assign temp = A * W + T;
wire signed [24-1: 0] Y;
saturate_32_to_24 U_SATURATE_32_TO_24_0(
    .in                             ( temp                            ),
    .out                            ( Y                           )
);
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		Y_Q <= 0;
	end
	else begin
		Y_Q <= Y;
	end
	
end

endmodule

