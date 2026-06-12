#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _r [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_r] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c; break
    }
}
package require tkutils::tkukeynav
wm title . "tkukeynav demo"

pack [ttk::label .hint -padding 8 -anchor w -text \
    "Type and press Return to walk fields; Return on the last field submits.\
    \nTab/Shift-Tab also navigate. Escape clears."] -fill x

set form [ttk::frame .form -padding 8]
pack $form -fill x
set i 0
foreach {key label} {name "Name:" email "Email:" phone "Phone:"} {
    ttk::label $form.l$key -text $label
    ttk::entry $form.$key -width 30
    grid $form.l$key -row $i -column 0 -sticky w -padx 4 -pady 3
    grid $form.$key  -row $i -column 1 -sticky ew -padx 4 -pady 3
    incr i
}
grid columnconfigure $form 1 -weight 1

pack [ttk::label .out -padding 8 -anchor w -text "(not submitted)"] -fill x

# Return walks fields; last field submits; Escape clears every field.
::tkutils::tkukeynav::form .form \
    -onsubmit {
        .out configure -text "Submitted: [.form.name get] / [.form.email get] / [.form.phone get]"
    } \
    -onescape {
        foreach k {name email phone} { .form.$k delete 0 end }
        .out configure -text "(cleared)"
    }

focus -force .form.name
vwait forever
