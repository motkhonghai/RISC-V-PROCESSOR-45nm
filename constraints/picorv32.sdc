###############################################################################
# Timing constraints for the standalone PicoRV32 core
# Time unit: ns (defined by the Liberty libraries)
# Capacitance unit: pF (defined by the Liberty libraries)
###############################################################################

set CORE_CLOCK_PERIOD_NS          10.00
set CLOCK_SETUP_UNCERTAINTY_NS     0.20
set CLOCK_HOLD_UNCERTAINTY_NS      0.10
set CLOCK_TRANSITION_NS            0.10
set INPUT_DELAY_MAX_NS             1.00
set INPUT_DELAY_MIN_NS             0.20
set OUTPUT_DELAY_MAX_NS            1.00
set OUTPUT_DELAY_MIN_NS           -0.20
set OUTPUT_LOAD_PF                  0.05
set DESIGN_MAX_TRANSITION_NS        0.50
set DESIGN_MAX_FANOUT              16
set DESIGN_MAX_CAPACITANCE_PF       0.20

###############################################################################
# Primary clock
###############################################################################

create_clock \
    -name core_clk \
    -period $CORE_CLOCK_PERIOD_NS \
    -waveform [list 0.00 [expr {$CORE_CLOCK_PERIOD_NS / 2.0}]] \
    [get_ports clk]

set_clock_uncertainty \
    -setup $CLOCK_SETUP_UNCERTAINTY_NS \
    [get_clocks core_clk]

set_clock_uncertainty \
    -hold $CLOCK_HOLD_UNCERTAINTY_NS \
    [get_clocks core_clk]

set_clock_transition \
    $CLOCK_TRANSITION_NS \
    [get_clocks core_clk]

###############################################################################
# Input interface
# resetn is synchronous and is therefore timed as a data input.
###############################################################################

set DATA_INPUT_PORTS \
    [remove_from_collection [all_inputs] [get_ports clk]]

if {[sizeof_collection $DATA_INPUT_PORTS] > 0} {
    set_input_delay \
        -clock core_clk \
        -max $INPUT_DELAY_MAX_NS \
        $DATA_INPUT_PORTS

    set_input_delay \
        -clock core_clk \
        -min $INPUT_DELAY_MIN_NS \
        $DATA_INPUT_PORTS

    set_driving_cell \
        -lib_cell BUFX2 \
        -pin Y \
        $DATA_INPUT_PORTS
}

###############################################################################
# Output interface
###############################################################################

set DATA_OUTPUT_PORTS [all_outputs]

if {[sizeof_collection $DATA_OUTPUT_PORTS] > 0} {
    set_output_delay \
        -clock core_clk \
        -max $OUTPUT_DELAY_MAX_NS \
        $DATA_OUTPUT_PORTS

    set_output_delay \
        -clock core_clk \
        -min $OUTPUT_DELAY_MIN_NS \
        $DATA_OUTPUT_PORTS

    set_load \
        $OUTPUT_LOAD_PF \
        $DATA_OUTPUT_PORTS
}

###############################################################################
# Design-rule constraints
###############################################################################

set_max_transition \
    $DESIGN_MAX_TRANSITION_NS \
    [current_design]

set_max_fanout \
    $DESIGN_MAX_FANOUT \
    [current_design]

set_max_capacitance \
    $DESIGN_MAX_CAPACITANCE_PF \
    [current_design]
