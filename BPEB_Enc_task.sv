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


