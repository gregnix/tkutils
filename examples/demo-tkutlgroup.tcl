#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutlgroup -- flat orders grouped by customer, with sums of
# quantity and amount in the customer row. Click a header to sort; the
# groups stay together.
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} { tcl::tm::path add $::env(TCLUTILS_TM) }

package require Tk
package require tablelist_tile
package require tkutils::tkutlgroup

wm title . "tkutlgroup demo"
set orders {
    {{Tämo GmbH} Schrauben 100 200,00}
    {{Quarz KG}  Muttern    50  50,00}
    {{Tämo GmbH} Dübel      20  60,50}
    {{Quarz KG}  Schrauben  10  20,00}
    {{Sufra AG}  Muttern    30  30,00}
}
tablelist::tablelist .t -treecolumn 0 -stretch all -height 12 \
    -labelcommand tablelist::sortByColumn \
    -columns {16 Customer left 12 Article left 6 Qty right 10 Amount right 4 N right}
.t columnconfigure 2 -sortmode integer
pack .t -fill both -expand 1

::tkutils::tkutlgroup::group .t $orders 0 -sum {2 3} -count 4

if {[lindex $argv 0] eq "--selftest"} {
    foreach k [.t childkeys root] { puts [.t get $k] }
    puts "flat rows: [llength [::tkutils::tkutlgroup::ungroup .t]]"
    exit 0
}
