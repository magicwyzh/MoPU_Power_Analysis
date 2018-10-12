`timescale 1ns/1ns
module SinglePEScheduler #(parameter
    AFIFO_size = 8,
    ACCFIFO_size = 32,
    nb_taps = 11,
	activation_width = 16,
	compressed_act_width = activation_width + 1,
	weight_width = 16,
	tap_width = 24,
	weight_bpr_width = ((weight_width+1)/2)*3,
	act_bpr_width = ((activation_width+1)/2)*3,
	ETC_width = 4,
	width_current_tap = nb_taps > 8 ? 4 : 3
    )(
        /**** Ports to control the PE *****/
        // control ports for PAMAC
            output logic [3-1: 0] PAMAC_BPEB_sel,
            output logic  PAMAC_DFF_en,
            output logic  PAMAC_first_cycle,
            input logic  PAMAC_MDecomp,
            input logic  PAMAC_AWDecomp,
        // control ports for FoFIR
            output logic [width_current_tap-1: 0] current_tap,
            output logic [nb_taps-1: 0] DRegs_en,
            output logic [nb_taps-1: 0] DRegs_clr,
            output logic [nb_taps-1: 0] DRegs_in_sel,
            output logic  index_update_en,
            output logic  out_mux_sel,
            output logic  out_reg_en,
        // control ports for FIFOs
            output logic  AFIFO_read, 
            output logic  ACCFIFO_write,
            output logic  ACCFIFO_read,
            output logic  add_zero,
            output logic feed_zero_to_accfifo,
            output logic accfifo_head_to_tail,
        /**** End of Ports to control the PE array***/

        /**** Ports from PE for some info ****/
            input [width_current_tap-1: 0] PD0,
            input AFIFO_empty,
            input [compressed_act_width-1: 0] afifo_out,

        /**** Ports for some weights info*******/
            input [weight_width*nb_taps-1: 0] WRegs_packed,
            input [weight_bpr_width*nb_taps-1: 0] WBPRs_packed,
            input [ETC_width*nb_taps-1: 0] WETCs_packed,
        /***** End of ports for weights info****/

        /****some layer info***************/
            input int kernel_size, 
            input int quantized_bits, 
            input [4-1:0] n_ap,
        /****End of layer info***************/

        /**** ports with array scheduler*****/
            input act_feed_done, 
            input start,
            output logic this_pe_done,
            input first_acc_flag, 
            input clr_pe_scheduler_done,
        /**** end of ports with array scheduler****/
        
        /**** Misc ports***************/
            input clk
    );
/***** Main control in a PE scheduler *************/
logic finish_condition;
assign finish_condition = AFIFO_empty && act_feed_done;
always@(posedge start) begin
    ACCFIFO_write = 0;
    AFIFO_read = 0;
    ACCFIFO_read = 0;
    #1;
    while(!finish_condition) begin
        if(!AFIFO_empty) begin
			AFIFO_read = 1;
            @(posedge clk);
			ACCFIFO_write = 0;
            AFIFO_read = 0;
            #1;
            fork
                FoFIR_update_one_time_task(
					afifo_out[activation_width-1: 0],
					afifo_out[compressed_act_width-1],
					WRegs_packed,
					n_ap,
					quantized_bits,
					kernel_size,
					PAMAC_MDecomp,
					PAMAC_AWDecomp
				);
				// read ACCFIFO when valid_result_trig = 1, then write accumulated result to ACCFIFO
				// the ACCFIFO_write should be set to zero one cycle after this task call.
				ACCFIFO_ctrl_process_when_computing();
			join
        end
        else begin
            @(posedge clk); 
			ACCFIFO_write = 0;
        end
        #1; // delay for obtaining the value of finish_condition
	end
	@(posedge clk);
    ACCFIFO_write = 0;
    AFIFO_read = 0;
    ACCFIFO_read = 0;
    this_pe_done = 1;
end
/** Clear it**/
always@(posedge clr_pe_scheduler_done) begin
    this_pe_done = 0;
end

/****** End of Main control in a PE scheduler*****/

/****** Some signals for easy debugging**********/
logic valid_result, valid_result_trig;
always@(posedge clk) begin
	if(valid_result_trig) begin
		valid_result <= 1;
	end
	else begin
		valid_result <= 0;
	end
end
/****** End of easy debugging signals************/


/**************** Tasks for control a PE to convolve a row and accumulate*************/
task automatic FoFIR_update_one_time_task(
	input [activation_width-1: 0] act_value,
	input is_zero_act,
	input [weight_width*nb_taps-1: 0] WRegs,
	input [4-1: 0] n_ap,
	input [5-1: 0] quantized_bits,
	//input [width_current_tap-1: 0] PD0,
	input int kernel_size,
	input is_MDecomp,
	input AW_Decomp
);
begin
	logic [ETC_width-1: 0] WETCs[nb_taps];
	logic [ETC_width-1: 0] ETC_A;
	logic [act_bpr_width-1: 0] BPR_A;
	logic [weight_bpr_width-1: 0] WBPRs[nb_taps];
	logic first_tap;
	int wetc_sum;
	int nb_effective_tap;
	logic [width_current_tap-1: 0] next_tap;
	int nb_zero_act;
	int nb_zero_cycle;
	logic [weight_bpr_width-1:0] BPR_for_PAMAC_ctrl;
	
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
		$display("In module %m, All taps are ineffective!");
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
				$display("Error! In module %m, non of MDecomp,AWDecomp is used!");
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
		$display("Error! In module %m, is_zero_act is not 1 or 0");
	end
	DRegs_clr = 0;
	DRegs_en = 0;
	index_update_en = 0;
	out_reg_en = 0;
	out_mux_sel = 0;
	valid_result_trig = 0;

end
endtask

task BPEB_Enc_task(
	input [16-1: 0] in,
	input [4-1: 0] n_ap,
	output [8*3-1: 0] encoded_result,
	output [4-1: 0] ETC
); 
begin
	for(int i = 0; i < 8; i++ ) begin
		if(i >= n_ap) begin
			encoded_result[3*i+1] = in[2*i];
			encoded_result[3*i+2] = in[2*i+1];
			encoded_result[3*i] = i==0 ? 0 : in[2*i-1];
		end
		else begin
			//abandoned terms
			encoded_result[3*i+2 -: 3] = 3'b000;
		end
	end

	ETC = 0;
	for(int t=0; t < 8; t++) begin
		if(encoded_result[3*(t+1)-1 -: 3] != 3'b000 && encoded_result[3*(t+1)-1 -: 3] != 3'b111) begin
			ETC += 1;
		end
	end
end
endtask

task automatic ACCFIFO_ctrl_process_when_computing();
	logic zero_more_than_kernel_size;
	int diff;
	int temp;
	//the caller of this task have already #1 to make the afifo_out data be the true data in that cycle
	if(afifo_out[compressed_act_width-1] == 0) begin
		#1;
		while(!valid_result_trig) begin
			@(posedge clk);
			#1;
		end
		ACCFIFO_read = first_acc_flag ? 0:1;
		@(posedge clk);
		// put head_to_tail/feed_zero_to_accfifo here to ensure correct data goto the accfifo
		accfifo_head_to_tail = 0;
		feed_zero_to_accfifo = 0;
		add_zero = first_acc_flag ? 1:0;
		ACCFIFO_read = 0;
		ACCFIFO_write = 1;
		// the ACCFIFO_write should be 0 in the next cycle, but put this part in the caller of this task
	end
	else begin
		//zero activation
		zero_more_than_kernel_size = afifo_out[activation_width-1-1: 0] > (kernel_size - 1);
		temp = zero_more_than_kernel_size ? (kernel_size - 1) : afifo_out[activation_width-1-1:0];
		for(int tt = 0; tt<temp; tt++) begin
			#1;
			if(valid_result_trig) begin
				ACCFIFO_read = first_acc_flag ? 0:1;
				add_zero = first_acc_flag ? 1: 0;
			end
			else begin
				ACCFIFO_read = first_acc_flag ? 0 : 1;
				add_zero = first_acc_flag ? 1:0;
				$display("In Module %m, @%t, the valid trig should be 1 but not meet", $time);
				@(posedge clk);
				$stop;
			end
			@(posedge clk);
			accfifo_head_to_tail = 0;
			feed_zero_to_accfifo = 0;
			ACCFIFO_write = 1;
		end
		ACCFIFO_read = 0;
		if(zero_more_than_kernel_size) begin
			diff = afifo_out[activation_width-1-1: 0] - kernel_size + 1;
			if(diff <= 0) return;//error state
			// need to put head to tail
			for(int m = 0; m < diff; m++) begin
				if(!first_acc_flag) begin
					ACCFIFO_read = 1;
				end
				else begin
					ACCFIFO_read = 0;
				end
				@(posedge clk);
				ACCFIFO_write = 1;
				if(!first_acc_flag) begin
					accfifo_head_to_tail = 1;
                    feed_zero_to_accfifo = 0;
				end
				else begin
					accfifo_head_to_tail = 0;
                    feed_zero_to_accfifo = 1;
				end
			end
		end
	end
	ACCFIFO_read = 0;
	//accfifo_head_to_tail = 0; this is set at the beginning of this task, dont touch it here
	//feed_zero_to_accfifo = 0; this is set at the beginning of this task, dont touch it here
	//dont touch ACCFIFO_write here, it should be reset to 0 outside of this task after one cycle.
endtask

task automatic ACCFIFO_pre_read_when_computing();
    begin
        logic zero_more_than_kernel_size;
		int diff;
		int temp;
        //ACCFIFO_read = 1;//because the first time need not to read
        if(afifo_out[compressed_act_width-1] == 0) begin
            //not a zero act
            ACCFIFO_read = first_acc_flag ? 0:1;
            @(posedge clk);
            ACCFIFO_read = 0;
        end
        else begin
            //zero activation
            temp = afifo_out[activation_width-1-1: 0] < kernel_size ?
                afifo_out[activation_width-1-1: 0] : kernel_size;
            zero_more_than_kernel_size = afifo_out[activation_width-1-1: 0] > kernel_size;
            for(int tt = 0; tt<temp;tt++) begin//
                #1;
                if(valid_result_trig == 1) begin
                    ACCFIFO_read = first_acc_flag ? 0 : 1;
                    add_zero = first_acc_flag ? 1:0;
                end
                else begin
                    ACCFIFO_read = first_acc_flag ? 0 : 1;
                    add_zero = first_acc_flag ? 1:0;
                    $display("In Module %m, @%t, the valid trig should be 1 but not meet", $time);
                end
                @(posedge clk);
                ACCFIFO_write = 1;
            end
            if(zero_more_than_kernel_size && !first_acc_flag) begin
                // need to put head to tail
                ACCFIFO_read = 1;
            end
            @(posedge clk);
            ACCFIFO_read = 0;
            ACCFIFO_write = 0;
            // add some more cycles feeding zero to the ACCFIFO or feed head to tail if so many zeros
            // but in real implementation, the ACCFIFO can just use SRAM to implement
            // and those zero are not required to be fed in
            if(zero_more_than_kernel_size) begin
                diff = afifo_out[activation_width-1-1: 0] - kernel_size;
                for(int tt = 0; tt < diff; tt++) begin
                    if(first_acc_flag) begin
                        feed_zero_to_accfifo = 1;
                        accfifo_head_to_tail = 0;
                        ACCFIFO_write = 1;
                        @(posedge clk);
                        #1;
                    end
                    else begin
                        feed_zero_to_accfifo = 0;
                        accfifo_head_to_tail = 1;
                        ACCFIFO_read = (tt < (diff - 1)) ? 1 : 0;
                        ACCFIFO_write = 1;
                        @(posedge clk);
                        #1;
                    end
                end
            end
        end
        ACCFIFO_read = 0;
        ACCFIFO_write = 0;
    end
    endtask

	task PAMAC_compute_ctrl_task_new(
		input [8*3-1: 0] BPR,
		input [5-1: 0] quantized_bits,
		input [4-1: 0]n_ap
	);
	begin
		int t;
		int n_ap_int;
		reg unsigned [4-1:0] i;
		reg unsigned [4-1: 0] half_n;
		reg V[8];
		int ETC;
		int last_essential_term_idx;
		last_essential_term_idx = -1;
		i = 0;
		//finish = 0;
		n_ap_int = n_ap;
		//initialize
		PAMAC_DFF_en = 0;
		PAMAC_BPEB_sel = 0;
		half_n = (quantized_bits + 1)/2;
		for(i = 0; i< 8; i++) begin
			V[i] = 0;
		end
		//value encoding
		for(i=0; i < half_n; i=i+1) begin
			case(BPR[3*(i+1)-1 -: 3])
				3'b000, 3'b111:begin
					V[i] = 0;
				end
				default:begin
					//this module dont care whether Vi is 1 or 2 or -1 or -2, 
					//so uniformly represent as 1
					V[i] = 1;
					if(last_essential_term_idx == -1 && i >= n_ap_int) begin
						last_essential_term_idx = i;
					end
				end
			endcase
			if(i<n_ap_int) begin
				V[i] = 0;
			end
		end
		ETC = 0;
		for(i = 0; i < half_n; i++) begin
			if(V[i] == 1) begin
				ETC = ETC +  1;
			end
		end
		//start multi-cycle-computation
		PAMAC_first_cycle = 1;
		for(t = half_n-1; t >= 0; t--) begin
			if(V[t] == 1) begin
				PAMAC_DFF_en = 1;
				PAMAC_BPEB_sel = t;
				if(t > last_essential_term_idx) begin
					@(posedge clk);	//wait for the posedge except for the last cycle
					PAMAC_first_cycle = 0;
				end
			end
			else begin
				;
			end
		end
		PAMAC_first_cycle = ETC==1 ? 1 : 0;
		PAMAC_DFF_en = 0;
	
	end
	endtask
/********Init the signals to zero**********************/
    initial begin
        {PAMAC_BPEB_sel, PAMAC_DFF_en, PAMAC_first_cycle} = 0;
        {current_tap, DRegs_en, DRegs_clr, DRegs_in_sel, index_update_en, out_mux_sel, out_reg_en} = 0;
        {AFIFO_read, ACCFIFO_read,ACCFIFO_write, add_zero, feed_zero_to_accfifo, accfifo_head_to_tail} = 0;
        this_pe_done = 0;
    end
endmodule