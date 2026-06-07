#!/usr/bin/env wish
# tical multi-select demo  --  uses the `tical` umbrella (one require for the
# Tk-free engine) plus the optional Tk canvas renderer.

set here [file dirname [file normalize [info script]]]
lappend auto_path [file dirname $here]            ;# tical root (pkgIndex.tcl)
if {[info exists ::env(TICAL_DIR)]} { lappend auto_path $::env(TICAL_DIR) }

package require tical                 ;# umbrella -> engine (view::month etc.)
package require tical::render::canvas 1.0
catch {tical::config::set timezone Europe/Berlin}

set ::Y 2025
set ::M 10
set ::mode multiple

proc redraw {} {
    set spec [tical::view::month::getData -year $::Y -month $::M -holidays DE]
    tical::render::canvas::draw .body.c $spec -interactive 1 -fontsize 13 -weekNumbers 1
    tical::render::canvas::setSelectMode .body.c $::mode
    wm title . "tical - [clock format [clock scan "$::Y-$::M-01"] -format {%B %Y}]"
}
proc onSel {w sel} {
    .body.side.lb delete 0 end
    foreach d $sel { .body.side.lb insert end $d }
    .body.side.count configure -text "[llength $sel] day(s) selected"
}
proc setMode {} { tical::render::canvas::setSelectMode .body.c $::mode }
proc nav {d} {
    if {$d eq "today"} { scan [clock format [clock seconds] -format {%Y %m}] {%d %d} ::Y ::M
    } else {
        incr ::M $d
        if {$::M > 12} {set ::M 1; incr ::Y}
        if {$::M < 1}  {set ::M 12; incr ::Y -1}
    }
    redraw
}

wm title . "tical multi-select demo"
wm geometry . 560x380

ttk::frame .bar
ttk::button .bar.prev  -text "\u25C0" -width 3 -command {nav -1}
ttk::button .bar.today -text Today        -command {nav today}
ttk::button .bar.next  -text "\u25B6" -width 3 -command {nav 1}
ttk::checkbutton .bar.wk -text Wk -variable ::wk -command redraw
ttk::label .bar.ml -text "  Mode:"
ttk::radiobutton .bar.m1 -text single   -variable ::mode -value single   -command setMode
ttk::radiobutton .bar.m2 -text multiple -variable ::mode -value multiple -command setMode
ttk::button .bar.clr -text Clear -command {tical::render::canvas::clearSelection .body.c; onSel .body.c {}}
pack .bar.prev .bar.today .bar.next .bar.wk .bar.ml .bar.m1 .bar.m2 .bar.clr \
    -side left -padx 3 -pady 4
pack .bar -side top -fill x

ttk::frame .body
canvas .body.c -bg white -highlightthickness 0
ttk::labelframe .body.side -text "Selected (click; Shift-click = range)"
ttk::label .body.side.count -text "0 day(s) selected"
listbox .body.side.lb -width 14 -height 12
pack .body.side.count -side top -anchor w -padx 4 -pady 2
pack .body.side.lb -side top -fill both -expand 1 -padx 4 -pady 2
pack .body.c -side left -fill both -expand 1
pack .body.side -side right -fill y
pack .body -side top -fill both -expand 1

tical::render::canvas::setSelectionCommand .body.c onSel
redraw

if {[info exists ::env(TICAL_DEMO_SMOKE)]} {
    update idletasks
    tical::render::canvas::onDayClick .body.c 2025-10-08 0
    tical::render::canvas::onDayClick .body.c 2025-10-13 1   ;# shift range
    puts "smoke: mode=$::mode selection=[tical::render::canvas::getSelection .body.c]"
    puts "smoke: listbox=[.body.side.lb get 0 end]"
    exit 0
}

if {[info exists ::env(TICAL_DEMO_SHOT)]} {
    tical::render::canvas::setSelection .body.c \
        {2025-10-03 2025-10-06 2025-10-13..2025-10-16 2025-10-24}
    onSel .body.c [tical::render::canvas::getSelection .body.c]
    update idletasks; update; after 400; update
    set out $::env(TICAL_DEMO_SHOT)
    exec import -window root /tmp/_root.png
    if {[catch {exec convert /tmp/_root.png -crop 560x380+0+0 +repage $out}]} {
        file copy -force /tmp/_root.png $out
    }
    exit 0
}

vwait forever
