module OutBuff_Bank #(
    out_fr_array_width = 24,
    data_width_to_buff = 16,
    nb_data = 8192,
    addr_width = clogb2(nb_data)
)(
    output [data_width_to_buff-1: 0] buff_data_out,
    input [data_width_to_buff-1: 0] buff_data_in_fr_dummy_ctrl,
    input wEn_fr_dummy_ctrl, //active low
    input rEn_fr_dummy_ctrl, //active low
    input [addr_width-1: 0] wAddr_fr_dummy_ctrl, 
    input [addr_width-1: 0] rAddr_fr_dummy_ctrl, 

    input [addr_width-1: 0] wAddr_fr_array, 
    input [addr_width-1: 0] rAddr_fr_array, 
    input [out_fr_array_width-1: 0] out_fr_array,
    input next_data_fr_array_valid, //use this to automatically generate enable signals
    input ctrl_signal_sel, //0 is from dummy, 1 is auto-generated from the array for power simulation
    input clk, rst_n
);
logic [data_width_to_buff-1: 0] buff_data_in;
logic buff_wEn, buff_rEn;
logic [addr_width-1: 0] buff_wAddr, buff_rAddr;
SRAM_8192x16bits u_SRAM_8192x16bits(
	.rData ( buff_data_out ),
    .wData ( buff_data_in  ),
    .clk   (clk   ),
    .wEn   ( buff_wEn   ),
    .rEn   ( buff_rEn   ),
    .wAddr ( buff_wAddr ),
    .rAddr ( buff_rAddr )
);
logic rEn_gen, wEn_gen; //generated enable signal
assign rEn_gen = ~next_data_fr_array_valid; //change to active low
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        wEn_gen <= 1;//because wEn is active low
    end
    else begin
        wEn_gen <= rEn_gen;
    end
end

logic [out_fr_array_width: 0] adder_out;
logic [data_width_to_buff-1: 0] adder_out_saturated;
assign adder_out = $signed(buff_data_out) + $signed(out_fr_array); // their width are not compatible..but dont care..

saturate #(
    .L_datain              ( out_fr_array_width+1                            ),
    .L_dataout                      ( data_width_to_buff                            ))
U_SATURATE_0(
    .in                       ( adder_out                     ),
    .out                      ( adder_out_saturated                  )
);
logic ctrl_fr_dummy;
assign ctrl_fr_dummy = ctrl_signal_sel == 0;
assign buff_data_in = ctrl_fr_dummy? buff_data_in_fr_dummy_ctrl : adder_out_saturated;
assign buff_wEn = ctrl_fr_dummy ? wEn_fr_dummy_ctrl : wEn_gen;
assign buff_rEn = ctrl_fr_dummy ? rEn_fr_dummy_ctrl : rEn_gen;
assign buff_wAddr = ctrl_fr_dummy ? wAddr_fr_dummy_ctrl : wAddr_fr_array;
assign buff_rAddr = ctrl_fr_dummy ? rAddr_fr_dummy_ctrl : rAddr_fr_array;


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