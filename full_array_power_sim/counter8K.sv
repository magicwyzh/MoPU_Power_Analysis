module counter8K (
    input clk,
    input rst_n,
    output [13-1: 0] value
);
logic [13-1: 0] counter;
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter <= 0;
    end
    else begin
        counter <= counter + 1;
    end
end
assign value = counter;
endmodule