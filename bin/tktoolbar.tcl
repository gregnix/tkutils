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
package require tkutils::tktoolbar
wm title . "tktoolbar"
set tb [::tkutils::tktoolbar::widget .tb]
pack $tb -side top -fill x
pack [ttk::label .msg -anchor w -padding 8 -text "Click a toolbar button."] -fill both -expand 1
::tkutils::tktoolbar::addButton $tb new "New"  {.msg configure -text "New clicked"}
::tkutils::tktoolbar::addButton $tb open "Open" {.msg configure -text "Open clicked"}
::tkutils::tktoolbar::addSeparator $tb
::tkutils::tktoolbar::addToggle $tb wrap "Wrap" ::wrapvar
vwait forever
