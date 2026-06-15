#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutlfooter -- a synced footer row for a tablelist, with
# auto-sums (numbers parsed via tclutils::tunum).
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir

# locate the tclutils dependency for in-tree/dev use
# (installed systems already have tclutils on the module path)
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
package require tkutils::tkutlfooter

wm title . "tkutlfooter demo"

# --- main table ---
tablelist::tablelist .t \
    -columns {0 "Article" left  0 "Qty" right  0 "Price" right} \
    -stretch all -stripebackground #eef -height 8
.t insert end {Apple   3 "1,50"}
.t insert end {Pear    5 "2,00"}
.t insert end {Cherry 12 "4,20"}
.t insert end {Plum    7 "3,10"}

# --- footer table (one row, no labels) ---
tablelist::tablelist .f -showlabels 0 -height 1 \
    -columns {0 {} left 0 {} right 0 {} right}

grid .t -row 0 -column 0 -sticky nsew
grid .f -row 1 -column 0 -sticky ew
grid rowconfigure    . 0 -weight 1
grid columnconfigure . 0 -weight 1

# --- attach footer + auto-sum the Qty and Price columns ---
::tkutils::tkutlfooter::attach  .t .f
::tkutils::tkutlfooter::autosum .t .f -columns {1 2} -label "Sum:" -format "%.2f"

# Re-sum whenever a cell is edited (demo only)
bind .t <<TablelistCellUpdated>> {
    ::tkutils::tkutlfooter::autosum .t .f -columns {1 2} -label "Sum:" -format "%.2f"
}

# headless self-test: print the footer row and exit
if {[lindex $argv 0] eq "--selftest"} {
    update idletasks
    puts "footer: [.f get 0]"
    exit 0
}
