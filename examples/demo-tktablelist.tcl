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
package require tkutils::tktablelist
wm title . "tktablelist demo"
set w [::tkutils::tktablelist::widget .w -titlecolumns 1 -editable 1 -stripes "#eef3fb"]
pack $w -fill both -expand 1
set csv "Name,Age,City\nAlice,30,Berlin\nBob,25,Munich\nCarol,41,Hamburg\nDave,19,Bremen\n"
::tkutils::tktablelist::loadCsv $w $csv
::tkutils::tktablelist::configureColumn $w 1 -sortmode integer -align right
pack [ttk::label .hint -padding 6 -anchor w     -text "Click a header to sort. Double-click a cell to edit (Age sorts numerically)."] -side bottom -fill x
vwait forever
