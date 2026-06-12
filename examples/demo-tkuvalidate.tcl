#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _r [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_r] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c; break
    }
}
package require tkutils::tkuvalidate
wm title . "tkuvalidate demo"

pack [ttk::label .hint -padding 8 -anchor w -text \
    "Invalid fields turn red on focus-out; hover to read why. Press Check."] -fill x

set f [ttk::frame .f -padding 8]
pack $f -fill x
set i 0
foreach {key label} {email "Email:" age "Age:" host "IPv4:"} {
    ttk::label $f.l$key -text $label -width 8 -anchor w
    ttk::entry $f.$key -width 30
    grid $f.l$key -row $i -column 0 -sticky w -pady 3 -padx 4
    grid $f.$key  -row $i -column 1 -sticky ew -pady 3 -padx 4
    incr i
}
grid columnconfigure $f 1 -weight 1

::tkutils::tkuvalidate::attach $f.email email   -message "Enter a valid e-mail (name@host.tld)"
::tkutils::tkuvalidate::attach $f.age   integer -message "Whole numbers only" -allowempty 0
::tkutils::tkuvalidate::attach $f.host  ipv4    -message "Dotted IPv4, e.g. 192.168.0.1"

pack [ttk::label .out -padding 8 -anchor w -text ""] -fill x
pack [ttk::button .check -text "Check all" -command {
    if {[::tkutils::tkuvalidate::allValid {.f.email .f.age .f.host}]} {
        .out configure -text "All valid."
    } else {
        .out configure -text "Some fields are invalid (see red entries)."
    }
}] -pady 6

vwait forever
