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
package require tkutils::tktimeentry
wm title . "tktimeentry demo"
set te [::tkutils::tktimeentry::widget .te -seconds 1 -increment 15 \
    -command {apply {t {.out configure -text "time: $t"}}}]
::tkutils::tktimeentry::setTime $te 09:30:00
ttk::label .out -text "time: [::tkutils::tktimeentry::getTime $te]"
grid [ttk::label .lbl -text "start:"] .te -padx 6 -pady 6 -sticky w
grid .out -columnspan 2 -padx 6 -pady {0 6} -sticky w
vwait forever
