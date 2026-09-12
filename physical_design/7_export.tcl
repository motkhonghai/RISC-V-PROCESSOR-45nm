###############################################################################
# Stage 7: Export final database, netlist, DEF and SDC
# Run: innovus -stylus -files 7_export.tcl
###############################################################################

###############################
# Setup - global variables
###############################
set STAGE  7_export
set DESIGN picorv32

set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
cd $PROJECT_PATH

set INPUT_DB    ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_finish
set OUTPUT_PATH ${PROJECT_PATH}/physical_design/outputs/mmmc
set REPORT_PATH ${PROJECT_PATH}/physical_design/reports/mmmc/7_export
set OUTPUT_DB   ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_final
set NETLIST     ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_post_pnr.v
set DEF_FILE    ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_post_pnr.def
set SLOW_SDC    ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_post_pnr_slow_setup_view.sdc
set FAST_SDC    ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_post_pnr_fast_hold_view.sdc

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
# Save final database
###############################
write_db $OUTPUT_DB

###############################
# Export netlist and DEF
###############################
write_netlist $NETLIST
write_def $DEF_FILE

###############################
# Export SDC for both MMMC views
###############################
write_sdc -view slow_setup_view > $SLOW_SDC
write_sdc -view fast_hold_view > $FAST_SDC

###############################
# Export GDSII
###############################
# GDS export is intentionally not configured: this repository has no cell GDS
# or verified GPDK045 stream map. DB/DEF/netlist/SDC remain available for review.
puts "GDS not exported: supply matching cell GDS and a verified stream map first."

puts "Final runtime and memory:"
time_info FINAL
puts "Done $STAGE"
puts "Saved database: $OUTPUT_DB"
puts "Netlist: $NETLIST"
puts "DEF: $DEF_FILE"
