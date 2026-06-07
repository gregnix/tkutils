#!/usr/bin/env tclsh
# Demo for tkutils::tkcanvaspng: build a Tk canvas, export it to PNG.
# Requires Tk and a display (run under a real X session or xvfb-run).
#
#   xvfb-run -a tclsh examples/generate-canvas-demo.tcl ?out.png?
#
set here [file dirname [file normalize [info script]]]
set tkroot [file normalize [file join $here ..]]
tcl::tm::path add [file join $tkroot lib tm]
# tkcanvaspng depends on tclutils (common/tupng/tupngdraw). When running this
# script standalone, make the tclutils module tree discoverable too. .tm
# modules are found via tcl::tm::path (NOT auto_path / TCLLIBPATH). Adjust /
# extend this list if your tclutils lives elsewhere.
foreach cand [list \
        [file join $tkroot .. tclutils lib tm] \
        [file join $tkroot .. .. tclutils lib tm] \
        [file join $tkroot lib tm]] {
    if {[file isdirectory $cand]} { tcl::tm::path add [file normalize $cand] }
}
package require Tk
package require tkutils::tkcanvaspng

set out [expr {[llength $argv] ? [lindex $argv 0] : [file join $here canvas-demo.png]}]

canvas .c -width 320 -height 200 -background white -highlightthickness 0
.c create rectangle 20 20 140 90  -fill lightblue -outline navy -width 2
.c create oval      170 20 300 90 -fill "#ffcccc" -outline red -width 2
.c create line      20 120 300 120 -fill darkgreen -width 3
.c create polygon   30 130 90 180 30 180 -fill khaki -outline "#aa7700" -width 2
.c create arc       120 130 190 195 -start 20 -extent 250 -style pieslice \
    -fill "#c0a0ff" -outline "#5522aa" -width 2
.c create text      210 160 -text "canvas -> png" -fill "#1a3f7a" -anchor w
pack .c
update idletasks   ;# canvas must be rendered first (as for pdf4tcl)

::tkutils::tkcanvaspng::write $out .c -scale 2
puts "wrote $out  (region [.c bbox all])"
exit 0
