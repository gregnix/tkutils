#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
package require tkutils::tkuicon
wm title . "tkuicon demo"

set ns ::tkutils::tkuicon

if {![$ns\::hassvg]} {
    pack [ttk::label .msg -padding 16 -justify left -text \
        "No SVG support in this Tk build.\n\ntkuicon needs the tksvg package on Tk 8.6,\
        \nor native SVG on Tk 9.0+.\n\nAvailable icon names ([llength [$ns\::available]]):\n\
        [join [$ns\::available] {  }]"]
    vwait forever
    return
}

pack [ttk::label .info -padding 8 -text \
    "Generated from tclutils::tusvg, rendered via tkuicon. Click to enlarge."] -anchor w

set grid [ttk::frame .g -padding 8]
pack $grid -fill both -expand 1
set col 0
set row 0
foreach name [$ns\::available] {
    set img [$ns\::create $name 24 -color "#333333"]
    set b [ttk::button $grid.b$name -image $img \
        -command [list ::showBig $name]]
    grid $b -row $row -column $col -padx 3 -pady 3
    if {[incr col] >= 12} { set col 0; incr row }
}

pack [ttk::label .big -padding 8] -anchor w
proc showBig {name} {
    set img [::tkutils::tkuicon::create $name 64 -color "#1565c0"]
    .big configure -image $img -text "  $name" -compound left
}

vwait forever
