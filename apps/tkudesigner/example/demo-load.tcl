#!/usr/bin/env wish
# Demonstrate tkuload: instantiate a .tkd design in a plain window -- no editor.
#   wish example/demo-load.tcl ?path/to/design.tkd?
package require Tcl 8.6-
package require Tk 8.6-

set here [file dirname [file normalize [info script]]]
source [file join $here .. .. _lib paths.tcl]
package require tkutils::tkuload

set file [lindex $argv 0]
if {$file eq ""} {
    set file [file join $here modern_faktura_complete.tkd]
}

wm title . "tkuload -- [file tail $file]"
# build into a frame (child widget names cannot hang directly off ".")
set host [ttk::frame .host]
pack $host -fill both -expand 1
set ui [::tkuload::buildFromFile $host $file]

puts "loaded [file tail $file]"
puts "  widgets : [dict size [dict get $ui byId]]"
puts "  named   : [dict size [dict get $ui byName]]"
puts "  types   : [lsort -unique [dict keys [dict get $ui byType]]]"
