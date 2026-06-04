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
package require tkutils::tkuldif
wm title . "tkuldif demo"
set w [::tkutils::tkuldif::widget .w]
pack $w -fill both -expand 1
set ldif "dn: cn=Alice Smith,dc=example,dc=com\ncn: Alice Smith\nsn: Smith\nmail: alice@example.com\nmail: a.smith@example.com\ntelephoneNumber: +49 123\n\ndn: cn=Bob Jones,dc=example,dc=com\ncn: Bob Jones\nsn: Jones\nmail: bob@example.com\n"
::tkutils::tkuldif::loadText $w $ldif
vwait forever
