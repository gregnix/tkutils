#!/usr/bin/env wish
#
# tkumonthcanvas demo -- draw a month, quarter, or year onto a canvas.
#
# tkumonthcanvas is OPTIONAL: it needs the external `tical` engine. Put tical on
# the auto_path (adjust the path below to where your tical checkout lives), then
# run this with wish.

set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]

# --- point this at your tical checkout ---
foreach cand [list \
        [file join $here .. .. tical] \
        [file join $here .. tical] \
        /tmp/tical/tical] {
    if {[file isdirectory $cand]} { lappend auto_path [file normalize $cand] ; break }
}

package require Tk
if {[catch {package require tkutils::tkumonthcanvas} err]} {
    wm withdraw .
    tk_messageBox -icon error -title "tical missing" -message \
        "tkumonthcanvas needs the tical engine on the auto_path.\n\n$err"
    exit 1
}

wm title . "tkumonthcanvas demo"
set ::view month
set ::info "click a day"

ttk::frame .bar
ttk::label .bar.l -text "View:"
ttk::radiobutton .bar.m -text "Month"   -value month   -variable ::view -command redraw
ttk::radiobutton .bar.q -text "Quarter" -value quarter -variable ::view -command redraw
ttk::radiobutton .bar.y -text "Year"    -value year    -variable ::view -command redraw
pack .bar.l .bar.m .bar.q .bar.y -side left -padx 4
pack .bar -fill x -pady 4

set c .c
canvas $c -bg white -highlightthickness 0
ttk::scrollbar .sy -orient vertical   -command [list $c yview]
$c configure -yscrollcommand [list .sy set]

ttk::label .info -textvariable ::info -anchor w -foreground "#1565c0"
pack .info -fill x -side bottom -padx 6 -pady {0 6}
pack .sy -fill y -side right
pack $c -fill both -expand 1 -side left

tkutils::tkumonthcanvas::init -theme default
tkutils::tkumonthcanvas::setCallback day {apply {{w date} {
    set ::info "clicked: $date"
}}}

proc redraw {} {
    set c .c
    tkutils::tkumonthcanvas::clear $c
    switch -- $::view {
        month {
            tkutils::tkumonthcanvas::drawMonth $c 2026 7 10 10
            lassign [tkutils::tkumonthcanvas::getMonthSize] w h
        }
        quarter {
            tkutils::tkumonthcanvas::drawQuarter $c 2026 7 10 10
            lassign [tkutils::tkumonthcanvas::getQuarterSize] w h
        }
        year {
            tkutils::tkumonthcanvas::drawYear $c 2026 10 10 3
            lassign [tkutils::tkumonthcanvas::getYearSize 3] w h
        }
    }
    $c configure -scrollregion [list 0 0 [expr {$w + 20}] [expr {$h + 20}]]
}

redraw
