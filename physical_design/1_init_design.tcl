###############################################################################
# Stage 1: Design initialization
# Run: innovus -stylus -files 1_init_design.tcl
###############################################################################

###############################
# Setup - global variables
###############################
set STAGE  1_init_design
set DESIGN picorv32

set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
cd $PROJECT_PATH

set INPUT_DB    ${PROJECT_PATH}/synthesis/outputs/mmmc/INVS
set OUTPUT_PATH ${PROJECT_PATH}/physical_design/outputs/mmmc
set REPORT_PATH ${PROJECT_PATH}/physical_design/reports/mmmc/1_init_design
set OUTPUT_DB   ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_init

set PROCESS_NODE 45
set TOP_ROUTING_LAYER Metal11
set CTS_BUFFER_CELLS [list CLKBUFX8 CLKBUFX16 CLKBUFX20]
set CTS_INVERTER_CELLS [list CLKINVX8 CLKINVX16 CLKINVX20]
set FILLER_CELLS [list FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1]
set TIE_CELLS [list TIELO TIEHI]

file mkdir $OUTPUT_PATH
file mkdir $REPORT_PATH

set_db init_power_nets  VDD
set_db init_ground_nets VSS

###############################
# Check input
###############################
if {![file exists $INPUT_DB]} {
    error "Genus MMMC database not found: $INPUT_DB"
}

###############################
# Read Genus MMMC handoff
###############################
read_db -common $INPUT_DB
set PD_DATABASE_LOADED true

# Path groups exported inside a mode-specific SDC are ignored by Innovus
# (TA-976). Recreate them here as global path groups for all active views.
set DATA_INPUTS [all_inputs -no_clocks]
set REGISTERS   [all_registers]

if {[sizeof_collection $REGISTERS] > 0} {
    group_path -name I2C -from $DATA_INPUTS -to $REGISTERS
    group_path -name R2R -from $REGISTERS -to $REGISTERS
    group_path -name C2O -from $REGISTERS -to [all_outputs]
}

group_path -name I2O -from $DATA_INPUTS -to [all_outputs]

###############################
# Configure Innovus
###############################
set_db design_process_node $PROCESS_NODE
set_db timing_analysis_cppr both
set_db timing_analysis_type ocv
set_db design_top_routing_layer $TOP_ROUTING_LAYER
set_db cts_buffer_cells $CTS_BUFFER_CELLS
set_db cts_inverter_cells $CTS_INVERTER_CELLS
set_db add_fillers_cells $FILLER_CELLS
set_db add_tieoffs_cells $TIE_CELLS

puts "MMMC analysis views: [get_db analysis_views]"

###############################
# Check imported design
###############################
# Stylus Common UI checks for inconsistent or missing netlist, library,
# timing, floorplan, I/O and power/ground data before implementation starts.
check_design -type all \
    > ${REPORT_PATH}/check_design_all.rpt

# Check clocks, exceptions and timing constraints independently from the
# structural/library checks above.
check_timing -verbose \
    > ${REPORT_PATH}/check_timing.rpt

###############################
# Save design
###############################
write_db $OUTPUT_DB

puts "Done $STAGE"
puts "Saved database: $OUTPUT_DB"
