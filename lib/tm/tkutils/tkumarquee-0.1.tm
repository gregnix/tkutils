# tkutils::tkumarquee -- rubber-band (marquee) rectangle selection on a canvas
# Description: rubber-band (marquee) rectangle selection on a canvas
# Category: Tk · widgets
#
# Drag on a canvas to draw a live selection rectangle; on release the selected
# region is reported in canvas coordinates (scroll-safe via canvasx/canvasy).
# The caller decides what to do with the region (crop, zoom, select items, ...).
# Pure Tk. 8.6+ / 9.x.
#
#   tkumarquee::enable .c -onselect {apply {{c x1 y1 x2 y2} {puts "$x1 $y1 $x2 $y2"}}}
#   tkumarquee::disable .c
#   tkumarquee::region  .c        ;# last region {x1 y1 x2 y2} or ""
#
# Error codes: {TKUTILS TKUMARQUEE NOWIDGET|OPTION}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkumarquee {
    namespace export enable disable region active
    variable state
}

proc ::tkutils::tkumarquee::_require {c} {
    variable state
    if {![info exists state($c,onselect)]} {
        return -code error -errorcode {TKUTILS TKUMARQUEE NOWIDGET} \
            "marquee not enabled on '$c'"
    }
}

proc ::tkutils::tkumarquee::_cleanup {c w} {
    variable state
    if {$w ne $c} return
    array unset state $c,*
}

# Enable rubber-band selection on canvas $c.
#   -onselect cmd   run on release with: cmd $c x1 y1 x2 y2 (x1<=x2, y1<=y2)
#   -onstart  cmd   run on press with:   cmd $c x y
#   -button N       mouse button (default 1)
#   -minsize px     ignore drags smaller than this in both axes (default 3)
#   -outline color  rubber-band outline (default a theme-ish blue)
#   -fill color     rubber-band fill (default "" = none)
#   -dash pattern   rubber-band dash (default {2 2}; "" = solid)
#   -keep 0|1       keep the rectangle item after release (default 0 = delete)
proc ::tkutils::tkumarquee::enable {c args} {
    variable state
    if {![winfo exists $c]} {
        return -code error -errorcode {TKUTILS TKUMARQUEE NOWIDGET} \
            "no such widget '$c'"
    }
    array set o {-onselect {} -onstart {} -button 1 -minsize 3 \
        -outline #1565c0 -fill {} -dash {2 2} -stipple {} -keep 0}
    foreach {opt val} $args {
        if {![info exists o($opt)]} {
            return -code error -errorcode {TKUTILS TKUMARQUEE OPTION} \
                "unknown option '$opt'"
        }
        set o($opt) $val
    }
    set state($c,onselect) $o(-onselect)
    set state($c,onstart)  $o(-onstart)
    set state($c,minsize)  $o(-minsize)
    set state($c,outline)  $o(-outline)
    set state($c,fill)     $o(-fill)
    set state($c,dash)     $o(-dash)
    set state($c,stipple)  $o(-stipple)
    set state($c,keep)     $o(-keep)
    set state($c,item)     ""
    set state($c,region)   ""

    set b $o(-button)
    bind $c <ButtonPress-$b>   [list ::tkutils::tkumarquee::_press   $c %x %y]
    bind $c <B$b-Motion>       [list ::tkutils::tkumarquee::_motion  $c %x %y]
    bind $c <ButtonRelease-$b> [list ::tkutils::tkumarquee::_release $c %x %y]
    bind $c <Destroy> +[list ::tkutils::tkumarquee::_cleanup $c %W]
    return $c
}

proc ::tkutils::tkumarquee::disable {c} {
    variable state
    if {![info exists state($c,onselect)]} return
    if {$state($c,item) ne "" && [winfo exists $c]} {
        catch {$c delete $state($c,item)}
    }
    foreach ev {<ButtonPress-1> <B1-Motion> <ButtonRelease-1> \
                <ButtonPress-2> <B2-Motion> <ButtonRelease-2> \
                <ButtonPress-3> <B3-Motion> <ButtonRelease-3>} {
        catch {bind $c $ev {}}
    }
    array unset state $c,*
    return
}

proc ::tkutils::tkumarquee::_press {c wx wy} {
    variable state
    set x [$c canvasx $wx]
    set y [$c canvasy $wy]
    set state($c,x0) $x
    set state($c,y0) $y
    if {$state($c,item) ne ""} { catch {$c delete $state($c,item)} }
    set opts [list -outline $state($c,outline)]
    if {$state($c,fill) ne ""} {
        lappend opts -fill $state($c,fill)
        if {$state($c,stipple) ne ""} { lappend opts -stipple $state($c,stipple) }
    }
    if {$state($c,dash) ne ""} { lappend opts -dash $state($c,dash) }
    set state($c,item) [$c create rectangle $x $y $x $y {*}$opts]
    if {$state($c,onstart) ne ""} {
        uplevel #0 [list {*}$state($c,onstart) $c $x $y]
    }
}

proc ::tkutils::tkumarquee::_motion {c wx wy} {
    variable state
    if {![info exists state($c,x0)] || $state($c,item) eq ""} return
    set x [$c canvasx $wx]
    set y [$c canvasy $wy]
    $c coords $state($c,item) $state($c,x0) $state($c,y0) $x $y
}

proc ::tkutils::tkumarquee::_release {c wx wy} {
    variable state
    if {![info exists state($c,x0)]} return
    set x [$c canvasx $wx]
    set y [$c canvasy $wy]
    set x1 [expr {min($state($c,x0), $x)}]
    set y1 [expr {min($state($c,y0), $y)}]
    set x2 [expr {max($state($c,x0), $x)}]
    set y2 [expr {max($state($c,y0), $y)}]
    if {!$state($c,keep) && $state($c,item) ne ""} {
        catch {$c delete $state($c,item)}
    }
    set state($c,item) ""
    unset -nocomplain state($c,x0) state($c,y0)
    # ignore clicks / tiny drags
    if {($x2 - $x1) < $state($c,minsize) && ($y2 - $y1) < $state($c,minsize)} {
        return
    }
    set state($c,region) [list $x1 $y1 $x2 $y2]
    if {$state($c,onselect) ne ""} {
        uplevel #0 [list {*}$state($c,onselect) $c $x1 $y1 $x2 $y2]
    }
}

# Last selected region as {x1 y1 x2 y2}, or "" if none yet.
proc ::tkutils::tkumarquee::region {c} {
    variable state
    _require $c
    return $state($c,region)
}

# 1 while a drag is in progress.
proc ::tkutils::tkumarquee::active {c} {
    variable state
    return [expr {[info exists state($c,x0)] ? 1 : 0}]
}

package provide tkutils::tkumarquee 0.1
