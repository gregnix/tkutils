#!/usr/bin/env tclsh
# tkutemplate -- edit a document template file.
#
#   tclsh bin/tkutemplate.tcl ?template.tcl?
#
# Without a file the editor starts empty; "Save…" writes the template.
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing \
            [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
if {[info exists ::env(PDF4TCLLIB_TM)]} {
    tcl::tm::path add $::env(PDF4TCLLIB_TM)
} else {
    catch {tcl::tm::path add [file normalize [file join $here .. .. pdf4tcllib lib]]}
}
package require tkutils::tkutemplate

wm title . "tkutemplate"
wm geometry . 1120x800
set w [::tkutils::tkutemplate::widget .te]
pack $w -fill both -expand 1
if {[llength $argv] > 0} {
    ::tkutils::tkutemplate::loadFile $w [lindex $argv 0]
    wm title . "tkutemplate -- [file tail [lindex $argv 0]]"
}

# enter the Tk event loop when launched as a standalone application
vwait forever
