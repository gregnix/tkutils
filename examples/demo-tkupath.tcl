#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require Tk
package require tkutils::tkupath

wm title . "tkupath demo"
wm geometry . 560x120

ttk::label .info -text "Click a segment to navigate to that ancestor" -anchor w
set ::where ""
ttk::label .where -textvariable ::where -anchor w -foreground "#1565c0"

::tkutils::tkupath::widget .bar \
    -onnavigate {apply {p {
        ::tkutils::tkupath::setPath .bar $p
        set ::where "navigated to: $p"
    }}}

grid .info -sticky ew -padx 8 -pady {8 0}
grid .bar  -sticky ew -padx 8 -pady 8
grid .where -sticky ew -padx 8 -pady {0 8}
grid columnconfigure . 0 -weight 1

::tkutils::tkupath::setPath .bar [expr {$argc ? [lindex $argv 0] : [pwd]}]
