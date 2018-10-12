
task automatic FoFIR_update_one_time_task(
	input [activation_width-1: 0] act_value,
	input is_zero_act,
	input [weight_width*nb_taps-1: 0] WRegs,
	input [4-1: 0] n_ap,
	input [5-1: 0] quantized_bits,
	//input [width_current_tap-1: 0] PD0,
	input int kernel_size,
	input is_MDecomp,
    input AW_Decomp,
    
);
begin
	reg [ETC_width-1: 0] WETCs[nb_taps];
	reg [ETC_width-1: 0] ETC_A;
	reg [act_bpr_width-1: 0] BPR_A;
	reg [weight_bpr_width-1: 0] WBPRs[nb_taps];
	reg first_tap;
	int wetc_sum;
	int nb_effective_tap;
	reg [width_current_tap-1: 0] next_tap;
	int nb_zero_act;
	int nb_zero_cycle;
	reg [weight_bpr_width-1:0] BPR_for_PAMAC_ctrl;
	
	valid_result_trig = 0;
	wetc_sum = 0;
	//init the control signal
	DRegs_en = 0;
	DRegs_clr = 0;
	DRegs_in_sel = 0;
	index_update_en = 0;
	out_mux_sel = 0;
	out_reg_en = 0;

	for(int i=0; i < nb_taps; i++) begin
		BPEB_Enc_task(WRegs[(i+1)*weight_width-1 -: weight_width], n_ap, WBPRs[i], WETCs[i]);
		//$display("In ctrl function, Weights = 0x%x, WBPRs = 0x%x, WTCs=0x%x",WRegs[(i+1)*weight_width-1 -: weight_width], WBPRs[i], WETCs[i]);
	end
	//deal with all zero taps
	for(int i=0; i< nb_taps; i++) begin
		wetc_sum += WETCs[i];
	end
	if(wetc_sum == 0) begin
		$display("All taps are ineffective!");
		out_mux_sel = 1;
		current_tap = 0;
		out_reg_en = 1;
		@(posedge clk);
		out_mux_sel = 0;
		out_reg_en = 0;
		return;
	end
	
	//The ETC may be zero when n_ap > 0
	BPEB_Enc_task(act_value, n_ap, BPR_A, ETC_A);


	if(is_zero_act === 0 && ETC_A > 0) begin
		//an effective value
		
		//Make a queue to store the effective taps
		automatic int  effective_tap_index[$] = {};//use a queue to store the effective taps
		for(int tap_idx = nb_taps-1; tap_idx >=0; tap_idx--) begin
			if(WETCs[tap_idx] > 0) begin
				effective_tap_index.push_back(tap_idx);
				nb_effective_tap += 1;
			end
		end
		#1;//wait for PD0
		foreach(effective_tap_index[i]) begin
			//i == 0 indicates the first non-zero tap, that should be output
			current_tap = effective_tap_index[i];
			if(is_MDecomp === 1) begin
				BPR_for_PAMAC_ctrl = ETC_A > WETCs[current_tap] ? WBPRs[current_tap]: BPR_A;
			end
			else if(is_MDecomp === 0 && AW_Decomp === 1) begin
				//weight decomp
				BPR_for_PAMAC_ctrl = WBPRs[current_tap];
			end
			else if(is_MDecomp ===0 && AW_Decomp ===0) begin
				BPR_for_PAMAC_ctrl = BPR_A;
			end
			else begin
				$display("Error! non of MDecomp,AWDecomp is used!");
				$stop;
			end
			//compute
			PAMAC_compute_ctrl_task_new(BPR_for_PAMAC_ctrl, quantized_bits, n_ap);
			//now the results is in the out port of PAMAC
			out_reg_en = i == 0 ? 1 : 0;//if the first tap, save to output reg
			out_mux_sel = 0;
			//save the results to the right register, only if it has right
			//register
			DRegs_en = 0;
			if((current_tap + 1 < nb_taps) && (current_tap+1 <kernel_size) && i != 0) begin
				DRegs_en[(PD0+current_tap+1)%nb_taps] = 1;
				DRegs_in_sel[(current_tap+PD0+1)%nb_taps] = 1;//update by the PAMAC output
			end
			//the left registers of the current taps should update in the same
			//cycle
			if(i == nb_effective_tap -1) begin
				//the last effective tap, left of it should all be updated
				//with zero
				for(int t=0; t <= current_tap; t++) begin
					DRegs_clr[(t+PD0)%nb_taps] = 1;
				end
			end
			else begin
				next_tap = effective_tap_index[i+1];//have a peep for the next tap
				for(int t=next_tap+1; t <= current_tap; t++) begin
					DRegs_en[(PD0+t)%nb_taps] = DRegs_clr[(t+PD0)%nb_taps] == 1 ? 0 : 1;
					DRegs_in_sel[(PD0+t)%nb_taps] = 0;//updated by the left
				end
			end
			if(i == (nb_effective_tap -1)) 
				valid_result_trig = 1;
			else 
				valid_result_trig = 0;
			@(posedge clk);
			out_reg_en = 0;
			DRegs_in_sel = 0;
			DRegs_clr = 0;
			DRegs_en = 0;
		end

	end
	else if(is_zero_act === 1 || ETC_A == 0) begin
		//a zero activation input, the act_value is of no use
		out_mux_sel = 1;
		out_reg_en = 1;
		nb_zero_act = is_zero_act ? act_value : 1;//this zero act may from zero ETC by approximate computing
		nb_zero_cycle = nb_zero_act >= kernel_size ? kernel_size : nb_zero_act;
		if(nb_zero_cycle == kernel_size) begin
			for(int i=kernel_size-1;i >= 0; i--) begin
				current_tap = i;
				valid_result_trig = 1;
				DRegs_clr = i == 0 ? {nb_taps{1'b1}} : 0;//clear all regs after the last cycle
				@(posedge clk);
			end
		end
		else begin
			//less than kernel_size zeros
			for(int i = 0;i<nb_zero_cycle;i++) begin
				index_update_en = 1;
				current_tap = kernel_size - 1;//output the righest register, but should according to the kernel size, otherwise, it equals a FIR filter with multiple delay element in the output if the n_tap > kernel size
				//DRegs_en = {nb_taps{1'b1}};//shift is not required
				DRegs_en = 0;
				//DRegs_en[PD0] = 0;//the D0 should be cleared
				DRegs_in_sel = 0;//from left registers
				#1;//wait for the PD0 update
				DRegs_clr = 0;
				DRegs_clr[(PD0+kernel_size-1)%nb_taps] = 1;
				valid_result_trig = 1;
				@(posedge clk);
			end
		end
		
	end
	else begin
		$display("error! is_zero_act is not 1 or 0");
	end
	DRegs_clr = 0;
	DRegs_en = 0;
	index_update_en = 0;
	out_reg_en = 0;
	out_mux_sel = 0;
	valid_result_trig = 0;

end
endtask