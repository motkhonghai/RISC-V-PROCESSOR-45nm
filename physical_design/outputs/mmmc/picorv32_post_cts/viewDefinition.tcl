if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name fast_libset\
   -timing\
    [list ${::IMEX::libVar}/mmmc/fast_vdd1v0_basicCells.lib]
create_library_set -name slow_libset\
   -timing\
    [list ${::IMEX::libVar}/mmmc/slow_vdd1v0_basicCells.lib]
create_opcond -name fast_opcond -process 1 -voltage 1.1 -temperature 0
create_opcond -name slow_opcond -process 1 -voltage 0.9 -temperature 125
create_timing_condition -name slow_timing_condition\
   -library_sets [list slow_libset]\
   -opcond slow_opcond
create_timing_condition -name fast_timing_condition\
   -library_sets [list fast_libset]\
   -opcond fast_opcond
create_rc_corner -name rc_typical\
   -pre_route_res 1\
   -post_route_res 1\
   -pre_route_cap 1\
   -post_route_cap 1\
   -post_route_cross_cap 1\
   -pre_route_clock_res 0\
   -pre_route_clock_cap 0\
   -post_route_clock_cap {1 1 1}\
   -post_route_clock_res {1 1 1}\
   -post_route_clock_cross_cap {1 1 1}\
   -qrc_tech ${::IMEX::libVar}/mmmc/rc_typical/gpdk045.tch
create_delay_corner -name fast_delay_corner\
   -early_timing_condition {fast_timing_condition}\
   -late_timing_condition {fast_timing_condition}\
   -rc_corner rc_typical
create_delay_corner -name slow_delay_corner\
   -early_timing_condition {slow_timing_condition}\
   -late_timing_condition {slow_timing_condition}\
   -rc_corner rc_typical
create_constraint_mode -name functional\
   -sdc_files\
    [list ${::IMEX::dataVar}/mmmc/modes/functional/functional.sdc.gz]
create_analysis_view -name fast_hold_view -constraint_mode functional -delay_corner fast_delay_corner -latency_file ${::IMEX::dataVar}/mmmc/views/fast_hold_view/latency.sdc.gz
create_analysis_view -name slow_setup_view -constraint_mode functional -delay_corner slow_delay_corner -latency_file ${::IMEX::dataVar}/mmmc/views/slow_setup_view/latency.sdc.gz
set_analysis_view -setup [list slow_setup_view] -hold [list fast_hold_view]
catch {set_interactive_constraint_mode [list functional] } 
