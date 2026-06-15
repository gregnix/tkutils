#!/usr/bin/env tclsh
# demo-tkucanvaspng.tcl -- draw a Tk canvas and export it to a PNG with
# tkutils::tkucanvaspng (pure Tcl via tclutils::tupngdraw; no Tk image needed).
# Optional widget -- not in the tkutils umbrella, so we require it directly.
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c; break
    }
}
package require Tk
package require tkutils::tkucanvaspng

wm title . "tkucanvaspng demo"
set out [file join $here canvas-demo.png]

canvas .c -width 360 -height 220 -background white -highlightthickness 0
# a few item kinds tkucanvaspng can rasterise
.c create rectangle 20 20 160 90 -fill "#cfe8ff" -outline "#1e5fa8" -width 2
.c create oval      200 20 340 90 -fill "#ffe0cf" -outline "#c2541e" -width 2
.c create line      20 120 340 120 -fill "#333333" -width 3 -arrow last
.c create polygon   60 200 110 150 160 200 -fill "#d7f0d0" -outline "#2e7d32" -width 2
.c create arc       210 140 330 210 -start 20 -extent 200 -style pieslice \
    -fill "#efe0ff" -outline "#6a1b9a" -width 2
.c create text      180 105 -text "tkucanvaspng" -fill "#202020" -font {Helvetica 14 bold}

proc export {} {
    .c configure -cursor watch; update idletasks
    set png [::tkutils::tkucanvaspng::write $::out .c -scale 2]
    .c configure -cursor {}
    .status configure -text "wrote $::out  ([file size $::out] bytes)"
}

ttk::frame .bar
ttk::button .bar.exp -text "Export PNG (2x)" -command export
ttk::label  .status  -text "click Export to write the PNG"
grid .c            -row 0 -column 0 -padx 8 -pady 8
grid .bar          -row 1 -column 0 -sticky w -padx 8
grid .bar.exp      -row 0 -column 0
grid .status       -row 2 -column 0 -sticky w -padx 8 -pady {0 8}

export   ;# also write once at startup so the file exists immediately

if {![info exists ::env(DEMO_NOLOOP)]} { vwait forever }
