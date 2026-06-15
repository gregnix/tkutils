#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require Tk
package require tkutils::tkufiletree

set start [expr {$argc ? [lindex $argv 0] : [pwd]}]

wm title . "tkufiletree demo"
ttk::label .info -text "Double-click an image file to select it" -anchor w
set ::picked ""
ttk::label .picked -textvariable ::picked -anchor w -foreground "#1565c0"

set t [::tkutils::tkufiletree::widget .tree \
    -root $start -filter {*.png *.jpg *.jpeg *.gif *.bmp *.svg} \
    -onactivate {apply {p {set ::picked "picked: $p"}}}]

grid .info  -sticky ew -padx 6 -pady {6 0}
grid .tree  -sticky nsew -padx 6 -pady 6
grid .picked -sticky ew -padx 6 -pady {0 6}
grid rowconfigure    . 1 -weight 1
grid columnconfigure . 0 -weight 1
