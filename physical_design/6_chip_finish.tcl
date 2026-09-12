###############################################################################
# Stage 6: Chip finishing, RC extraction and physical verification
# Run: innovus -stylus -files 6_chip_finish.tcl
###############################################################################

###############################
# Setup - global variables
###############################
set STAGE  6_chip_finish
set DESIGN picorv32

set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
cd $PROJECT_PATH

set INPUT_DB    ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_post_route
set OUTPUT_PATH ${PROJECT_PATH}/physical_design/outputs/mmmc
set REPORT_PATH ${PROJECT_PATH}/physical_design/reports/mmmc/6_chip_finish
set OUTPUT_DB   ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_finish

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
# Extract detailed parasitics
###############################
set_db delaycal_enable_si true
set_db extract_rc_engine post_route
set_db extract_rc_effort_level high
extract_rc

###############################
# Timing and physical checks
###############################
report_timing -late  -max_paths 100 > ${REPORT_PATH}/setup.rpt
report_timing -early -max_paths 100 > ${REPORT_PATH}/hold.rpt
report_area  > ${REPORT_PATH}/area.rpt
report_power > ${REPORT_PATH}/power.rpt

check_drc > ${REPORT_PATH}/drc.rpt
check_connectivity > ${REPORT_PATH}/connectivity.rpt

# Metal fill and foundry LVS are not run here because the required PDK rule
# decks are not included in this project.

###############################
# Save design
###############################
write_db $OUTPUT_DB

puts "Done $STAGE"
puts "Saved database: $OUTPUT_DB"
