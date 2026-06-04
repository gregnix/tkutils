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
package require tkutils::tkudialog
wm title . "tkdialog"
pack [ttk::frame .f -padding 16] -fill both -expand 1
ttk::label .f.l -text "Click to open a dialog (message text is copyable):"
grid .f.l -columnspan 2 -sticky w -pady {0 8}
ttk::button .f.i -text "Info"    -command {::tkutils::tkudialog::showInfo "Operation finished.\nYou can select and copy this text."}
ttk::button .f.w -text "Warning" -command {::tkutils::tkudialog::showWarning "Low disk space."}
ttk::button .f.e -text "Error"   -command {::tkutils::tkudialog::showError "Failed to open file." -detail "Traceback:\n  at open()\n  at main()"}
ttk::button .f.c -text "Confirm" -command {::tkutils::tkudialog::confirm "Delete the selected items?"}
ttk::button .f.n -text "Input"   -command {::tkutils::tkudialog::input -message "Your name?"}
grid .f.i .f.w -sticky ew -padx 2 -pady 2
grid .f.e .f.c -sticky ew -padx 2 -pady 2
grid .f.n -sticky ew -padx 2 -pady 2
vwait forever
