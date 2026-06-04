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
package require tkutils::tkuical
wm title . "tkuical demo"
set w [::tkutils::tkuical::widget .w]
pack $w -fill both -expand 1
set ics "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nSUMMARY:Team standup\r\nDTSTART:20260601T090000\r\nDTEND:20260601T091500\r\nLOCATION:Online\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nSUMMARY:Release review\r\nDTSTART:20260601T140000\r\nLOCATION:Room 2\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
::tkutils::tkuical::loadText $w $ics
vwait forever
