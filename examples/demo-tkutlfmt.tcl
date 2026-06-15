#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutlfmt -- per-column display formatting. Cells hold raw
# numbers; the columns show grouped / currency / percent / date strings, while
# sorting still uses the raw values.
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
package require tkutils::tkutlfmt
catch {package require tkutils::tkutlsort}

wm title . "tkutlfmt demo"

tablelist::tablelist .t \
    -columns {0 "Article" left  0 "Price" right  0 "Share" right  0 "Count" right  0 "Date" left} \
    -stretch all -stripebackground #eef -height 8 \
    -labelcommand tablelist::sortByColumn
# raw values
.t insert end [list "Apple"  1234.5  0.125 1234567 1717200000]
.t insert end [list "Pear"      9.9  0.5        42 1718000000]
.t insert end [list "Cherry"  123.45 0.0833    900 1700000000]
pack .t -fill both -expand 1

# display formats
::tkutils::tkutlfmt::columns .t {
    1 currency
    2 percent
    3 integer
    4 date {-outformat %d.%m.%Y}
}
# numeric sorting on the raw values (if tkutlsort present)
catch {::tkutils::tkutlsort::columns .t {1 real 2 real 3 integer 4 integer}}

if {[lindex $argv 0] eq "--selftest"} {
    update idletasks
    foreach r {0 1 2} { puts "shown: [.t getformatted $r]" }
    exit 0
}
