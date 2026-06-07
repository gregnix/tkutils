#!/usr/bin/env tclsh
# demo-tkutical.tcl -- tical-backed calendar widget: month/week view, week
# numbers, holidays and multi-day selection. Optional widget (requires the
# tical engine) -- not in the tkutils umbrella, so we require it directly.
#
# tical is a sibling repo: set TICAL_DIR, or keep it next to this tkutils repo.
# NOTE: written against the tkutical/tical source API; not executed in this
# sandbox because tical was not available here -- diff/run before relying on it.
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c; break
    }
}
# locate the tical engine (pkgIndex.tcl at the tical repo root)
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tical*]]] {
        if {[file exists [file join $_c pkgIndex.tcl]]} { lappend auto_path $_c; break }
    }
}

package require Tk
package require tkutils::tkutical

wm title . "tkutical demo"
wm geometry . 560x440

# selection callback: invoked as  cmd $widgetPath $selectionList
proc onSel {w sel} {
    .side.lb delete 0 end
    foreach d $sel { .side.lb insert end $d }
    .side.count configure -text "[llength $sel] day(s)"
}

set cal [::tkutils::tkutical::widget .cal \
    -view month -weeknumbers 1 -fontsize 13 \
    -holidays DE -selectmode multiple -command onSel]

# side panel: view toggle + selection list
ttk::frame .side
ttk::label .side.title -text "View"
ttk::radiobutton .side.m -text "Month" -value month -variable ::view \
    -command {::tkutils::tkutical::setView $cal $::view}
ttk::radiobutton .side.w -text "Week"  -value week  -variable ::view \
    -command {::tkutils::tkutical::setView $cal $::view}
set ::view month
ttk::separator .side.sep -orient horizontal
ttk::label .side.sel -text "Selection"
listbox .side.lb -height 10 -width 14
ttk::label .side.count -text "0 day(s)"
ttk::button .side.clr -text "Clear" \
    -command {::tkutils::tkutical::clearSelection $cal; onSel $cal {}}

grid $cal  -row 0 -column 0 -sticky nsew -padx 6 -pady 6
grid .side -row 0 -column 1 -sticky ns -padx {0 6} -pady 6
grid columnconfigure . 0 -weight 1
grid rowconfigure    . 0 -weight 1
grid .side.title -sticky w
grid .side.m -sticky w
grid .side.w -sticky w
grid .side.sep -sticky ew -pady 6
grid .side.sel -sticky w
grid .side.lb -sticky nsew
grid .side.count -sticky w
grid .side.clr -sticky ew -pady {4 0}

if {![info exists ::env(DEMO_NOLOOP)]} { vwait forever }
