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
package require tkutils::tkustatus
wm title . "tkustatus demo"
pack [ttk::frame .body -width 360 -height 120] -fill both -expand 1
ttk::button .body.f -text "Flash 'Saved.'" -command {::tkutils::tkustatus::flash .st "Saved." 1500}
ttk::button .body.p -text "Progress 75%" -command {::tkutils::tkustatus::progress .st 75}
pack .body.f .body.p -pady 6
set st [::tkutils::tkustatus::widget .st]
pack $st -side bottom -fill x
::tkutils::tkustatus::addField $st pos -width 14
::tkutils::tkustatus::setField $st pos "Ln 1, Col 1"
::tkutils::tkustatus::setText $st "Ready"
vwait forever
