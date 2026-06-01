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
wm title . "tktoolbar demo"
set tb [::tkutils::tktoolbar::widget .tb]
pack $tb -side top -fill x
pack [ttk::label .out -anchor w -padding 10 -text "Toolbar demo - click a button"] -fill both -expand 1
::tkutils::tktoolbar::addButton $tb new  "New"  {.out configure -text "New"}
::tkutils::tktoolbar::addButton $tb open "Open" {.out configure -text "Open"}
::tkutils::tktoolbar::addButton $tb save "Save" {.out configure -text "Save"}
::tkutils::tktoolbar::addSeparator $tb
::tkutils::tktoolbar::addToggle $tb bold "Bold" ::boldvar
vwait forever
