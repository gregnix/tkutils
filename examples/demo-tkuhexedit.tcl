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


package require tkutils::tkuhexedit

wm title . "tkutils demo: hexedit"
set w [::tkutils::tkuhexedit::widget .hex]
pack $w -fill both -expand 1

set sample [binary format a* "PDF-1.7\n% tkutils sample\n"]
append sample [binary format c* 0 1 2 3 4 5 6 7 8 9 10 255]
::tkutils::tkuhexedit::setData $w $sample
