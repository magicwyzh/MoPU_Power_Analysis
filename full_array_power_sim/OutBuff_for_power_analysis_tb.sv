`timescale 1ns/1ns
module OutBuff_for_power_analysis_tb #(
    num_pe_row = 4,
    num_pe_col = 4,
    out_fr_array_width = 24,
    data_width_to_buff = 16,
    nb_data = 8192,
    addr_width = clogb2(nb_data)
)();
    logic [num_pe_row-1: 0][data_width_to_buff-1: 0] buff_data_out_even;
    logic [num_pe_row-1: 0][data_width_to_buff-1: 0] buff_data_out_odd;
    logic [num_pe_row-1: 0][data_width_to_buff-1: 0] buff_data_in_fr_dummy_ctrl_even;
    logic [num_pe_row-1: 0][data_width_to_buff-1: 0] buff_data_in_fr_dummy_ctrl_odd;
    logic [num_pe_row-1: 0] wEn_fr_dummy_ctrl_even_AH;//active high
    logic [num_pe_row-1: 0] wEn_fr_dummy_ctrl_odd_AH;//active high
    logic [num_pe_row-1: 0] rEn_fr_dummy_ctrl_even_AH;//active high
    logic [num_pe_row-1: 0] rEn_fr_dummy_ctrl_odd_AH;//active high
    logic [num_pe_row-1: 0][addr_width-1: 0] wAddr_fr_dummy_ctrl_even;
    logic [num_pe_row-1: 0][addr_width-1: 0] wAddr_fr_dummy_ctrl_odd;
    logic [num_pe_row-1: 0][addr_width-1: 0] rAddr_fr_dummy_ctrl_even;
    logic [num_pe_row-1: 0][addr_width-1: 0] rAddr_fr_dummy_ctrl_odd;

    logic [num_pe_row-1: 0][out_fr_array_width-1: 0] array_out_even_col;
    logic [num_pe_row-1: 0][out_fr_array_width-1: 0] array_out_odd_col;
    logic next_data_fr_array_valid; //active high
    logic ctrl_signal_sel; 
    logic clk;
    logic rst_n;
OutBuff_for_power_analysis #(.num_pe_row(num_pe_row))
DUT(
	.buff_data_out_even              (buff_data_out_even              ),
    .buff_data_out_odd               (buff_data_out_odd               ),
    .buff_data_in_fr_dummy_ctrl_even (buff_data_in_fr_dummy_ctrl_even ),
    .buff_data_in_fr_dummy_ctrl_odd  (buff_data_in_fr_dummy_ctrl_odd  ),
    .wEn_fr_dummy_ctrl_even_AH       (wEn_fr_dummy_ctrl_even_AH       ),
    .wEn_fr_dummy_ctrl_odd_AH        (wEn_fr_dummy_ctrl_odd_AH        ),
    .rEn_fr_dummy_ctrl_even_AH       (rEn_fr_dummy_ctrl_even_AH       ),
    .rEn_fr_dummy_ctrl_odd_AH        (rEn_fr_dummy_ctrl_odd_AH        ),
    .wAddr_fr_dummy_ctrl_even        (wAddr_fr_dummy_ctrl_even        ),
    .wAddr_fr_dummy_ctrl_odd         (wAddr_fr_dummy_ctrl_odd         ),
    .rAddr_fr_dummy_ctrl_even        (rAddr_fr_dummy_ctrl_even        ),
    .rAddr_fr_dummy_ctrl_odd         (rAddr_fr_dummy_ctrl_odd         ),
    .array_out_even_col              (array_out_even_col              ),
    .array_out_odd_col               (array_out_odd_col               ),
    .next_data_fr_array_valid        (next_data_fr_array_valid        ),
    .ctrl_signal_sel                 (ctrl_signal_sel                 ),
    .clk                             (clk                             ),
    .rst_n                           (rst_n                           )
);
initial begin
    clk = 0;
    forever begin
        #10; clk = ~clk;
    end
end

initial begin
    rst_n = 1;
    buff_data_in_fr_dummy_ctrl_even = 0;
    buff_data_in_fr_dummy_ctrl_odd = 0;
    wEn_fr_dummy_ctrl_even_AH = 0;
    wEn_fr_dummy_ctrl_odd_AH = 0;
    rEn_fr_dummy_ctrl_even_AH = 0;
    rEn_fr_dummy_ctrl_odd_AH = 0;
    wAddr_fr_dummy_ctrl_even = 0;
    wAddr_fr_dummy_ctrl_odd = 0;
    array_out_even_col = 0;
    array_out_odd_col = 0;
    ctrl_signal_sel = 0; // from dummy ctrl
	next_data_fr_array_valid = 0;
end

logic [13-1: 0] recorded_counter_val;
initial begin
    #5;
    rst_n = 0;
    #20
    rst_n = 1;
    @(posedge clk);
    rEn_fr_dummy_ctrl_even_AH = {num_pe_row{1'b1}};
    rEn_fr_dummy_ctrl_odd_AH = {num_pe_row{1'b1}};
    rAddr_fr_dummy_ctrl_even = 0;
    rAddr_fr_dummy_ctrl_odd = 0;
    @(posedge clk);
    rEn_fr_dummy_ctrl_even_AH = 0;
    rEn_fr_dummy_ctrl_odd_AH = 0;
	#1;
    if(!(buff_data_out_even[0] === 0 && buff_data_out_odd[0]  === 0)) begin
        $display("@%t, Error1!buff_data_out_even = %x, odd=%x", $time, buff_data_out_even[0] , buff_data_out_odd[0] );
        @(posedge clk);
        $stop;
    end
    rAddr_fr_dummy_ctrl_even[0] =1;
    rAddr_fr_dummy_ctrl_odd[0] = 1;
	wAddr_fr_dummy_ctrl_odd[0] = 1;
	wAddr_fr_dummy_ctrl_even[0] = 1;
    buff_data_in_fr_dummy_ctrl_even[0]  = 222;
    buff_data_in_fr_dummy_ctrl_odd[0]  = 333;
    wEn_fr_dummy_ctrl_even_AH[0] = 1;
    wEn_fr_dummy_ctrl_odd_AH[0] = 1;
    @(posedge clk);
    wEn_fr_dummy_ctrl_even_AH[0] = 0;
    wEn_fr_dummy_ctrl_odd_AH[0] = 0;
	rEn_fr_dummy_ctrl_odd_AH = 1;
	rEn_fr_dummy_ctrl_even_AH = 1;
	@(posedge clk);
	rEn_fr_dummy_ctrl_odd_AH = 0;
	rEn_fr_dummy_ctrl_even_AH = 0;
    #1;
    if(!(buff_data_out_even[0]  === 222 && buff_data_out_odd[0]  === 333)) begin
        $display("Error2!buff_data_out_even = %x, odd=%x", buff_data_out_even[0] , buff_data_out_odd[0] );
        @(posedge clk);
        $stop;
    end
	$stop;
    next_data_fr_array_valid = 1;
    ctrl_signal_sel = 1; // auto control
    recorded_counter_val = DUT.counter_value;
    @(posedge clk);
    next_data_fr_array_valid = 0;
    array_out_even_col[0]  = 777;
    array_out_odd_col[0]  = 888;
	#1;
    while(DUT.counter_value != recorded_counter_val) begin
        @(posedge clk);
        #1;
    end
    next_data_fr_array_valid = 1;
    @(posedge clk);
    next_data_fr_array_valid = 0;
	#1;
    if(!(buff_data_out_even[0]  === 777 && buff_data_out_odd[0]  === 888)) begin
        $display("Error3!buff_data_out_even = %x, odd=%x", buff_data_out_even[0] , buff_data_out_odd[0] );
        @(posedge clk);
        $stop;
    end
    $finish;
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
