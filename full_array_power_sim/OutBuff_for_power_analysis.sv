module OutBuff_for_power_analysis #(
    num_pe_row = 16,
    //num_pe_col = 16,
    out_fr_array_width = 24,
    data_width_to_buff = 16,
    nb_data = 8192,
    addr_width = clogb2(nb_data)
)(  
    // double out buffer, so divided into even and odd part
    output [num_pe_row-1: 0][data_width_to_buff-1: 0] buff_data_out_even,
    output [num_pe_row-1: 0][data_width_to_buff-1: 0] buff_data_out_odd,
    input [num_pe_row-1: 0][data_width_to_buff-1: 0] buff_data_in_fr_dummy_ctrl_even,
    input [num_pe_row-1: 0][data_width_to_buff-1: 0] buff_data_in_fr_dummy_ctrl_odd,
    input [num_pe_row-1: 0] wEn_fr_dummy_ctrl_even_AH,//active high
    input [num_pe_row-1: 0] wEn_fr_dummy_ctrl_odd_AH,//active high
    input [num_pe_row-1: 0] rEn_fr_dummy_ctrl_even_AH,//active high
    input [num_pe_row-1: 0] rEn_fr_dummy_ctrl_odd_AH,//active high
    input [num_pe_row-1: 0][addr_width-1: 0] wAddr_fr_dummy_ctrl_even,
    input [num_pe_row-1: 0][addr_width-1: 0] wAddr_fr_dummy_ctrl_odd,
    input [num_pe_row-1: 0][addr_width-1: 0] rAddr_fr_dummy_ctrl_even,
    input [num_pe_row-1: 0][addr_width-1: 0] rAddr_fr_dummy_ctrl_odd,

    input [num_pe_row-1: 0][out_fr_array_width-1: 0] array_out_even_col,
    input [num_pe_row-1: 0][out_fr_array_width-1: 0] array_out_odd_col,
    input next_data_fr_array_valid, //active high
    input ctrl_signal_sel, 
    input clk,
    input rst_n
);
// convert active high to active low
logic [num_pe_row-1: 0] wEn_fr_dummy_ctrl_even;
logic [num_pe_row-1: 0] wEn_fr_dummy_ctrl_odd;
logic [num_pe_row-1: 0] rEn_fr_dummy_ctrl_even;
logic [num_pe_row-1: 0] rEn_fr_dummy_ctrl_odd;
assign wEn_fr_dummy_ctrl_even = ~wEn_fr_dummy_ctrl_even_AH;
assign rEn_fr_dummy_ctrl_even = ~rEn_fr_dummy_ctrl_even_AH;
assign wEn_fr_dummy_ctrl_odd = ~wEn_fr_dummy_ctrl_odd_AH;
assign rEn_fr_dummy_ctrl_odd = ~rEn_fr_dummy_ctrl_odd_AH;
// The counter and the generated random address.
logic [13-1: 0] counter_value, delayed_counter_value;
counter8K u_counter8K(
	.clk   (clk   ),
    .rst_n (rst_n ),
    .value (counter_value )
);
always@(posedge clk) begin
    if(!rst_n) begin
        delayed_counter_value <= 0;
    end
    else begin
        delayed_counter_value <= counter_value;
    end
end

/******** Instance of OutBuffBank******/
genvar gen_r;

generate
for(gen_r = 0; gen_r < num_pe_row; gen_r++) begin
    OutBuff_Bank u_OutBuff_Bank_Even(
    	.buff_data_out              (buff_data_out_even[gen_r]              ),
        .buff_data_in_fr_dummy_ctrl (buff_data_in_fr_dummy_ctrl_even[gen_r] ),
        .wEn_fr_dummy_ctrl          (wEn_fr_dummy_ctrl_even[gen_r]          ),
        .rEn_fr_dummy_ctrl          (rEn_fr_dummy_ctrl_even[gen_r]          ),
        .wAddr_fr_dummy_ctrl        (wAddr_fr_dummy_ctrl_even[gen_r]        ),
        .rAddr_fr_dummy_ctrl        (rAddr_fr_dummy_ctrl_even[gen_r]        ),
        .wAddr_fr_array             (delayed_counter_value             ),
        .rAddr_fr_array             (counter_value             ),
        .out_fr_array               (array_out_even_col[gen_r]               ),
        .next_data_fr_array_valid   (next_data_fr_array_valid   ),
        .ctrl_signal_sel            (ctrl_signal_sel            ),
        .clk                        (clk                        ),
        .rst_n                      (rst_n                      )
    );
    OutBuff_Bank u_OutBuff_Bank_Odd(
    	.buff_data_out              (buff_data_out_odd[gen_r]              ),
        .buff_data_in_fr_dummy_ctrl (buff_data_in_fr_dummy_ctrl_odd[gen_r] ),
        .wEn_fr_dummy_ctrl          (wEn_fr_dummy_ctrl_odd[gen_r]          ),
        .rEn_fr_dummy_ctrl          (rEn_fr_dummy_ctrl_odd[gen_r]          ),
        .wAddr_fr_dummy_ctrl        (wAddr_fr_dummy_ctrl_odd[gen_r]        ),
        .rAddr_fr_dummy_ctrl        (rAddr_fr_dummy_ctrl_odd[gen_r]        ),
        .wAddr_fr_array             (delayed_counter_value             ),
        .rAddr_fr_array             (counter_value             ),
        .out_fr_array               (array_out_odd_col[gen_r]               ),
        .next_data_fr_array_valid   (next_data_fr_array_valid   ),
        .ctrl_signal_sel            (ctrl_signal_sel            ),
        .clk                        (clk                        ),
        .rst_n                      (rst_n                      )
    );
end
endgenerate


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
