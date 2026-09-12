###############################################################################
# Stage 3: Placement and pre-CTS optimization
# Run: innovus -stylus -files 3_placement.tcl
###############################################################################

###############################
# Setup - global variables
###############################
set STAGE  3_placement
set DESIGN picorv32

set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
cd $PROJECT_PATH

set INPUT_DB    ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_floorplan_power
set OUTPUT_PATH ${PROJECT_PATH}/physical_design/outputs/mmmc
set REPORT_PATH ${PROJECT_PATH}/physical_design/reports/mmmc/3_placement
set OUTPUT_DB   ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_place

file mkdir $OUTPUT_PATH
file mkdir $REPORT_PATH

###############################
# Use in-memory design or read input database
###############################
if {[info exists PD_DATABASE_LOADED] && $PD_DATABASE_LOADED} {
    puts "Use design already loaded in memory"
} else {
    if {![file exists $INPUT_DB]} {
        error "Stage 2 database not found: $INPUT_DB"
    }
    read_db $INPUT_DB
    set PD_DATABASE_LOADED true
}

###############################
# Place standard cells and optimize
###############################
place_opt_design

###############################
# Report and save design
###############################
report_timing -late -max_paths 50 > ${REPORT_PATH}/setup.rpt
write_db $OUTPUT_DB

puts "Done $STAGE"
puts "Saved database: $OUTPUT_DB"
