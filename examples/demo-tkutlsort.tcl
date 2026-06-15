#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutlsort -- type-aware column sorting (numeric/currency via
# tclutils::tunum). Click a column label to sort; the Price column sorts
# numerically instead of as text.
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
package require tkutils::tkutlsort

wm title . "tkutlsort demo"

tablelist::tablelist .t \
    -columns {0 "Article" left  0 "Price" right  0 "Qty" right} \
    -stretch all -stripebackground #eef -height 8 \
    -labelcommand tablelist::sortByColumn
.t insert end [list "Apple"   "9,90 \u20AC"     3]
.t insert end [list "Pear"    "10,00 \u20AC"    5]
.t insert end [list "Cherry"  "1.234,56 \u20AC" 12]
.t insert end [list "Plum"    "2,50 \u20AC"     7]
.t insert end [list "Mango"   "100,00 \u20AC"   1]
pack .t -fill both -expand 1

# Article = text, Price = currency (numeric), Qty = integer
::tkutils::tkutlsort::columns .t {0 string  1 num  2 integer}

if {[lindex $argv 0] eq "--selftest"} {
    .t sortbycolumn 1 -increasing
    puts "price asc: [lmap r [.t get 0 end] {lindex $r 1}]"
    exit 0
}
