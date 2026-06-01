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
package require tkutils::tkvcard
wm title . "tkvcard demo"
set w [::tkutils::tkvcard::widget .w]
pack $w -fill both -expand 1
set vcf "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alice Smith\r\nEMAIL;TYPE=work:alice@example.com\r\nEMAIL;TYPE=home:alice@home.com\r\nTEL;TYPE=cell:+49 170 1234567\r\nORG:Example GmbH\r\nEND:VCARD\r\nBEGIN:VCARD\r\nVERSION:3.0\r\nFN:Bob Jones\r\nEMAIL:bob@example.com\r\nTEL;TYPE=work:+49 30 9876543\r\nEND:VCARD\r\n"
::tkutils::tkvcard::loadText $w $vcf
vwait forever
