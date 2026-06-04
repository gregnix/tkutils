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
package require tkutils::tkunumentry
wm title . "tkunumentry demo"
set ne [::tkutils::tkunumentry::widget .ne -decimals 2 -min 0 -max 100 \
    -command {apply {v {.out configure -text "committed: $v  (0..100)"}}}]
::tkutils::tkunumentry::setValue $ne 19.99
ttk::label .out -text "committed: [::tkutils::tkunumentry::getValue $ne]  (0..100)"
grid [ttk::label .lbl -text "amount:"] .ne -padx 6 -pady 6 -sticky w
grid .out -columnspan 2 -padx 6 -pady {0 6} -sticky w
vwait forever
