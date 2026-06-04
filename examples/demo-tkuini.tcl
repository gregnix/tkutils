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
package require tkutils::tkuini
wm title . "tkuini demo"
set w [::tkutils::tkuini::widget .w]
pack $w -fill both -expand 1
set ini "app = demo\nversion = 1.0\n\[window\]\nwidth = 800\nheight = 600\n\[paths\]\ndata = /var/data\ncache = /tmp/cache\n"
::tkutils::tkuini::loadText $w $ini
vwait forever
