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
package require tkutils::tkunotes
wm title . "tkunotes demo"
set w [::tkutils::tkunotes::widget .w]
pack $w -fill both -expand 1
set proj [::tkutils::tkunotes::addRoot $w "Project" "Top-level project note" {work}]
::tkutils::tkunotes::addChild $w $proj "Tasks" "- design\n- build\n- test" {todo}
set ideas [::tkutils::tkunotes::addChild $w $proj "Ideas" "brainstorming" {}]
::tkutils::tkunotes::addChild $w $ideas "Idea 1" "use tunotes engine" {}
::tkutils::tkunotes::addRoot $w "Personal" "private notes" {home}
::tkutils::tkunotes::select $w $proj
vwait forever
