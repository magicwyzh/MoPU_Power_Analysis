module actQueueCtrl (
	output write_to_stk,
	output read_fr_stk,
	input write,read,stk_full,stk_empty
);

assign write_to_stk = write && (!stk_full);
assign read_fr_stk = read && (!stk_empty);

endmodule
