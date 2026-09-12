# GPDK045 technology files

The technology files in `lib/`, `lef/`, and `QRC_Tech/` were copied from the
sibling `counter_design_45nm` project.

Use `mmmc.view` with Stylus/Common UI to load the slow/fast Liberty corners
and the GPDK045 QRC technology file. For physical-aware synthesis or Innovus
initialization, also load these LEFs in this order:

1. `lef/gsclib045_tech.lef`
2. `lef/gsclib045_macro.lef`

The RC corner uses `QRC_Tech/gpdk045.tch` only. Do not add a capacitance table
from another process node. A capTbl may be added later only when it is a
GPDK045 table characterized for the intended RC corner.

`mmmc.tcl` is retained only as a compatibility wrapper that sources
`mmmc.view`.

The initial SDC assumes a 10 ns (100 MHz) clock, 1 ns I/O delays, 0.2 ns
clock uncertainty, and 0.05 pF output load. These are starting assumptions,
not specifications of the PicoRV32 core.
