#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutltools -- one require pulls in the whole tablelist family.
# This builds a table that uses sort + format + footer + clipboard together.
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
        tcl::tm::path add $_c; break
    }
}

package require Tk
package require tkutils::tkutltools

wm title . "tkutltools demo"

tablelist::tablelist .t \
    -columns {0 "Article" left  0 "Qty" right  0 "Price" right} \
    -stretch all -stripebackground #eef -height 8 \
    -labelcommand tablelist::sortByColumn
.t insert end [list "Apple"  3 1.50]
.t insert end [list "Pear"   5 2.00]
.t insert end [list "Cherry" 12 4.20]
tablelist::tablelist .f -showlabels 0 -height 1 -columns {0 {} left 0 {} right 0 {} right}
pack .t -fill both -expand 1
pack .f -fill x

# sort numerically, format as currency, footer sum, Ctrl+C copy
::tkutils::tkutlsort::columns .t {0 string 1 integer 2 real}
::tkutils::tkutlfmt::column   .t 2 currency
::tkutils::tkutlfooter::attach  .t .f
::tkutils::tkutlfooter::autoagg .t .f -columns {1 sum 2 sum} -label "Σ" -format %g
::tkutils::tkutlclip::installBindings .t

if {[lindex $argv 0] eq "--selftest"} {
    update idletasks
    puts "family loaded; footer: [.f get 0]"
    exit 0
}
