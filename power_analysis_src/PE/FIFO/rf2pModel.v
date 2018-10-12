module rf2pModel #(parameter
	nb_data = 16,
	L_data = 17,//12(data)+15(idx)
	L_addr = clogb2(nb_data)
)(
	output reg [L_data-1: 0] rData,
	input [L_data-1: 0] wData,
	input clk,
	input wEn, rEn,
	input [L_addr-1: 0] wAddr, rAddr
);

reg [L_data-1: 0] mem[0: nb_data-1];

always@(posedge clk) begin
	if(!wEn) begin
		mem[wAddr] <= wData;
	end
end

always @ (posedge clk) begin
    if (!rEn) begin
        rData <= mem[rAddr];
    end
end

//************************************************************************
//function called clogb2 that returns an integer which has the
//value of the ceiling of the log base 2.
function integer clogb2 (input integer bit_depth);
begin
bit_depth = bit_depth - 1;
for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
bit_depth = bit_depth>>1;
end
endfunction
//************************************************************************
endmodule
