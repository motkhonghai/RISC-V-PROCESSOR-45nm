#################################################################################
#
# Created by Genus(TM) Synthesis Solution 25.13-s071_1 on Sat Sep 12 21:57:02 +07 2026
#
#################################################################################

## library_sets
create_library_set -name slow_libset \
    -timing { /home/icd1/workspace/RISC-V-PROCESSOR-45nm/lib/slow_vdd1v0_basicCells.lib }
create_library_set -name fast_libset \
    -timing { /home/icd1/workspace/RISC-V-PROCESSOR-45nm/lib/fast_vdd1v0_basicCells.lib }

## opcond
create_opcond -name slow_opcond \
    -process 1.0 \
    -voltage 0.9 \
    -temperature 125.0
create_opcond -name fast_opcond \
    -process 1.0 \
    -voltage 1.1 \
    -temperature 0.0

## timing_condition
create_timing_condition -name slow_timing_condition \
    -opcond slow_opcond \
    -library_sets { slow_libset }
create_timing_condition -name fast_timing_condition \
    -opcond fast_opcond \
    -library_sets { fast_libset }

## rc_corner
create_rc_corner -name rc_typical \
    -qrc_tech /home/icd1/workspace/RISC-V-PROCESSOR-45nm/QRC_Tech/gpdk045.tch \
    -pre_route_res 1.0 \
    -pre_route_cap 1.0 \
    -pre_route_clock_res 0.0 \
    -pre_route_clock_cap 0.0 \
    -post_route_res {1.0} \
    -post_route_cap {1.0} \
    -post_route_cross_cap {1.0} \
    -post_route_clock_res {1.0 1.0 1.0} \
    -post_route_clock_cap {1.0 1.0 1.0} \
    -post_route_clock_cross_cap {1.0 1.0 1.0}

## delay_corner
create_delay_corner -name slow_delay_corner \
    -early_timing_condition { slow_timing_condition } \
    -late_timing_condition { slow_timing_condition } \
    -early_rc_corner rc_typical \
    -late_rc_corner rc_typical
create_delay_corner -name fast_delay_corner \
    -early_timing_condition { fast_timing_condition } \
    -late_timing_condition { fast_timing_condition } \
    -early_rc_corner rc_typical \
    -late_rc_corner rc_typical

## constraint_mode
create_constraint_mode -name functional \
    -sdc_files { /home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/outputs/mmmc/INVS/cmn/picorv32.mmmc/modes/functional/functional.sdc.gz }

## analysis_view
create_analysis_view -name slow_setup_view \
    -constraint_mode functional \
    -delay_corner slow_delay_corner \
    -latency_file /home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/outputs/mmmc/INVS/cmn/picorv32.mmmc/views/slow_setup_view/latency.sdc.gz
create_analysis_view -name fast_hold_view \
    -constraint_mode functional \
    -delay_corner fast_delay_corner \
    -latency_file /home/icd1/workspace/RISC-V-PROCESSOR-45nm/synthesis/outputs/mmmc/INVS/cmn/picorv32.mmmc/views/fast_hold_view/latency.sdc.gz

## set_analysis_view
set_analysis_view -setup { slow_setup_view } \
                  -hold { fast_hold_view }
