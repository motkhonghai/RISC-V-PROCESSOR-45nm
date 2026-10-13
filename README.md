# RISC-V Processor 45nm — RTL, Synthesis and Physical Design Reports

## Project Overview

This repository summarizes the RTL-to-physical-design implementation of a
PicoRV32-based RISC-V processor using a 45nm standard-cell flow.

The public `main` branch is intentionally kept as a lightweight report branch.
It contains only:

- RTL source
- timing constraints
- raw synthesis reports
- raw physical-design reports
- key implementation outputs (netlist, per-view SDC, post-PnR DEF)

Technology libraries, LEF/QRC files, cap tables, tool run scripts, generated
databases and checkpoint directories are not included on this branch.

## Design

| Item | Value |
|---|---|
| Top module | `picorv32` |
| RTL | `rtl/picorv32.v` |
| Constraint file | `constraints/picorv32.sdc` |
| Target clock | `core_clk` |
| Clock period | 10 ns |
| Target frequency | 100 MHz |
| Implementation node | 45nm |
| Synthesis tool | Cadence Genus 25.13 |
| Physical-design tool | Cadence Innovus 25.13 |

## Repository Structure

```text
constraints/
  picorv32.sdc

rtl/
  picorv32.v

synthesis/
  outputs/mmmc/            netlist, per-view SDC, final/report files
  reports/mmmc/*.rpt

physical_design/
  outputs/mmmc/            post-PnR netlist, DEF, per-view SDC
  reports/mmmc/<stage>/*.rpt
  reports/mmmc/<stage>/*.csv
  reports/mmmc/<stage>/*.txt
```

## High-Level Flow

1. RTL import
2. Constraint setup
3. Logic synthesis
4. Gate-level QoR, timing, area and power reporting
5. Innovus design initialization
6. Floorplan and power planning
7. Placement
8. Clock Tree Synthesis
9. Routing
10. Post-route extraction and timing recovery
11. Final timing, DRC, connectivity, area and power reporting

## Synthesis Summary

The latest synthesis reports are stored under `synthesis/reports/mmmc/` and
`synthesis/outputs/mmmc/final.rpt`.

| Metric | Value |
|---|---:|
| Final synthesis slack | +1618 ps |
| Final synthesis TNS | 0 ps |
| Failing paths | 0 |
| Leaf instances | 6822 |
| Sequential instances | 1557 |
| Combinational instances | 5265 |
| Cell area | 19942.020 µm² |
| Net area | 9019.486 µm² |
| Total estimated area | 28961.506 µm² |
| Scan-cell check | 0 mapped scan-cell instances |

Main synthesis reports:

- `synthesis/outputs/mmmc/final.rpt`
- `synthesis/reports/mmmc/picorv32_qor.rpt`
- `synthesis/reports/mmmc/picorv32_area.rpt`
- `synthesis/reports/mmmc/picorv32_power.rpt`
- `synthesis/reports/mmmc/picorv32_timing.rpt`
- `synthesis/reports/mmmc/picorv32_setup_timing.rpt`
- `synthesis/reports/mmmc/picorv32_check_design.rpt`
- `synthesis/reports/mmmc/picorv32_check_timing_intent.rpt`
- `synthesis/reports/mmmc/picorv32_scan_cell_check.rpt`

## Synthesis Power Summary

Power values below come directly from the synthesis power report.

| Category | Leakage (W) | Internal (W) | Switching (W) | Total (W) |
|---|---:|---:|---:|---:|
| Register | 1.71908e-07 | 2.95545e-04 | 1.07231e-04 | 4.02948e-04 |
| Logic | 2.54775e-07 | 7.95440e-05 | 1.77970e-04 | 2.57769e-04 |
| Total | 4.26683e-07 | 3.75089e-04 | 2.85200e-04 | 6.60717e-04 |

## Physical Design Summary

The final physical-design reports are stored under
`physical_design/reports/mmmc/6_chip_finish/`.

