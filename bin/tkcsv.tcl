#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
# locate the tclutils dependency for in-tree/dev use
# (installed systems already have tclutils on the module path)
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
package require tkutils::tkcsv

wm title . "tkcsv"
set w [::tkutils::tkcsv::widget .w]
pack $w -fill both -expand 1
if {[llength $argv] > 0} { ::tkutils::tkcsv::loadFile $w [lindex $argv 0] }

# enter the Tk event loop when launched as a standalone application
vwait forever
