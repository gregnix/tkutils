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
package require tkutils::tkutags
wm title . "tkutags demo"
set tg [::tkutils::tkutags::widget .tg -tags {tcl tk} \
    -suggestions {tcl tk gui widget demo} \
    -command {apply {tags {.out configure -text "tags: $tags"}}}]
ttk::label .out -text "tags: [::tkutils::tkutags::getTags $tg]"
grid [ttk::label .lbl -text "labels:"] -sticky w -padx 6 -pady {6 0}
grid .tg -sticky ew -padx 6
grid .out -sticky w -padx 6 -pady {4 6}
grid columnconfigure . 0 -weight 1
vwait forever
