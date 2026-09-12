###############################################################################
# Stage 4: Clock Tree Synthesis and post-CTS optimization
# Run: innovus -stylus -files 4_cts.tcl
###############################################################################

###############################
# Setup - global variables
###############################
set STAGE  4_cts
set DESIGN picorv32

set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
cd $PROJECT_PATH

set INPUT_DB    ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_place
set OUTPUT_PATH ${PROJECT_PATH}/physical_design/outputs/mmmc
set REPORT_PATH ${PROJECT_PATH}/physical_design/reports/mmmc/4_cts
set OUTPUT_DB   ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_post_cts

file mkdir $OUTPUT_PATH
file mkdir $REPORT_PATH

###############################
# Use in-memory design or read input database
###############################
# Always reload the predecessor checkpoint, including in run_full.tcl.
# This avoids accidentally using an unrelated design left in memory.
if {![file exists $INPUT_DB]} {
    error "Predecessor database not found: $INPUT_DB"
}
read_db $INPUT_DB

###############################
# Create and optimize clock tree
###############################
clock_opt_design
set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [all_clocks]

###############################
# Report and save design
###############################
report_timing -late  -max_paths 50 > ${REPORT_PATH}/setup.rpt
report_timing -early -max_paths 50 > ${REPORT_PATH}/hold.rpt
write_db $OUTPUT_DB

puts "Done $STAGE"
puts "Saved database: $OUTPUT_DB"
