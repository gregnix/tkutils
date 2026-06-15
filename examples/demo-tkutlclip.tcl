#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutlclip -- copy tablelist rows to the clipboard.
# Select rows and press Ctrl+C (TSV), or use the buttons. Paste into a
# spreadsheet or text editor to see the result.
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir

if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain \
            [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}

package require Tk
package require tablelist
package require tkutils::tkutlclip

wm title . "tkutlclip demo"

tablelist::tablelist .t \
    -columns {0 "Article" left  0 "Qty" right  0 "Price" right} \
    -stretch all -selectmode extended -stripebackground #eef -height 8
.t insert end [list "Apple"        3 "1,50 \u20AC"]
.t insert end [list "Pear, small"  5 "2,00 \u20AC"]
.t insert end [list "Cherry"      12 "4,20 \u20AC"]
.t insert end [list "Plum"         7 "3,10 \u20AC"]

frame .b
button .b.tsv -text "Copy all (TSV)" \
    -command {::tkutils::tkutlclip::copyAll .t -header 1 -format tsv}
button .b.csv -text "Copy all (CSV)" \
    -command {::tkutils::tkutlclip::copyAll .t -header 1 -format csv}
label  .b.hint -text "Select rows + Ctrl+C, or use the buttons; then paste."
pack .b.tsv .b.csv .b.hint -side left -padx 4

pack .t -fill both -expand 1
pack .b -fill x -pady 4

# Ctrl+C copies the selection as TSV
::tkutils::tkutlclip::installBindings .t

if {[lindex $argv 0] eq "--selftest"} {
    puts [::tkutils::tkutlclip::asText .t {0 1 2 3} -header 1 -format csv]
    exit 0
}
