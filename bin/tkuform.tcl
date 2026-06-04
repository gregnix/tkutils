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
wm title . "tkform"
set spec {
    {name name  label "Name"  type entry}
    {name email label "Email" type entry}
    {name admin label "Admin" type check}
    {name role  label "Role"  type combo values {guest user admin} default user}
}
set w [::tkutils::tkuform::widget .w $spec]
pack $w -fill both -expand 1
pack [ttk::button .ok -text "Show values"     -command {puts [::tkutils::tkuform::values .w]}] -pady 6
vwait forever
