#find all the synchronizer modules
set synchronizers [get_cells -hier -filter {(ORIG_REF_NAME == synchronizer) || (REF_NAME == synchronizer)}]

foreach sync $synchronizers {
	# false path to asynchronous preset or clear on all flip-flops in chain
	# synchronizer in generate loop might have [idx] brackets to specify loop index
	# which need to be escaped for regexp
	set pattern [string map {[ \\[ ] \\]} $sync/sync_chain_reg\[\\d\]/(PRE|CLR)]
	set_false_path -to [get_pins -regexp $pattern]
	# false path to first flip-flop data pin
	set_false_path -to [get_pins $sync/sync_chain_reg[0]/D]
	# max delay to maximize metastability settle time (assumes two flip-flops)
	set_max_delay -from [get_cells $sync/sync_chain_reg[0]] -to [get_cells $sync/sync_chain_reg[1]] 2
}
