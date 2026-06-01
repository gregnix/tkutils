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
package require tkutils::tkjson

wm title . "tkjson demo"
set w [::tkutils::tkjson::widget .w]
pack $w -fill both -expand 1
set json {{"app":"demo","version":3,"enabled":true,"tags":["a","b","c"],"author":{"name":"Greg","city":"Vreden"},"notes":null}}
::tkutils::tkjson::setJson $w $json
vwait forever
