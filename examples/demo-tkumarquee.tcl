#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
package require tkutils::tkumarquee
wm title . "tkumarquee demo"

pack [ttk::label .hint -padding 8 -anchor w -text \
    "Drag a rectangle on the canvas. The selection is kept and reported below."] -fill x

canvas .c -width 480 -height 320 -bg "#fafafa" -highlightthickness 1 \
    -highlightbackground "#ccc"
pack .c -fill both -expand 1 -padx 8 -pady 8

# some content to select over
for {set i 0} {$i < 8} {incr i} {
    set x [expr {30 + $i * 55}]
    .c create oval $x 40 [expr {$x + 36}] 76 -fill "#90caf9" -outline "#1565c0"
    .c create text [expr {$x + 18}] 100 -text "item $i" -font {TkDefaultFont 8}
}

pack [ttk::label .out -padding 8 -anchor w -text "(no selection yet)"] -fill x

# Each new drag clears the previous persistent marker, then draws a kept one.
::tkutils::tkumarquee::enable .c -keep 1 -fill "#1565c0" -stipple gray12 -outline "#1565c0" \
    -onstart {apply {{c x y} {
        foreach id [$c find withtag mark] { $c delete $id }
    }}} \
    -onselect {apply {{c x1 y1 x2 y2} {
        # tag the just-drawn rectangle so the next drag can clear it
        set last [lindex [$c find withtag all] end]
        $c addtag mark withtag $last
        set w [expr {int($x2 - $x1)}]; set h [expr {int($y2 - $y1)}]
        .out configure -text [format "region: %.0f,%.0f .. %.0f,%.0f   (%dx%d px)" \
            $x1 $y1 $x2 $y2 $w $h]
    }}}

vwait forever
