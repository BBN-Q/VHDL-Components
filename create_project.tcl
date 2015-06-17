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

set REPO_PATH [file dirname [file normalize [info script]]]

create_project -force $PROJECT_NAME $PROJECT_DIR/$PROJECT_NAME -part xc7a200tfbg676-2
set_property target_language VHDL [current_project]

# add VHDL sources
add_files -norecurse $REPO_PATH/ $REPO_PATH/src
add_files $REPO_PATH/deps/VHDL-Components/src/ComplexMultiplier.vhd
add_files $REPO_PATH/deps/VHDL-Components/src/DelayLine.vhd

#testbenches
add_files -norecurse -fileset sim_1 $REPO_PATH/test

# constraints
add_files -fileset constrs_1 -norecurse $REPO_PATH/constraints
set_property target_constrs_file $REPO_PATH/constraints/timing.xdc [current_fileset -constrset]

# ip cores
set ip_srcs [glob $REPO_PATH/ip/*.xci]
import_ip $ip_srcs

set_property top Polyphase_SSB [current_fileset]
update_compile_order -fileset sources_1

set_property top Polyphase_SSB_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1
