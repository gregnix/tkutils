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
package require tkutils::tktree
wm title . "tktree demo"
set tr [::tkutils::tktree::widget .tr -columns {kind} -headings {Name Kind} -height 10 \
    -command {apply {sel {.out configure -text "selected: $sel"}}}]
::tkutils::tktree::loadTree $tr {
    {id docs text Documents open 1 values {folder} children {
        {id r1 text report.odt values {file}}
        {id r2 text notes.md   values {file}}}}
    {id media text Media values {folder} children {
        {id m1 text photo.png values {file}}}}
}
ttk::label .out -text "selected: (none)"
grid .tr -sticky nsew -padx 6 -pady 6
grid .out -sticky w -padx 6 -pady {0 6}
grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1
vwait forever
