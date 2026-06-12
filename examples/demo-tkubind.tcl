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
package require tkutils::tkubind
wm title . "tkubind demo"

set ns ::tkutils::tkubind

pack [ttk::label .p -padding 8 -text \
    "Platform modifier: [$ns\::platform modKey]   ([$ns\::platform modSymbol])"] -anchor w
pack [ttk::label .out -padding 8 -text "Press Ctrl/Cmd+S, +O, or +Q ..."] -anchor w -fill x

# Global shortcuts -- shown via their accelerator strings.
foreach {spec label} {Mod-s Save Mod-o Open Mod-q Quit} {
    $ns\::key $spec [list .out configure -text "$label  ([$ns\::accelerator $spec])"]
}
# Quit really quits.
$ns\::key Mod-q { after 50 exit }

# The isEditing guard: type in this entry; plain letters do NOT trigger the
# global "Delete" handler, but Ctrl+S still saves.
pack [ttk::label .l2 -padding {8 8 8 0} -anchor w -text \
    "Focus the entry and type -- editing is detected, plain keys stay local:"]
set e [ttk::entry .e -width 40]
pack $e -padx 8 -pady 4 -anchor w
$ns\::key Delete {.out configure -text "Delete pressed (only outside edit widgets)"} \
    -skipClasses {TEntry Entry Text}

pack [ttk::label .ed -padding 8 -anchor w -textvariable ::edstate]
proc refresh {} { set ::edstate "isEditing = [::tkutils::tkubind::isEditing]" ; after 200 refresh }
refresh

# A toggleable binding group.
pack [ttk::checkbutton .grp -padding 8 -text "Enable Bold/Italic group (Ctrl+B / Ctrl+I)" \
    -variable ::grpOn -command {
        if {$::grpOn} { ::tkutils::tkubind::group enable fmt } \
        else          { ::tkutils::tkubind::group disable fmt }
    }] -anchor w
$ns\::group define fmt {
    {Mod-b {.out configure -text "Bold"}}
    {Mod-i {.out configure -text "Italic"}}
}

focus -force .
vwait forever
