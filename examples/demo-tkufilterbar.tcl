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
package require tkutils::tkufilterbar
wm title . "tkufilterbar demo"
set fb [::tkutils::tkufilterbar::widget .fb -delay 250 \
    -command {apply {{filters} {.out configure -text "filters: $filters"}}}]
::tkutils::tkufilterbar::setColumns $fb {id name club country}
ttk::label .out -text "type in any column field (debounced, ANDed by the consumer)..."
ttk::button .clr -text "Clear" -command [list ::tkutils::tkufilterbar::clear $fb]
grid .fb -sticky ew -padx 6 -pady 6
grid .out -sticky w -padx 6 -pady {0 6}
grid .clr -sticky w -padx 6 -pady {0 6}
grid columnconfigure . 0 -weight 1
vwait forever
