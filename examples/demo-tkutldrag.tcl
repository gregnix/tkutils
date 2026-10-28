#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutldrag -- drag rows with the mouse to set your own order.
# The label shows the order of the row ids after each move.
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} { tcl::tm::path add $::env(TCLUTILS_TM) }

package require Tk
package require tablelist_tile
package require tkutils::tkutldrag

wm title . "tkutldrag demo"
ttk::label .l -textvariable ::orderText
pack .l -fill x
tablelist::tablelist .t -columns {20 Task left 10 Owner left} -stretch all -height 8
foreach {id task owner} {
    t1 "Write spec" Anna  t2 "Review" Bert  t3 "Build" Cora  t4 "Release" Dirk
} {
    .t insert end [list $task $owner]
    .t rowconfigure end -name $id
}
pack .t -fill both -expand 1

proc moved {tbl id parent pos} {
    set ::orderText "moved $id to $pos -- order: [::tkutils::tkutldrag::order $tbl]"
}
::tkutils::tkutldrag::enable .t -command moved
set ::orderText "order: [::tkutils::tkutldrag::order .t]"

if {[lindex $argv 0] eq "--selftest"} {
    puts "selectmode: [.t cget -selectmode], movablerows: [.t cget -movablerows]"
    puts $::orderText
    exit 0
}
