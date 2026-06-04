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
package require tkutils::tkuform
wm title . "tkuform demo"
set spec {
    {name title   label "Title"    type entry default "My note"}
    {name tags    label "Tags"     type entry default "work todo"}
    {name priority label "Priority" type combo values {low normal high} default normal}
    {name done    label "Done"     type check default 0}
    {name body    label "Body"     type text height 5 default "Write here..."}
}
set w [::tkutils::tkuform::widget .w $spec]
pack $w -fill both -expand 1
pack [ttk::button .b -text "Collect" -command {
    set v [::tkutils::tkuform::values .w]
    wm title . "tkuform demo - [dict get $v title]"
}] -pady 6
vwait forever