| Metric | Value |
|---|---:|
| Post-route setup WNS | +2.249 ns |
| Post-route setup TNS | 0.000 ns |
| Setup violating paths | 0 |
| Post-route hold WNS | +0.002 ns |
| Post-route hold TNS | 0.000 ns |
| Hold violating paths | 0 |
| Max transition violations | 0 |
| Max capacitance violations | 0 |
| Real max-fanout violations | 159 |
| Total max-fanout terms | 175 |
| Final DRC violations | 0 |
| Final connectivity violations | 0 |
| Final instance count | 7899 |
| Final cell area | 22817.556 µm² |
| Final density | 69.935% |

Main physical-design reports:

- `physical_design/reports/mmmc/1_init_design/check_design_input.rpt`
- `physical_design/reports/mmmc/1_init_design/check_timing.rpt`
- `physical_design/reports/mmmc/3_placement/setup.rpt`
- `physical_design/reports/mmmc/4_cts/setup.rpt`
- `physical_design/reports/mmmc/4_cts/hold.rpt`
- `physical_design/reports/mmmc/4_cts/clock_trees.rpt`
- `physical_design/reports/mmmc/4_cts/skew_groups.rpt`
- `physical_design/reports/mmmc/5_routing/setup.rpt`
- `physical_design/reports/mmmc/5_routing/hold.rpt`
- `physical_design/reports/mmmc/6_chip_finish/setup.rpt`
- `physical_design/reports/mmmc/6_chip_finish/hold.rpt`
- `physical_design/reports/mmmc/6_chip_finish/area.rpt`
- `physical_design/reports/mmmc/6_chip_finish/power.rpt`
- `physical_design/reports/mmmc/6_chip_finish/drc.rpt`
- `physical_design/reports/mmmc/6_chip_finish/connectivity.rpt`

## Physical Design Power Summary

Power values below come directly from the final Innovus power report. Units are
mW in the report.

| Component | Internal (mW) | Switching (mW) | Leakage (mW) | Total (mW) | Share |
|---|---:|---:|---:|---:|---:|
| Sequential | 0.2942 | 0.02819 | 0.0001592 | 0.3225 | 44.66% |
| Combinational | 0.1179 | 0.1918 | 0.0003689 | 0.3101 | 42.93% |
| Clock | 0.0289 | 0.0607 | 0.000009774 | 0.08961 | 12.41% |
| Total | 0.4409 | 0.2807 | 0.0005379 | 0.7222 | 100% |

## Current Status

The latest reported implementation is clean for the main checks below:

- setup timing
- hold timing
- max transition
- max capacitance
- DRC
- connectivity
- mapped scan-cell check

The remaining item to review is `set_max_fanout 16`. The final report still
shows 159 real max-fanout violations. These fanout violations do not currently
cause max-transition, max-capacitance, timing, DRC or connectivity failures in
the reported run. If fanout 16 is a strict project requirement, the design
should be re-optimized with fanout repair and rerun through physical design. If
it is only a synthesis heuristic, the electrical checks already pass in the
current reports.

## Delivered Outputs

Key implementation deliverables are included under `outputs/`.

Synthesis — `synthesis/outputs/mmmc/`:

| File | Description |
|---|---|
| `picorv32_netlist.v` | Gate-level netlist |
| `picorv32_slow_setup.sdc` | SDC for the slow/setup view |
| `picorv32_fast_hold.sdc` | SDC for the fast/hold view |
| `final.rpt`, `syn_*_*.rpt` | Final and per-step QoR/timing reports |

Physical Design — `physical_design/outputs/mmmc/`:

| File | Description |
|---|---|
| `picorv32_post_pnr.v` | Post-place-and-route netlist |
| `picorv32_post_pnr.def` | Post-place-and-route DEF |
| `picorv32_post_pnr_slow_setup_view.sdc` | SDC for the slow/setup view |
| `picorv32_post_pnr_fast_hold_view.sdc` | SDC for the fast/hold view |

## Limitations

This report branch does not include a complete tapeout signoff package.

Not included or not yet signed off here:

- standard-cell libraries
- LEF/QRC/cap-table files
- Genus/Innovus run scripts
- generated implementation databases
- GDSII stream-out
- LVS
- foundry signoff DRC
- IR-drop and EM signoff
- formal equivalence
- full software/ISA regression

## References

- PicoRV32 RTL in this repository: `rtl/picorv32.v`
- RISC-V International: https://riscv.org/
