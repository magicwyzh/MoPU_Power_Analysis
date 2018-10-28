//contains the memory bank and  BPE encoder
module WBuffer_Bank #(parameter
	nb_taps = 11,
	weight_width = 16,
    activation_width = weight_width,
	ETC_width = 4,
	weight_bpr_width = ((weight_width+1)/2)*3,
	buffer_depth = 72,
	buffer_width = 16,
	buffer_addr_width = clogb2(buffer_depth)
)(
	output [nb_taps * weight_width - 1: 0] WRegs,
	output [nb_taps * weight_bpr_width - 1: 0] WBPRs,
	output [nb_taps * ETC_width - 1: 0] WETCs,
    output [activation_width-1: 0] last_pe_row_data_in,
	input [nb_taps-1: 0] weight_load_en,
	input clk, rst_n,
	input [buffer_addr_width-1: 0] wAddr, rAddr,
	input [buffer_width-1: 0] buffer_data_in,
	input buffer_wEn, buffer_rEn,
    input clear_all_wregs,
	input [4-1: 0] n_ap
);

logic [weight_bpr_width-1: 0] bpr;
logic [ETC_width-1: 0] etc;
logic [buffer_width-1: 0] buffer_data_out, weight;
assign last_pe_row_data_in = buffer_data_out;
assign weight = buffer_data_out;
BPEB_Enc_ETC U_BPEB_ENC_ETC_0(
    .in                             ( weight                            ),
    .n_ap                           ( n_ap                          ),
    .BPR                            ( bpr                           ),
    .ETC                            ( etc                           )
);

TS6N28HPCPHVTA72X16M2F ram(
	.AA(wAddr),
	.D(buffer_data_in),
	.WEB(buffer_wEn),
	.CLKW(clk),
	.AB(rAddr),
	.REB(buffer_rEn),
	.CLKR(clk),
	.Q(buffer_data_out)
);	
		
reg [weight_width-1: 0] WRegs_packed[nb_taps-1: 0];
reg [ETC_width-1: 0] WETCs_packed[nb_taps-1: 0];
reg [weight_bpr_width-1: 0] WBPRs_packed[nb_taps-1: 0];

integer i;
always@(posedge clk or negedge rst_n) begin
	if((!rst_n) || (clear_all_wregs)) begin
		for(i = 0; i < nb_taps; i = i + 1) begin
			WRegs_packed[i] <= 0;
			WETCs_packed[i] <= 0;
			WBPRs_packed[i] <= 0;
		end
	end
	else begin
		for(i = 0; i < nb_taps;i = i + 1 ) begin
			if(weight_load_en[i] == 1) begin
				WRegs_packed[i] <= weight;
				WETCs_packed[i] <= etc;
				WBPRs_packed[i] <= bpr;
			end
		end
	end
end
genvar t;
generate
for(t = 0; t < nb_taps; t = t + 1) begin
	assign WRegs[(t+1)*weight_width-1 -: weight_width] = WRegs_packed[t];
	assign WETCs[(t+1)*ETC_width-1 -: ETC_width] =  WETCs_packed[t];
	assign WBPRs[(t+1)*weight_bpr_width-1 -: weight_bpr_width] = WBPRs_packed[t];
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
