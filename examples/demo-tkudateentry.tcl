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
package require tkutils::tkudateentry
wm title . "tkudateentry demo"
ttk::label .lbl -text "pick a date:"
set de [::tkutils::tkudateentry::widget .de -dateformat "%d.%m.%Y" \
    -command {apply {iso {.out configure -text "ISO: $iso"}}}]
::tkutils::tkudateentry::today $de
ttk::label .out -text "ISO: [::tkutils::tkudateentry::getDate $de]"
grid .lbl .de -padx 6 -pady 6 -sticky w
grid .out -columnspan 2 -padx 6 -pady {0 6} -sticky w
vwait forever
