#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Sat Sep 12 14:26:00 2026                
#                                                     
#######################################################

#@(#)CDS: Innovus v25.13-s088_1 (64bit) 03/26/2026 12:37 (Linux 4.18.0-305.el8.x86_64)
#@(#)CDS: NanoRoute 25.13-s088_1 NR260309-1855/25_13-UB (database version 18.20.683) {superthreading v2.20}
#@(#)CDS: AAE 25.13-s023 (64bit) 03/26/2026 (Linux 4.18.0-305.el8.x86_64)
#@(#)CDS: CTE 25.13-s044_1 () Mar 24 2026 17:45:14 ( )
#@(#)CDS: SYNTECH 25.13-s012_1 () Mar 10 2026 03:01:02 ( )
#@(#)CDS: CPE v25.13-s019
#@(#)CDS: IQuantus/TQuantus 24.1.0-s476 (64bit) Wed Feb 11 22:11:27 PST 2026 (Linux 4.18.0-305.el8.x86_64)

#@ source run_full.tcl 
#@ Begin verbose source (pre): source run_full.tcl 
set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
cd $PROJECT_PATH
set SCRIPT_PATH  ${PROJECT_PATH}/physical_design
#@ source ${SCRIPT_PATH}/1_init_design.tcl
#@ Begin verbose source /home/icd1/workspace/RISC-V-PROCESSOR-45nm/physical_design/1_init_design.tcl (pre)
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
if {![file exists $INPUT_DB]} {...}
read_db -common $INPUT_DB
set_db design_process_node $PROCESS_NODE
set_db timing_analysis_cppr both
set_db timing_analysis_type ocv
set_db design_top_routing_layer $TOP_ROUTING_LAYER
set_db cts_buffer_cells $CTS_BUFFER_CELLS
set_db cts_inverter_cells $CTS_INVERTER_CELLS
set_db add_fillers_cells $FILLER_CELLS
set_db add_tieoffs_cells $TIE_CELLS
puts "MMMC analysis views: [get_db analysis_views]"
write_db $OUTPUT_DB
puts "Done $STAGE"
puts "Saved database: $OUTPUT_DB"
#@ End verbose source /home/icd1/workspace/RISC-V-PROCESSOR-45nm/physical_design/1_init_design.tcl
#@ source ${SCRIPT_PATH}/2_floorplan_power.tcl
#@ Begin verbose source /home/icd1/workspace/RISC-V-PROCESSOR-45nm/physical_design/2_floorplan_power.tcl (pre)
set STAGE  2_floorplan_power
set DESIGN picorv32
set PROJECT_PATH /home/icd1/workspace/RISC-V-PROCESSOR-45nm
cd $PROJECT_PATH
set INPUT_DB    ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_init
set OUTPUT_PATH ${PROJECT_PATH}/physical_design/outputs/mmmc
set REPORT_PATH ${PROJECT_PATH}/physical_design/reports/mmmc/2_floorplan_power
set OUTPUT_DB   ${PROJECT_PATH}/physical_design/outputs/mmmc/picorv32_floorplan_power
set IO_FILE     ${PROJECT_PATH}/physical_design/pins_mmmc.io
set POWER_NET       VDD
set GROUND_NET      VSS
set CORE_SITE       CoreSite
set CORE_WIDTH      180.0
set CORE_HEIGHT     181.26
set CORE_MARGIN     10.0
file mkdir $OUTPUT_PATH
file mkdir $REPORT_PATH
if {![file exists $INPUT_DB]} {...}
read_db $INPUT_DB
#@ End verbose source /home/icd1/workspace/RISC-V-PROCESSOR-45nm/physical_design/2_floorplan_power.tcl
#@ End verbose source run_full.tcl
exit
