###############################################################################
# Stage 5: Routing and post-route optimization
# Run: innovus -stylus -files 5_routing.tcl
###############################################################################

###############################
# Setup - global variables
###############################
set STAGE  5_routing
set DESIGN picorv32

set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
cd $PROJECT_PATH

set INPUT_DB    ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_post_cts
set OUTPUT_PATH ${PROJECT_PATH}/physical_design/outputs/mmmc
set REPORT_PATH ${PROJECT_PATH}/physical_design/reports/mmmc/5_routing
set OUTPUT_DB   ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_post_route

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
        error "Stage 4 database not found: $INPUT_DB"
    }
    read_db $INPUT_DB
    set PD_DATABASE_LOADED true
}

###############################
# Route and optimize design
###############################
set_db opt_fix_hold_verbose true
route_opt_design -setup -hold

###############################
# Final post-route timing/DRV recovery
###############################
# route_opt_design can insert transparent fillers before its final recovery.
# Remove those fillers so post-route optimization has legal sites for delay
# cells and buffers, then optimize against the final routed parasitics.
delete_filler -cells $FILLER_CELLS -prefix FILLER
# Preserve both setup and hold during the automatic post-route area-reclaim
# phase. The setup-aware default removed freshly inserted hold buffers in the
# previous run and reintroduced about 8 ps of negative hold slack.
set_db opt_post_route_area_reclaim hold_and_setup_aware
set_db opt_hold_target_slack 0.010
opt_design -post_route -drv -setup -hold \
    -hold_violation_report ${REPORT_PATH}/unfixed_hold

###############################
# Insert filler cells and repair affected ECO routes
###############################
set_db add_fillers_cells $FILLER_CELLS
add_fillers
route_eco

###############################
# Report and save design
###############################
report_timing -late  -max_paths 50 > ${REPORT_PATH}/setup.rpt
report_timing -early -max_paths 50 > ${REPORT_PATH}/hold.rpt
write_db $OUTPUT_DB

puts "Done $STAGE"
puts "Saved database: $OUTPUT_DB"
