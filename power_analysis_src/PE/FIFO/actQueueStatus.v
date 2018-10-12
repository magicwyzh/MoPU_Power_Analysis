module actQueueStatus #(parameter
nb_data = 16,
L_data = 17,//12(data)+15(idx)
L_addr = clogb2(nb_data),
word_width = L_data,
stk_height = nb_data,
stk_ptr_width = L_addr,
HF_level = stk_height >> 1,//half full
AF_level = (stk_height - HF_level) >>1,//almost full
AE_level = (HF_level) >> 1//almost empty
)(
	output [stk_ptr_width-1: 0] write_ptr, read_ptr,
	output stk_full,stk_almost_full,stk_half_full,stk_almost_empty,stk_empty,

	input write_to_stk, read_fr_stk,
	input clk,rst_n

);
wire [stk_ptr_width: 0] wr_cntr,rd_cntr;
wire [stk_ptr_width: 0] ptr_gap;
assign ptr_gap = wr_cntr - rd_cntr;

assign stk_full = ptr_gap == stk_height || ~rst_n;
assign stk_almost_full = ptr_gap == AF_level || ~rst_n;
assign stk_half_full = ptr_gap == HF_level || ~rst_n;
assign stk_almost_empty = ptr_gap == AE_level || ~rst_n;
assign stk_empty = ptr_gap == 0 || ~rst_n;

wr_cntr_Unit #(.nb_data(nb_data),.L_data(L_data)) WRCNTRUNIT(wr_cntr, write_ptr,write_to_stk,clk,rst_n);
rd_cntr_Unit #(.nb_data(nb_data),.L_data(L_data)) RDCNTRUNIT(rd_cntr, read_ptr, read_fr_stk, clk, rst_n);


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



module wr_cntr_Unit #(parameter 
nb_data = 16,
L_data = 17,//12(data)+15(idx)
L_addr = clogb2(nb_data),
word_width = L_data,
stk_height = nb_data,
stk_ptr_width = L_addr
)(
	output reg [stk_ptr_width:0] wr_cntr,//used to compute the ptr_gap but not for register file access
	output [stk_ptr_width-1: 0] write_ptr,//for register file access
	input write_to_stk, clk, rst_n
);


assign write_ptr = wr_cntr[stk_ptr_width-1: 0];

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) 
		wr_cntr <= 0;
	else if(write_to_stk) begin
		wr_cntr <= wr_cntr + 1;
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

module rd_cntr_Unit #(parameter 
nb_data = 16,
L_data = 17,//12(data)+15(idx)
L_addr = clogb2(nb_data),
word_width = L_data,
stk_height = nb_data,
stk_ptr_width = L_addr
)(
	output reg [stk_ptr_width:0] rd_cntr,//used to compute the ptr_gap but not for register file access
	output [stk_ptr_width-1: 0] read_ptr,//for register file access
	input read_fr_stk, clk, rst_n
);


assign read_ptr = rd_cntr[stk_ptr_width-1: 0];

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) 
		rd_cntr <= 0;
	else if(read_fr_stk) begin
		rd_cntr <= rd_cntr + 1;
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
