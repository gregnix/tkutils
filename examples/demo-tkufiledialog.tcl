#!/usr/bin/env wish
# demo-tkufiledialog.tcl -- smoke the three choosers
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    foreach c [glob -nocomplain [file join [file dirname [file dirname $here]] tclutils*/lib/tm]] {
        tcl::tm::path add $c
        break
    }
}
package require tkutils::tkufiledialog 0.3

wm title . "tkufiledialog demo"
ttk::frame .f -padding 12
pack .f -fill both -expand 1
ttk::label .f.l -textvariable ::demoMsg -wraplength 360
set ::demoMsg "Choose open / save / folder. Bookmarks, recent folders and the\
view are kept for the application \"tkufiledialog-demo\" (-app)."
pack .f.l -fill x -pady {0 8}
ttk::button .f.open -text Open -command {
    set r [::tkutils::tkufiledialog::open -parent . -app tkufiledialog-demo \
        -filetypes {{Text {.txt .md}} {Tcl {.tcl .tm}} {All *}}]
    set ::demoMsg "open → $r"
}
ttk::button .f.save -text Save -command {
    set r [::tkutils::tkufiledialog::save -parent . -app tkufiledialog-demo \
        -initialfile out.txt -defaultextension .txt]
    set ::demoMsg "save → $r"
}
ttk::button .f.dir -text Folder -command {
    set r [::tkutils::tkufiledialog::directory -parent . -app tkufiledialog-demo]
    set ::demoMsg "directory → $r"
}
pack .f.open .f.save .f.dir -side left -padx 4
