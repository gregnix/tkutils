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
package require tkutils::tkutoolbar
wm title . "tkutoolbar demo (0.2)"

set out [ttk::label .out -anchor w -padding 10 -text "Toolbar demo - click a button"]

# Main toolbar: buttons, separator, toggle, dropdown, tooltips, shortcut.
set tb [::tkutils::tkutoolbar::widget .tb]
pack $tb -side top -fill x
pack $out -fill both -expand 1

::tkutils::tkutoolbar::addButton $tb new  "New"  {.out configure -text "New"} \
    -tooltip "Create a new document (Ctrl+N)" -shortcut "Control-n"
::tkutils::tkutoolbar::addButton $tb open "Open" {.out configure -text "Open"} \
    -tooltip "Open a document (Ctrl+O)" -shortcut "Control-o"
::tkutils::tkutoolbar::addButton $tb save "Save" {.out configure -text "Save"} \
    -tooltip "Save (Ctrl+S)" -shortcut "Control-s"
::tkutils::tkutoolbar::addSeparator $tb
::tkutils::tkutoolbar::addToggle $tb bold "Bold" ::boldvar \
    -command {.out configure -text "Bold = $::boldvar"}
::tkutils::tkutoolbar::addDropdown $tb fmt "Format" -tooltip "Formatting options" -menu {
    {"Heading 1" {.out configure -text "Heading 1"}}
    {"Heading 2" {.out configure -text "Heading 2"}}
    -
    {"Body text" {.out configure -text "Body text"}}
}

# A second toolbar to demonstrate live display-mode switching.
set ctl [::tkutils::tkutoolbar::widget .ctl]
pack $ctl -side bottom -fill x
foreach m {both text icon} {
    ::tkutils::tkutoolbar::addButton $ctl mode$m "Show: $m" \
        [list ::tkutils::tkutoolbar::setDisplayMode $tb $m]
}

vwait forever
