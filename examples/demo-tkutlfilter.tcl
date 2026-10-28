#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutlfilter -- type into the entry; rows that do not match
# are hidden (after a short pause). The rows stay in the table.
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} { tcl::tm::path add $::env(TCLUTILS_TM) }

package require Tk
package require tablelist_tile
package require tkutils::tkutlfilter

wm title . "tkutlfilter demo"
ttk::frame .f
ttk::label .f.l -text "Filter:"
ttk::entry .f.e -textvariable ::q
ttk::label .f.n -textvariable ::count
pack .f.l .f.e .f.n -side left -padx 4
pack .f -fill x

tablelist::tablelist .t -columns {14 Name left 12 City left 6 Age right} \
    -stretch all -height 10
.t insertlist end {
    {Anna Berlin 34} {Bert Bonn 51} {Cora Berlin 28} {Dirk Essen 45}
    {Eva Hamburg 39} {Falk Bonn 23} {Gina Essen 61}
}
pack .t -fill both -expand 1

set ::count "[.t size] rows"
bind .f.e <KeyRelease> {::tkutils::tkutlfilter::later .t 300 $::q}
bind .t <<TkutlFilterApplied>> {
    set ::count "[llength [.t getfullkeys 0 end -viewable]] of [.t size] rows"
}

if {[lindex $argv 0] eq "--selftest"} {
    puts "matches: [::tkutils::tkutlfilter::filter .t bonn]"
    puts "visible: [lmap r [.t get 0 end -viewable] {lindex $r 0}]"
    ::tkutils::tkutlfilter::clear .t
    puts "after clear: [llength [.t get 0 end -viewable]]"
    exit 0
}
