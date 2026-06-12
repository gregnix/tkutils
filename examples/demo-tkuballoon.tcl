#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
package require tkutils::tkuballoon
wm title . "tkuballoon demo"

set ns ::tkutils::tkuballoon

pack [ttk::label .info -padding 8 -text \
    "Hover over the controls to see balloon help."] -anchor w

set f [ttk::frame .f -padding 8]
pack $f -fill x
foreach {name text help} {
    new   "New"   "Create a new document"
    open  "Open"  "Open an existing file from disk"
    save  "Save"  "Write the current document to disk (Ctrl+S)"
} {
    set b [ttk::button $f.$name -text $text]
    pack $b -side left -padx 4
    $ns\::add $b $help
}

set e [ttk::entry .e -width 30]
pack $e -padx 8 -pady 4 -anchor w
$ns\::add $e "Type a file name here. This balloon wraps long text onto\
 several lines once it passes the configured wrap length." -wraplength 220

# Live controls: hover delay and global enable/disable.
set ctl [ttk::frame .ctl -padding 8]
pack $ctl -fill x
ttk::label $ctl.dl -text "Delay (ms):"
ttk::scale $ctl.ds -from 0 -to 1500 -value [$ns\::cget -delay] \
    -command {apply {{v} {::tkutils::tkuballoon::configure -delay [expr {int($v)}]}}}
ttk::checkbutton $ctl.en -text "Balloons enabled" -variable ::en \
    -command {if {$::en} {::tkutils::tkuballoon::enable} else {::tkutils::tkuballoon::disable}}
set ::en 1
grid $ctl.dl $ctl.ds $ctl.en -sticky w -padx 4
grid columnconfigure $ctl 1 -weight 1
$ns\::add $ctl.ds "New delay applies to balloons added afterwards"

vwait forever
