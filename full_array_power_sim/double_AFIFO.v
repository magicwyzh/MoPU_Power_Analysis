// double buffered AFIFO
// the one that is not used for read when computing in FoFIR is called the "shadow fifo", another one
// is called "compute fifo"
// it also output a "delayed_compute_AFIFO_read" signal which can be used to connect to the 
// "shadow_AFIFO_write" signal in the upper pe.
module double_AFIFO #(parameter 
    nb_data = 8, 
    data_width = 17,
    SRAM_IMPL = 0
)(
    input [data_width-1: 0] shadow_AFIFO_data_in,
    input [data_width-1: 0] compute_AFIFO_data_in,
    input shadow_AFIFO_write,
    input compute_AFIFO_read,
    input compute_AFIFO_write,
    output reg delayed_compute_AFIFO_read,
    output compute_AFIFO_full,
    output compute_AFIFO_empty,
    output [data_width-1: 0] compute_AFIFO_data_out,

    input which_AFIFO_for_compute,
    input compute_AFIFO_read_delay_enable,
    input clk,
    input rst_n
);

wire [data_width-1: 0] fifo_0_data_out;
wire [data_width-1: 0] fifo_0_data_in;
wire [data_width-1: 0] fifo_1_data_in;
wire [data_width-1: 0] fifo_1_data_out;
wire fifo_0_empty, fifo_0_full, fifo_0_write, fifo_0_read;
wire fifo_1_empty, fifo_1_full, fifo_1_write, fifo_1_read;
//delay for one cycle
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        delayed_compute_AFIFO_read <= 0;
    end
    else if(compute_AFIFO_read_delay_enable) begin
        delayed_compute_AFIFO_read <= compute_AFIFO_read;
    end
    else begin
        delayed_compute_AFIFO_read <= delayed_compute_AFIFO_read;
    end
end

assign compute_AFIFO_full = which_AFIFO_for_compute==0? fifo_0_full : fifo_1_full;
assign compute_AFIFO_empty = which_AFIFO_for_compute == 0 ? fifo_0_empty : fifo_1_empty;
assign compute_AFIFO_data_out = which_AFIFO_for_compute == 0? fifo_0_data_out : fifo_1_data_out;
assign fifo_0_write = which_AFIFO_for_compute == 0 ? compute_AFIFO_write : shadow_AFIFO_write;
assign fifo_1_write = which_AFIFO_for_compute == 0 ?  shadow_AFIFO_write : compute_AFIFO_write;
assign fifo_0_read = which_AFIFO_for_compute == 0 ? compute_AFIFO_read : 0;
assign fifo_1_read = which_AFIFO_for_compute == 0 ?  0 : compute_AFIFO_read;
assign fifo_0_data_in = which_AFIFO_for_compute == 0? compute_AFIFO_data_in : shadow_AFIFO_data_in;
assign fifo_1_data_in = which_AFIFO_for_compute == 0 ? shadow_AFIFO_data_in : compute_AFIFO_data_in;


FIFO #(
    .nb_data               ( nb_data                            ),
    .L_data                         ( data_width                            ),
    .SRAM_IMPL                      ( SRAM_IMPL                             ))
AFIFO_0(
    .DataOut                        ( fifo_0_data_out                       ),
    .stk_full                       ( fifo_0_full             ),
    .stk_almost_full                (              ),
    .stk_half_full                  (              ),
    .stk_almost_empty               (              ),
    .stk_empty                      ( fifo_0_empty            ),
    .DataIn                         (  fifo_0_data_in     ),
    .write                          (  fifo_0_write                         ),
    .read                           ( fifo_0_read ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         )
);
FIFO #(
    .nb_data               ( nb_data                            ),
    .L_data                         ( data_width                            ),
    .SRAM_IMPL                      ( SRAM_IMPL                             ))
AFIFO_1(
    .DataOut                        ( fifo_1_data_out                       ),
    .stk_full                       ( fifo_1_full             ),
    .stk_almost_full                (              ),
    .stk_half_full                  (              ),
    .stk_almost_empty               (              ),
    .stk_empty                      ( fifo_1_empty            ),
    .DataIn                         (  fifo_1_data_in     ),
    .write                          (  fifo_1_write                         ),
    .read                           ( fifo_1_read ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         )
);




endmodule