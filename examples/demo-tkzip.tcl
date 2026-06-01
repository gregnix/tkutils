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
package require tkutils::tkzip
package require tclutils::tuzip
wm title . "tkzip demo"
set w [::tkutils::tkzip::widget .w]
pack $w -fill both -expand 1
# build a small demo archive on the fly
set d [file join [file dirname [info script]] _demo_zip]
file mkdir $d
foreach {n c} {readme.txt "hello world" data.csv "a,b,c\n1,2,3" notes.md "# Notes"} {
    ::tclutils::common::writeFile [file join $d $n] $c
}
set zip [file join $d demo.zip]
::tclutils::tuzip::create $zip [list [file join $d readme.txt] [file join $d data.csv] [file join $d notes.md]]
::tkutils::tkzip::openFile $w $zip
vwait forever
