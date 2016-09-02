#find all the synchronizer modules
set synchronizers [get_cells -hier -filter {(ORIG_REF_NAME == synchronizer) || (REF_NAME == synchronizer)}]

foreach sync $synchronizers {
	# false path to asynchronous preset or clear on all flip-flops in chain
	# synchronizer in generate loop might have [idx] brackets to specify loop index
	# which need to be escaped for regexp
	set reset_pins_pattern [string map {[ \\[ ] \\]} $sync/sync_chain_reg\[\\d\]/(PRE|CLR)]
	set reset_pins [get_pins -regexp $reset_pins_pattern]
	# if reset is a constant then there will be no PRE/CLR pins
	if { [llength $reset_pins] > 0 } {
		set_false_path -to $reset_pins
	}

	# false path to first flip-flop data pin
	set_false_path -to [get_pins $sync/sync_chain_reg[0]/D]
	# max delay to maximize metastability settle time (assumes two flip-flops)
	set_max_delay -from [get_cells $sync/sync_chain_reg[0]] -to [get_cells $sync/sync_chain_reg[1]] 2
}
