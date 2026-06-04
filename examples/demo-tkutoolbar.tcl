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
package require tkutils::tkutoolbar
wm title . "tkutoolbar demo"
set tb [::tkutils::tkutoolbar::widget .tb]
pack $tb -side top -fill x
pack [ttk::label .out -anchor w -padding 10 -text "Toolbar demo - click a button"] -fill both -expand 1
::tkutils::tkutoolbar::addButton $tb new  "New"  {.out configure -text "New"}
::tkutils::tkutoolbar::addButton $tb open "Open" {.out configure -text "Open"}
::tkutils::tkutoolbar::addButton $tb save "Save" {.out configure -text "Save"}
::tkutils::tkutoolbar::addSeparator $tb
::tkutils::tkutoolbar::addToggle $tb bold "Bold" ::boldvar
vwait forever
