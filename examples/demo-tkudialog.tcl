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
wm title . "tkudialog demo"
pack [ttk::frame .f -padding 16] -fill both -expand 1
ttk::button .f.b1 -text "Info"    -command {::tkutils::tkudialog::showInfo "Build succeeded.\n(Select and copy this text.)"}
ttk::button .f.b2 -text "Error+Detail" -command {::tkutils::tkudialog::showError "Compilation failed." -detail "main.c:42: undefined reference to 'foo'\nmain.c:50: note: in expansion"}
ttk::button .f.b3 -text "Confirm" -command {::tkutils::tkudialog::confirm "Overwrite existing file?"}
ttk::button .f.b4 -text "Input"   -command {::tkutils::tkudialog::input -message "Project name?" -initial "untitled"}
pack .f.b1 .f.b2 .f.b3 .f.b4 -fill x -pady 2
vwait forever
