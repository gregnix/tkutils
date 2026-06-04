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
package require tkutils::tkusearchbar
wm title . "tkusearchbar demo"
set sb [::tkutils::tkusearchbar::widget .sb -delay 250 -filters {All Active Done} \
    -command {apply {{text filter} {.out configure -text "search: \"$text\"  filter: $filter"}}}]
ttk::label .out -text "type to search (debounced)..."
grid .sb -sticky ew -padx 6 -pady 6
grid .out -sticky w -padx 6 -pady {0 6}
grid columnconfigure . 0 -weight 1
vwait forever
