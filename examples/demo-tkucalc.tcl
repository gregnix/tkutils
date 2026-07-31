#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require Tk
package require tkutils::tkucalc

# A calculator. Click the buttons or type; Enter evaluates, Escape clears.
# The last result is echoed below to show the -onresult hook.

wm title . "tkucalc demo"
wm geometry . 300x520
set ::last "type or click, then ="
::tkutils::tkucalc::widget .calc -history 1 -onresult {apply {{r} {set ::last "= $r"}}}
ttk::label .last -textvariable ::last -anchor w -foreground "#1565c0"

pack .calc -fill both -expand 1 -padx 6 -pady 6
pack .last -fill x -padx 6 -pady {0 6}
