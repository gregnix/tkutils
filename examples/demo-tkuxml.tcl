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
package require tkutils::tkuxml
wm title . "tkuxml demo"
set w [::tkutils::tkuxml::widget .w]
pack $w -fill both -expand 1
set xml {<library><book id="1"><title>Tcl</title><author>Ousterhout</author></book><book id="2"><title>Tk</title></book></library>}
::tkutils::tkuxml::setXml $w $xml
vwait forever
