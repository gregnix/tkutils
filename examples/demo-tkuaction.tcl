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
package require tkutils::tkuaction
package require tkutils::tkutoolbar
wm title . "tkuaction demo"

set act ::tkutils::tkuaction
set out [ttk::label .out -padding 8 -anchor w -text "(no action yet)"]

# Define actions once.
$act\::define save  -label "Save"  -command {.out configure -text "Save"}  -accelerator "Ctrl+S"
$act\::define print -label "Print" -command {.out configure -text "Print"}
$act\::define wrap  -label "Wrap"  -checkable 1 \
    -command {.out configure -text "Wrap = [::tkutils::tkuaction::getChecked wrap]"}

# A toolbar built from those actions.
set tb [::tkutils::tkutoolbar::widget .tb]
pack $tb -side top -fill x
::tkutils::tkutoolbar::addAction $tb save
::tkutils::tkutoolbar::addAction $tb print
::tkutils::tkutoolbar::addSeparator $tb
::tkutils::tkutoolbar::addAction $tb wrap
pack $out -fill x

# A second set of widgets bound to the SAME actions -- they stay in sync.
set f [ttk::labelframe .f -text "Same actions, different widgets" -padding 8]
pack $f -fill x -padx 8 -pady 8
ttk::button $f.save  -text "Save"  -command {::tkutils::tkuaction::invoke save}
ttk::button $f.print -text "Print" -command {::tkutils::tkuaction::invoke print}
pack $f.save $f.print -side left -padx 4
$act\::register save  $f.save
$act\::register print $f.print

# Controls that drive the actions' shared state.
set c [ttk::frame .c -padding 8]
pack $c -fill x
ttk::checkbutton $c.en -text "Printing available" -variable ::canPrint -command {
    ::tkutils::tkuaction::setEnabled print $::canPrint
}
set ::canPrint 1
ttk::button $c.tg -text "Toggle Wrap programmatically" -command {
    ::tkutils::tkuaction::toggle wrap
}
$act\::groupDefine docActions {save print}
ttk::button $c.dis -text "Disable all (group)" -command {
    ::tkutils::tkuaction::groupSet docActions 0
}
pack $c.en $c.tg $c.dis -side left -padx 4

vwait forever
