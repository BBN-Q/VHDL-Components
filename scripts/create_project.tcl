###########################################################
# Tcl script to create the VHDL-Components Vivado project
#
# Usage: at the Tcl console manually set the argv to set the PROJECT_DIR and PROJECT_NAME and
# then source this file. E.g.
#
# set argv [list "/home/cryan/Programming/FPGA" "VHDL-Components"] or
# or  set argv [list "C:/Users/qlab/Documents/Xilinx Projects/" "VHDL-Components"]
# source create_project.tcl
#
# from Vivado batch mode use the -tclargs to pass argv
# vivado -mode batch -source create_project.tcl -tclargs "/home/cryan/Programming/FPGA" "VHDL-Components"
############################################################

set PROJECT_DIR [lindex $argv 0]
set PROJECT_NAME [lindex $argv 1]

#Figure out the script path
set SCRIPT_PATH [file normalize [info script]]
set REPO_PATH [file dirname $SCRIPT_PATH]/../

create_project -force $PROJECT_NAME $PROJECT_DIR/$PROJECT_NAME -part xc7a200tfbg676-2
set_property "default_lib" "xil_defaultlib" [current_project]
set_property "sim.ip.auto_export_scripts" "1" [current_project]
set_property "simulator_language" "Mixed" [current_project]
set_property "target_language" "VHDL" [current_project]

# add VHDL sources
add_files -norecurse $REPO_PATH/ $REPO_PATH/src

#testbenches
add_files -norecurse -fileset sim_1 $REPO_PATH/test

# constraints
add_files -fileset constrs_1 -norecurse $REPO_PATH/constraints
set_property target_constrs_file $REPO_PATH/constraints/timing.xdc [current_fileset -constrset]

# ip cores
set ip_srcs [glob $REPO_PATH/ip/*.xci]
import_ip $ip_srcs
