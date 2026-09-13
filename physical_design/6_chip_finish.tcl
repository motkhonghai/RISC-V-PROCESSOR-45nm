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

set FILLER_CELLS [list FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1]

file mkdir $OUTPUT_PATH
file mkdir $REPORT_PATH

###############################
# Use in-memory design or read input database
###############################
if {[info exists PD_DATABASE_LOADED] && $PD_DATABASE_LOADED} {
    puts "Use design already loaded in memory"
} else {
    if {![file exists $INPUT_DB]} {
        error "Stage 5 database not found: $INPUT_DB"
    }
    read_db $INPUT_DB
    set PD_DATABASE_LOADED true
}

###############################
# Extract detailed parasitics
###############################
set_db delaycal_enable_si true
set_db extract_rc_engine post_route
set_db extract_rc_effort_level high
extract_rc

###############################
# Post-extraction recovery
###############################
# Stage 5 optimizes with post-route estimates. After detailed RC extraction,
# a few transition violations can reappear, so fix DRV/timing on extracted RC,
# repair ECO routes, and extract again before final reports.
delete_filler -cells $FILLER_CELLS -prefix FILLER
set_db opt_fix_hold_verbose true
set_db opt_post_route_area_reclaim hold_and_setup_aware
set_db opt_hold_target_slack 0.010
opt_design -post_route -drv -setup -hold \
    -hold_violation_report ${REPORT_PATH}/unfixed_hold_after_extract

set_db add_fillers_cells $FILLER_CELLS
add_fillers
route_eco

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
