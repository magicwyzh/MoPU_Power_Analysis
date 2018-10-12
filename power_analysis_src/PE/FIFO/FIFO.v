module FIFO #(parameter
nb_data = 16,
L_data = 12,
SRAM_IMPL = 0,
L_addr = clogb2(nb_data),
word_width = L_data,
stk_height = nb_data,
stk_ptr_width = L_addr
)(
	output [word_width-1: 0] DataOut,
	output stk_full, stk_almost_full, stk_half_full, stk_almost_empty,stk_empty,

	input [word_width-1: 0] DataIn,
	input write, read,
	input clk, rst_n

);

wire [stk_ptr_width-1: 0] write_ptr, read_ptr;
wire write_to_stk, read_fr_stk;
actQueueDataPath #(
	.nb_data(nb_data),
	.L_data(L_data),
	.SRAM_IMPL(SRAM_IMPL),
	.L_addr(L_addr))
	DataPath (
		.DataOut(DataOut),
		.DataIn(DataIn),
		.write_ptr(write_ptr),
		.read_ptr(read_ptr),
		.write_to_stk(write_to_stk),
		.read_fr_stk(read_fr_stk),
		.clk(clk)
	);
				
actQueueStatus #(
	.nb_data(nb_data),
	.L_data(L_data),
	.L_addr(L_addr))
	StatusModule(
	.write_ptr(write_ptr),
	.read_ptr(read_ptr),
	.stk_full(stk_full),
	.stk_almost_full(stk_almost_full),
	.stk_half_full(stk_half_full),
	.stk_almost_empty(stk_almost_empty),
	.stk_empty(stk_empty),
	.write_to_stk(write_to_stk),
	.read_fr_stk(read_fr_stk),
	.clk(clk),
	.rst_n(rst_n)
	);


actQueueCtrl Ctrl(
    .write_to_stk                   ( write_to_stk                  ),
    .read_fr_stk                    ( read_fr_stk                   ),
    .write                          ( write                         ),
    .read                           ( read                          ),
    .stk_full                       ( stk_full                      ),
    .stk_empty                      ( stk_empty                     )
);


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
