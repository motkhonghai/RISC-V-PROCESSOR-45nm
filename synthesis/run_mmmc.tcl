###############################################################################
# Genus Stylus MMMC synthesis flow for the PicoRV32 core
# Run with:
# genus -stylus -files /home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/run_mmmc.tcl
###############################################################################

set PROJECT_PATH    /home/icd1/workspace/RISC-V-PROCESSOR-45nm
set SYNTHESIS_PATH  ${PROJECT_PATH}/synthesis
set RTL_PATH        ${PROJECT_PATH}/rtl
set LIB_PATH        ${PROJECT_PATH}/lib
set LEF_PATH        ${PROJECT_PATH}/lef
set OUTPUTS_PATH    ${SYNTHESIS_PATH}/outputs/mmmc
set REPORTS_PATH    ${SYNTHESIS_PATH}/reports/mmmc
set MMMC_FILE       ${PROJECT_PATH}/mmmc.view

cd $PROJECT_PATH

set DESIGN picorv32
set SYN_EFFORT medium
set MAP_EFFORT medium
set OPT_EFFORT medium

puts "Project   : $PROJECT_PATH"
puts "Design    : $DESIGN"
puts "Hostname  : [info hostname]"
puts "Genus     : [get_db program_version]"

###############################################################################
# Output directories
###############################################################################

file mkdir $OUTPUTS_PATH
file mkdir $REPORTS_PATH

###############################################################################
# Stylus configuration
###############################################################################

set_db init_lib_search_path [list \
    $LIB_PATH \
]

set_db init_hdl_search_path [list \
    $RTL_PATH \
]

set_db script_search_path [list \
    $PROJECT_PATH \
    $SYNTHESIS_PATH \
]

set_db max_cpus_per_server 8
set_db information_level 9
set_db syn_generic_effort $SYN_EFFORT
set_db syn_map_effort $MAP_EFFORT
set_db syn_opt_effort $OPT_EFFORT

###############################################################################
# Libraries, technology, constraints and RTL
###############################################################################

read_mmmc $MMMC_FILE

read_physical -lefs [list \
    ${LEF_PATH}/gsclib045_tech.lef \
    ${LEF_PATH}/gsclib045_macro.lef \
]

read_hdl ${RTL_PATH}/picorv32.v
elaborate $DESIGN
init_design

check_design -unresolved \
    > ${REPORTS_PATH}/picorv32_check_design.rpt

check_timing_intent \
    > ${REPORTS_PATH}/picorv32_check_timing_intent.rpt

report_clocks \
    > ${REPORTS_PATH}/picorv32_clocks.rpt

time_info ELABORATION

###############################################################################
# Path groups
###############################################################################

set HAS_REGISTERS [expr {[llength [all_registers]] > 0}]

foreach VIEW [get_db analysis_views -if {.is_setup == true}] {
    if {$HAS_REGISTERS} {
        group_path \
            -name I2C \
            -from [all_inputs -no_clocks] \
            -to [all_registers] \
            -view $VIEW

        group_path \
            -name R2R \
            -from [all_registers] \
            -to [all_registers] \
            -view $VIEW

        group_path \
            -name C2O \
            -from [all_registers] \
            -to [all_outputs] \
            -view $VIEW
    }

    group_path \
        -name I2O \
        -from [all_inputs -no_clocks] \
        -to [all_outputs] \
        -view $VIEW
}

report_timing -max_paths 20 \
    > ${REPORTS_PATH}/picorv32_pre_synthesis_timing.rpt

###############################################################################
# Generic synthesis
###############################################################################

syn_generic

write_snapshot \
    -directory $OUTPUTS_PATH \
    -tag syn_generic

write_reports \
    -directory $REPORTS_PATH \
    -tag syn_generic

time_info GENERIC

###############################################################################
# Technology mapping
###############################################################################

syn_map

write_snapshot \
    -directory $OUTPUTS_PATH \
    -tag syn_map

write_reports \
    -directory $REPORTS_PATH \
    -tag syn_map

time_info MAPPED

###############################################################################
# Post-mapping optimization
###############################################################################

syn_opt

write_snapshot \
    -innovus \
    -directory $OUTPUTS_PATH \
    -tag syn_opt

write_reports \
    -directory $REPORTS_PATH \
    -tag syn_opt

time_info OPTIMIZED

###############################################################################
# Final reports
###############################################################################

report_messages \
    > ${REPORTS_PATH}/picorv32_messages.rpt

report_gates \
    > ${REPORTS_PATH}/picorv32_gates.rpt

report_area \
    > ${REPORTS_PATH}/picorv32_area.rpt

report_power \
    > ${REPORTS_PATH}/picorv32_power.rpt

report_qor \
    > ${REPORTS_PATH}/picorv32_qor.rpt

report_timing \
    -view slow_setup_view \
    -late \
    -max_paths 50 \
    > ${REPORTS_PATH}/picorv32_setup_timing.rpt

report_timing \
    -view fast_hold_view \
    -early \
    -max_paths 50 \
    > ${REPORTS_PATH}/picorv32_hold_timing.rpt

###############################################################################
# Netlist, constraints, databases and Innovus handoff
###############################################################################

write_hdl \
    > ${OUTPUTS_PATH}/picorv32_netlist.v

write_sdc -view slow_setup_view \
    > ${OUTPUTS_PATH}/picorv32_slow_setup.sdc

write_sdc -view fast_hold_view \
    > ${OUTPUTS_PATH}/picorv32_fast_hold.sdc

write_db \
    ${OUTPUTS_PATH}/picorv32.db

write_db \
    -common ${OUTPUTS_PATH}/INVS \
    -design $DESIGN

puts "Final runtime and memory"
time_info FINAL
puts "MMMC synthesis completed for $DESIGN"
puts "Outputs: $OUTPUTS_PATH"
puts "Reports: $REPORTS_PATH"

# Uncomment when running in a non-interactive batch job.
# quit
