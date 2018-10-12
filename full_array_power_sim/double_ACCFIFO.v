// double buffered ACCFIFO
// the one that not for FoFIRcompute and accumulate but for being sent to global buffer is called 
// "shadow fifo", another one called "compute fifo"
module double_ACCFIFO #(parameter
    nb_data = 32, 
    output_width = 24,
    SRAM_IMPL = 1
)(
    input [output_width-1: 0] data_in,
    input compute_fifo_write,
    input compute_fifo_read,
    input shadow_fifo_read,
    input which_fifo_to_compute,
    output [output_width-1: 0] compute_fifo_data_out,
    output [output_width-1: 0] shadow_fifo_data_out,
    output shadow_fifo_empty,
    input clk, 
    input rst_n
);

wire [output_width-1: 0] ACCFIFO_0_data_out;
wire [output_width-1: 0] ACCFIFO_1_data_out;
wire ACCFIFO_0_empty;
wire ACCFIFO_1_empty;
wire ACCFIFO_0_read, ACCFIFO_1_read, ACCFIFO_0_write, ACCFIFO_1_write;
assign compute_fifo_data_out = which_fifo_to_compute ? ACCFIFO_1_data_out : ACCFIFO_0_data_out;
assign shadow_fifo_data_out = which_fifo_to_compute ? ACCFIFO_0_data_out : ACCFIFO_1_data_out;
assign shadow_fifo_empty = which_fifo_to_compute ? ACCFIFO_0_empty : ACCFIFO_1_empty;
assign ACCFIFO_0_read = which_fifo_to_compute ? shadow_fifo_read : compute_fifo_read;
assign ACCFIFO_1_read = which_fifo_to_compute ? compute_fifo_read : shadow_fifo_read;
assign ACCFIFO_0_write = which_fifo_to_compute ? 0 : compute_fifo_write;
assign ACCFIFO_1_write = which_fifo_to_compute ? compute_fifo_write : 0;
assign compute_fifo_data_out = which_fifo_to_compute ? ACCFIFO_1_data_out : ACCFIFO_0_data_out;
assign shadow_fifo_data_out = which_fifo_to_compute ? ACCFIFO_0_data_out : ACCFIFO_1_data_out;

FIFO #(
    .nb_data               ( nb_data                            ),
    .L_data                         ( output_width                            ),
    .SRAM_IMPL                      ( SRAM_IMPL                             ))
ACCFIFO_0(
    .DataOut                        ( ACCFIFO_0_data_out                       ),
    .stk_full                       (              ),
    .stk_almost_full                (              ),
    .stk_half_full                  (              ),
    .stk_almost_empty               (              ),
    .stk_empty                      ( ACCFIFO_0_empty             ),
    .DataIn                         (  data_in     ),
    .write                          (  ACCFIFO_0_write                         ),
    .read                           ( ACCFIFO_0_read ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         )
);

FIFO #(
    .nb_data               ( nb_data                           ),
    .L_data                         ( output_width                            ),
    .SRAM_IMPL                      ( SRAM_IMPL                             ))
ACCFIFO_1(
    .DataOut                        ( ACCFIFO_1_data_out                       ),
    .stk_full                       (              ),
    .stk_almost_full                (              ),
    .stk_half_full                  (              ),
    .stk_almost_empty               (              ),
    .stk_empty                      ( ACCFIFO_1_empty             ),
    .DataIn                         (  data_in     ),
    .write                          (  ACCFIFO_1_write                         ),
    .read                           ( ACCFIFO_1_read ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         )
);


endmodule