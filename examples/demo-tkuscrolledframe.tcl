#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _r [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_r] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c; break
    }
}
package require tkutils::tkuscrolledframe
wm title . "tkuscrolledframe demo"

if {[catch {package require scrollutil}]} {
    pack [ttk::label .msg -padding 16 -text \
        "This demo needs the scrollutil package (tklib)."]
    vwait forever
    return
}

pack [ttk::label .hint -padding 8 -anchor w -text \
    "A scrollable frame with many rows -- scroll with the wheel or scrollbars."] -fill x

::tkutils::tkuscrolledframe::widget .sf -width 360 -height 240
pack .sf -fill both -expand 1 -padx 8 -pady 8

set c [::tkutils::tkuscrolledframe::content .sf]
for {set i 1} {$i <= 40} {incr i} {
    set row [ttk::frame $c.r$i]
    ttk::label  $row.l -width 10 -text "Row $i"
    ttk::entry  $row.e
    ttk::button $row.b -text "see last" -command {
        ::tkutils::tkuscrolledframe::see .sf [::tkutils::tkuscrolledframe::content .sf].r40
    }
    pack $row.l $row.e $row.b -side left -padx 4
    pack $row -fill x -pady 2
}

vwait forever
