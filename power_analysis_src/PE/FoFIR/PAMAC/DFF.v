module DFF_en #(parameter
	L_datain = 16,
	L_dataout = L_datain
)(
	output reg  [L_dataout-1: 0] Q,
	input  [L_datain-1: 0] D,
	input clk,
	input rst_n,
	input en
);
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		Q <= 0;
	end
	else begin
		if(en) begin
			Q <= D;
		end
	end
		
end
endmodule


