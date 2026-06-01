#!/usr/bin/env tclsh
# tkhexedit.tcl -- small hex editor/viewer based on tkutils::tkhexedit

set scriptDir [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $scriptDir .. lib tm]]
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


package require tkutils::tkhexedit

wm title . "tkhexedit"
set w [::tkutils::tkhexedit::widget .hex]
pack $w -fill both -expand 1

if {[llength $argv] > 0} {
    ::tkutils::tkhexedit::loadFile $w [lindex $argv 0]
}

# enter the Tk event loop when launched as a standalone application
vwait forever
