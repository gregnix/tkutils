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
package require tkutils::tkudiff

wm title . "tkudiff demo"
set w [::tkutils::tkudiff::widget .w]
pack $w -fill both -expand 1
set old "line one\nline two\nline three\nshared\n"
set new "line one\nline TWO changed\nline three\nshared\nadded line\n"
::tkutils::tkudiff::setTexts $w $old $new
vwait forever
