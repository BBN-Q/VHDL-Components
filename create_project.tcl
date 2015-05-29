###########################################################
# Tcl script to create the PolyphaseSSB Vivado project
#
# Usage: at the Tcl console set the PROJECT_DIR and PROJECT_NAME and
# then source this file. E.g.
#
# set PROJECT_DIR "/home/cryan/Programming/FPGA" or set PROJECT_DIR "C:/Users/qlab/Documents/Xilinx Projects/"
# set PROJECT_NAME "PolyphaseSSB"
# source create_project.tcl

############################################################

set SCRIPT_PATH [file normalize [info script]]
set REPO_PATH [file dirname $SCRIPT_PATH]

create_project -force $PROJECT_NAME $PROJECT_DIR/$PROJECT_NAME -part xc7a200tfbg676-2
set_property target_language VHDL [current_project]

# add VHDL and NGC sources
add_files -norecurse $REPO_PATH/ $REPO_PATH/src

#testbenches
add_files -norecurse -fileset sim_1 $REPO_PATH/test

# constraints
add_files -fileset constrs_1 -norecurse $REPO_PATH/constraints
set_property target_constrs_file $REPO_PATH/constraints/timing.xdc [current_fileset -constrset]

# ip cores
#First the regular ones
set ip_srcs [glob $REPO_PATH/ip/*.xci]
import_ip $ip_srcs

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

#Get headerless bit file output
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
