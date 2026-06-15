#!/usr/bin/env tclsh
# demo-tkumonthcanvas.tcl -- procedural canvas calendar (month / quarter / year)
# with themes, selection and click callbacks. Optional widget (requires the
# tical engine) -- not in the tkutils umbrella, so we require it directly.
#
# tical is a sibling repo: set TICAL_DIR, or keep it next to this tkutils repo.
# NOTE: written against the tkumonthcanvas/tical source API; not executed in this
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
if {[info exists ::env(TICAL_DIR)]} {
    lappend auto_path $::env(TICAL_DIR)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tical*]]] {
        if {[file exists [file join $_c pkgIndex.tcl]]} { lappend auto_path $_c; break }
    }
}

package require Tk
package require tkutils::tkumonthcanvas

wm title . "tkumonthcanvas demo"

namespace eval demo {
    variable y; variable m; variable view month
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    set y [scan [string range $today 0 3] %d]
    set m [scan [string range $today 5 6] %d]
}

# tkumonthcanvas uses one global state; init once, then draw onto a canvas.
::tkutils::tkumonthcanvas::init -fontsize 11 -theme default \
    -locale de_DE -timezone :Europe/Berlin
::tkutils::tkumonthcanvas::setSelectMode multiple
::tkutils::tkumonthcanvas::setCallback select ::demo::onSel
::tkutils::tkumonthcanvas::setCallback month  ::demo::onMonth

proc demo::onSel {w sel} {
    .side.lb delete 0 end
    foreach d $sel { .side.lb insert end $d }
    .side.count configure -text "[llength $sel] day(s)"
}
proc demo::onMonth {w year month} { set ::demo::y $year; set ::demo::m $month; demo::redraw }

proc demo::redraw {} {
    variable y; variable m; variable view
    set c .c
    ::tkutils::tkumonthcanvas::clear $c
    switch -- $view {
        month   { ::tkutils::tkumonthcanvas::drawMonth   $c $y $m
                  lassign [::tkutils::tkumonthcanvas::getMonthSize] w h }
        quarter { ::tkutils::tkumonthcanvas::drawQuarter $c $y $m
                  lassign [::tkutils::tkumonthcanvas::getQuarterSize] w h }
        year    { ::tkutils::tkumonthcanvas::drawYear    $c $y
                  lassign [::tkutils::tkumonthcanvas::getYearSize] w h }
    }
    $c configure -scrollregion [list 0 0 $w $h]
    wm title . [format "tkumonthcanvas demo - %s %d-%02d" $view $y $m]
}

proc demo::nav {step} {
    variable y; variable m; variable view
    set n [expr {$view eq "year" ? 12 : ($view eq "quarter" ? 3 : 1)}]
    incr m [expr {$step * $n}]
    while {$m > 12} { incr m -12; incr y }
    while {$m < 1}  { incr m 12;  incr y -1 }
    demo::redraw
}
proc demo::setView {v} { set ::demo::view $v; demo::redraw }
proc demo::setTheme {t} { ::tkutils::tkumonthcanvas::setTheme $t; demo::redraw }

# layout
canvas .c -width 520 -height 360 -background white -highlightthickness 0 \
    -yscrollcommand {.ys set} -xscrollcommand {.xs set}
ttk::scrollbar .ys -orient vertical   -command {.c yview}
ttk::scrollbar .xs -orient horizontal -command {.c xview}

ttk::frame .bar
foreach {txt v} {Month month Quarter quarter Year year} {
    ttk::radiobutton .bar.$v -text $txt -value $v -variable ::demo::view \
        -command [list demo::setView $v]
    pack .bar.$v -side left -padx 2
}
ttk::button .bar.prev -text "<" -width 3 -command {demo::nav -1}
ttk::button .bar.tdy  -text "Today" -command {
    set t [clock format [clock seconds] -format "%Y %m"]
    set ::demo::y [scan [lindex $t 0] %d]; set ::demo::m [scan [lindex $t 1] %d]
    demo::redraw}
ttk::button .bar.next -text ">" -width 3 -command {demo::nav 1}
ttk::label  .bar.thl -text "  Theme:"
ttk::combobox .bar.theme -width 10 -state readonly \
    -values {default dark light} -textvariable ::demo::theme
set ::demo::theme default
bind .bar.theme <<ComboboxSelected>> {demo::setTheme $::demo::theme}
pack .bar.prev .bar.tdy .bar.next -side left -padx 2
pack .bar.thl -side left
pack .bar.theme -side left -padx 2

ttk::frame .side
ttk::label .side.sel -text "Selection"
listbox .side.lb -height 12 -width 14
ttk::label .side.count -text "0 day(s)"
ttk::button .side.clr -text "Clear" \
    -command {::tkutils::tkumonthcanvas::clearSelection; demo::onSel .c {}}
pack .side.sel -anchor w
pack .side.lb -fill both -expand 1
pack .side.count -anchor w
pack .side.clr -fill x -pady {4 0}

grid .bar  -row 0 -column 0 -columnspan 2 -sticky w -padx 6 -pady {6 0}
grid .c    -row 1 -column 0 -sticky nsew -padx {6 0} -pady 6
grid .ys   -row 1 -column 1 -sticky ns -pady 6
grid .xs   -row 2 -column 0 -sticky ew -padx {6 0}
grid .side -row 1 -column 2 -sticky ns -padx 6 -pady 6
grid columnconfigure . 0 -weight 1
grid rowconfigure    . 1 -weight 1

demo::redraw

if {![info exists ::env(DEMO_NOLOOP)]} { vwait forever }
