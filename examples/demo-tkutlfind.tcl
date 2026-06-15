#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutlfind -- incremental find with highlight. Type in the box
# to highlight matches; Enter / F3 jumps to the next match, Shift-F3 to prev.
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir

package require Tk
package require tablelist
package require tkutils::tkutlfind

wm title . "tkutlfind demo"

frame .top
label .top.l -text "Find:"
entry .top.e -textvariable ::q -width 24
label .top.n -textvariable ::status
button .top.next -text "Next" -command { ::tkutils::tkutlfind::next .t }
button .top.prev -text "Prev" -command { ::tkutils::tkutlfind::prev .t }
pack .top.l .top.e .top.prev .top.next .top.n -side left -padx 3
pack .top -fill x -pady 3

tablelist::tablelist .t \
    -columns {0 "Article" left  0 "Category" left} \
    -stretch all -stripebackground #eef -height 10
foreach row {
    {Apple Fruit} {Pear Fruit} {Carrot Vegetable} {Apple juice Drink}
    {Apricot Fruit} {Cabbage Vegetable} {Pineapple Fruit} {Water Drink}
} { .t insert end $row }
pack .t -fill both -expand 1

proc doFind {} {
    set ::status "[::tkutils::tkutlfind::find .t $::q] match(es)"
}
bind .top.e <KeyRelease> doFind
bind .top.e <Return>     { ::tkutils::tkutlfind::next .t }
bind . <F3>       { ::tkutils::tkutlfind::next .t }
bind . <Shift-F3> { ::tkutils::tkutlfind::prev .t }

if {[lindex $argv 0] eq "--selftest"} {
    set ::q apple
    doFind
    puts "matches for 'apple': [::tkutils::tkutlfind::matches .t]"
    puts "status: $::status"
    exit 0
}
