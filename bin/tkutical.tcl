#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    foreach _c [lsort -decreasing [glob -nocomplain \
            [file join [file dirname [file dirname $here]] tical*/lib] \
            [file join [file dirname [file dirname $here]] tical*]]] {
        lappend auto_path $_c
    }
}
package require tkutils::tkutical

wm title . "tkutical"
set ::view month

ttk::frame .top
ttk::label .top.l -text "View:"
ttk::radiobutton .top.m -text month -variable ::view -value month \
    -command {::tkutils::tkutical::setView .w month}
ttk::radiobutton .top.w -text week -variable ::view -value week \
    -command {::tkutils::tkutical::setView .w week}
pack .top.l .top.m .top.w -side left -padx 3 -pady 3
pack .top -side top -fill x

set w [::tkutils::tkutical::widget .w -view $::view -selectmode multiple \
    -command {apply {{p sel} {.status configure -text \
        "[llength $sel] selected: $sel"}}}]
pack $w -fill both -expand 1

label .status -text "Click to select; Shift-click for a range" -anchor w
pack .status -side bottom -fill x

if {[llength $argv] >= 1} { ::tkutils::tkutical::setDate .w [lindex $argv 0] }
vwait forever
