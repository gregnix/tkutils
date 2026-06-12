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
package require tkutils::tkucontextmenu
wm title . "tkucontextmenu demo"

set ns ::tkutils::tkucontextmenu

pack [ttk::label .hint -padding 8 -text \
    "Right-click the list or the text area below."] -anchor w
pack [ttk::label .out -padding 8 -text "(no action yet)"] -anchor w -fill x

# A listbox with a spec-built context menu (command + check + submenu).
set lb [listbox .lb -height 6]
foreach x {Apple Banana Cherry Date Elderberry} { $lb insert end $x }
pack $lb -fill both -expand 1 -padx 8 -pady 4

$ns\::createFromSpec .lb.menu {
    {"Add row"    {.out configure -text "Add row"}    -accelerator "Ctrl+N"}
    {"Delete row" {.out configure -text "Delete row"} -accelerator "Del"}
    -
    {check "Show details" -variable ::showDetails -command {.out configure -text "details=$::showDetails"}}
    {submenu "Sort" {
        {"Ascending"  {.out configure -text "Sort ascending"}}
        {"Descending" {.out configure -text "Sort descending"}}
    }}
}
$ns\::attach .lb.menu $lb

# A text widget with a standard edit menu.
set txt [text .txt -height 5 -width 40]
$txt insert end "Right-click here for Cut/Copy/Paste."
pack $txt -fill both -expand 1 -padx 8 -pady 4

set edit [$ns\::createStandardEdit .txt.menu \
    -cutcmd   {.out configure -text "Cut"} \
    -copycmd  {.out configure -text "Copy"} \
    -pastecmd {.out configure -text "Paste"} \
    -selectall {.out configure -text "Select All"}]
$ns\::attach .txt.menu $txt

vwait forever
