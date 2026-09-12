# GPDK045 technology files

The technology files in `lib/`, `lef/`, `QRC_Tech/`, and `captable/` were
copied from the sibling `counter_design_45nm` project.

Use `mmmc.view` with Stylus/Common UI to load the slow/fast Liberty corners, the GPDK045 QRC
technology file, and the requested capacitance table. For physical-aware
synthesis or Innovus initialization, also load these LEFs in this order:

1. `lef/gsclib045_tech.lef`
2. `lef/gsclib045_macro.lef`

The supplied capacitance table reports its process as
`cln28hpl_1p10m+alrdl_5x2yu2yz_typical`, not GPDK045. It is enabled in
`mmmc.view` to reproduce the requested setup, but its RC results must not be
treated as characterized 45 nm signoff results. Replace it with a matching
GPDK045 capTbl when one is available.

`mmmc.tcl` is retained only as a compatibility wrapper that sources
`mmmc.view`.

The initial SDC assumes a 10 ns (100 MHz) clock, 1 ns I/O delays, 0.2 ns
clock uncertainty, and 0.05 pF output load. These are starting assumptions,
not specifications of the PicoRV32 core.
