#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutlstate -- save/restore a tablelist's column layout.
# Resize/hide/sort columns, click "Save", mess it up, then "Restore".
# A file roundtrip is shown via "Save file" / "Load file".
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir

package require Tk
package require tablelist
package require tkutils::tkutlstate

wm title . "tkutlstate demo"
set ::stateFile [file join [pwd] tablelist-demo.state]
set ::saved {}

tablelist::tablelist .t \
    -columns {0 "A" left 0 "B" right 0 "C" left 0 "D" right} \
    -stretch all -stripebackground #eef -height 8 \
    -labelcommand tablelist::sortByColumn
foreach r {{1 2 3 4} {5 6 7 8} {9 10 11 12} {13 14 15 16}} { .t insert end $r }

frame .b
button .b.save  -text "Save"      -command { set ::saved [::tkutils::tkutlstate::save .t] }
button .b.rest  -text "Restore"   -command { if {$::saved ne ""} {::tkutils::tkutlstate::restore .t $::saved} }
button .b.sf    -text "Save file" -command { ::tkutils::tkutlstate::saveToFile .t $::stateFile }
button .b.lf    -text "Load file" -command { ::tkutils::tkutlstate::restoreFromFile .t $::stateFile }
pack .b.save .b.rest .b.sf .b.lf -side left -padx 3
pack .t -fill both -expand 1
pack .b -fill x -pady 4

if {[lindex $argv 0] eq "--selftest"} {
    .t columnconfigure 0 -width 18
    .t columnconfigure 2 -hide 1
    .t sortbycolumn 1 -decreasing
    set s [::tkutils::tkutlstate::save .t]
    .t columnconfigure 0 -width 6; .t columnconfigure 2 -hide 0
    ::tkutils::tkutlstate::restore .t $s
    puts "restored: w0=[.t columncget 0 -width] hide2=[.t columncget 2 -hide] sort=[.t sortcolumn]/[.t sortorder]"
    exit 0
}
