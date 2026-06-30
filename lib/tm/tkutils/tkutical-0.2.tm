# tkutils::tkutical -- month/week calendar widget (OPTIONAL: requires tical)
# Description: month/week calendar widget (OPTIONAL: requires tical)
# Category: Tk · widgets
#
# A thin Tk front-end around the `tical` calendar library: it draws a month or
# week grid on a canvas via tical::render::canvas (engines: tical::view::month /
# tical::view::week) and exposes navigation plus interactive day selection
# (none / single / multiple, with Shift-click ranges) as a tku*-style widget API.
#
# Internally the widget tracks one reference ISO date. The month view shows that
# date's month and navigates by +/-1 month; the week view shows the ISO week of
# that date and navigates by +/-7 days. Selection is view-agnostic.
#
# OPTIONAL widget: NOT part of the tkutils umbrella. Require it directly once
# the `tical` packages are on the module path. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tical::view::month 1.0
package require tical::view::week 1.0
package require tical::render::canvas 1.0

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutical {
    namespace export widget setMonth getMonth setDate getDate setView getView \
        next prev today refresh selectMode getSelection setSelection \
        clearSelection canvasWidget
    variable state
}

proc ::tkutils::tkutical::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkutical::_today {} {
    return [clock format [clock seconds] -format %Y-%m-%d]
}
proc ::tkutils::tkutical::_ymOf {iso} {
    scan $iso "%d-%d-%d" y m d
    return [list $y $m]
}
proc ::tkutils::tkutical::_addMonths {iso n} {
    set t [clock scan "$iso 12:00:00" -timezone :UTC]
    return [clock format [clock add $t $n months -timezone :UTC] \
        -format %Y-%m-%d -timezone :UTC]
}
proc ::tkutils::tkutical::_addDays {iso n} {
    set t [clock scan "$iso 12:00:00" -timezone :UTC]
    return [clock format [clock add $t $n days -timezone :UTC] \
        -format %Y-%m-%d -timezone :UTC]
}
proc ::tkutils::tkutical::_validDate {iso} {
    # Strict, version-independent validation (do not rely on clock scan, whose
    # free-form parser rolls over out-of-range fields on some Tcl builds).
    if {![regexp {^(\d{4})-(\d{2})-(\d{2})$} $iso -> y m d]} { return 0 }
    scan $y %d y; scan $m %d m; scan $d %d d
    if {$m < 1 || $m > 12 || $d < 1} { return 0 }
    set first [clock scan [format "%04d-%02d-01 12:00:00" $y $m] -timezone :UTC]
    set last  [clock add [clock add $first 1 month -timezone :UTC] -1 day -timezone :UTC]
    set dim   [scan [clock format $last -format %d -timezone :UTC] %d]
    return [expr {$d <= $dim}]
}

# Build the calendar widget under $path.
# Options: -view month|week -date YYYY-MM-DD -year Y -month M
#          -weeknumbers 0|1 -fontsize N -holidays REGION
#          -selectmode none|single|multiple -command CMD
# Reference date precedence: -date, else -year/-month (1st of that month),
# else today. CMD is called as `CMD $path $selection` on selection changes
# (selection modes only). Returns $path.
proc ::tkutils::tkutical::widget {path args} {
    variable state
    array set o {
        -view month -date {} -year 0 -month 0 -weeknumbers 1 -fontsize 12
        -holidays {} -selectmode single -command {}
    }
    array set o $args
    if {$o(-view) ni {month week}} {
        return -code error -errorcode {TKUTILS TKUTICAL VIEW} \
            "view must be month|week"
    }
    if {$o(-selectmode) ni {none single multiple}} {
        return -code error -errorcode {TKUTILS TKUTICAL SELECTMODE} \
            "selectmode must be none|single|multiple"
    }
    if {$o(-date) ne ""} {
        if {![_validDate $o(-date)]} {
            return -code error -errorcode {TKUTILS TKUTICAL DATE} \
                "invalid date: $o(-date)"
        }
        set ref $o(-date)
    } elseif {$o(-year) != 0 && $o(-month) != 0} {
        set ref [format %04d-%02d-01 $o(-year) $o(-month)]
    } else {
        set ref [_today]
    }

    ttk::frame $path
    set state($path,date)        $ref
    set state($path,view)        $o(-view)
    set state($path,weeknumbers) $o(-weeknumbers)
    set state($path,fontsize)    $o(-fontsize)
    set state($path,holidays)    $o(-holidays)
    set state($path,command)     $o(-command)
    bind $path <Destroy> [list ::tkutils::tkutical::_cleanup $path %W]

    ttk::frame $path.bar
    ttk::button $path.bar.prev  -text "\u25C0" -width 3 \
        -command [list ::tkutils::tkutical::prev $path]
    ttk::button $path.bar.today -text "Today" \
        -command [list ::tkutils::tkutical::today $path]
    ttk::button $path.bar.next  -text "\u25B6" -width 3 \
        -command [list ::tkutils::tkutical::next $path]
    ttk::checkbutton $path.bar.wk -text "Wk" \
        -variable ::tkutils::tkutical::state($path,weeknumbers) \
        -command [list ::tkutils::tkutical::refresh $path]
    grid $path.bar.prev $path.bar.today $path.bar.next $path.bar.wk \
        -sticky w -padx 2
    grid columnconfigure $path.bar 3 -weight 1

    canvas $path.c -bg white -highlightthickness 0
    grid $path.bar -sticky ew
    grid $path.c   -sticky nsew
    grid rowconfigure    $path 1 -weight 1
    grid columnconfigure $path 0 -weight 1

    tical::render::canvas::setSelectMode $path.c $o(-selectmode)
    if {$o(-command) ne ""} {
        tical::render::canvas::setSelectionCommand $path.c \
            [list ::tkutils::tkutical::_onSelect $path]
    }
    _render $path
    return $path
}

proc ::tkutils::tkutical::_onSelect {path w sel} {
    variable state
    if {[info exists state($path,command)] && $state($path,command) ne ""} {
        uplevel #0 [list {*}$state($path,command) $path $sel]
    }
}

proc ::tkutils::tkutical::_render {path} {
    variable state
    set hol {}
    if {$state($path,holidays) ne ""} { set hol [list -holidays $state($path,holidays)] }
    if {$state($path,view) eq "week"} {
        set spec [tical::view::week::getData -date $state($path,date) {*}$hol]
    } else {
        lassign [_ymOf $state($path,date)] y m
        set spec [tical::view::month::getData -year $y -month $m {*}$hol]
    }
    tical::render::canvas::draw $path.c $spec \
        -interactive 1 -fontsize $state($path,fontsize) \
        -weekNumbers $state($path,weeknumbers)
}

# Re-render the current view (e.g. after toggling week numbers).
proc ::tkutils::tkutical::refresh {path} { _render $path }

# --- view & reference date --------------------------------------------------

proc ::tkutils::tkutical::setView {path view} {
    variable state
    if {$view ni {month week}} {
        return -code error -errorcode {TKUTILS TKUTICAL VIEW} \
            "view must be month|week"
    }
    set state($path,view) $view
    _render $path
    return $view
}
proc ::tkutils::tkutical::getView {path} {
    variable state
    return $state($path,view)
}

proc ::tkutils::tkutical::setDate {path iso} {
    variable state
    if {![_validDate $iso]} {
        return -code error -errorcode {TKUTILS TKUTICAL DATE} "invalid date: $iso"
    }
    set state($path,date) $iso
    _render $path
    return $iso
}
proc ::tkutils::tkutical::getDate {path} {
    variable state
    return $state($path,date)
}

# Show year/month (sets the reference to the 1st of that month). Returns {y m}.
proc ::tkutils::tkutical::setMonth {path year month} {
    variable state
    if {![string is integer -strict $month] || $month < 1 || $month > 12} {
        return -code error -errorcode {TKUTILS TKUTICAL MONTH} \
            "invalid month: $month"
    }
    set state($path,date) [format %04d-%02d-01 $year $month]
    _render $path
    return [list $year $month]
}
proc ::tkutils::tkutical::getMonth {path} {
    variable state
    return [_ymOf $state($path,date)]
}

# Navigation: month view steps by month, week view by 7 days.
proc ::tkutils::tkutical::next {path} {
    variable state
    if {$state($path,view) eq "week"} {
        set state($path,date) [_addDays $state($path,date) 7]
    } else {
        set state($path,date) [_addMonths $state($path,date) 1]
    }
    _render $path
    return $state($path,date)
}
proc ::tkutils::tkutical::prev {path} {
    variable state
    if {$state($path,view) eq "week"} {
        set state($path,date) [_addDays $state($path,date) -7]
    } else {
        set state($path,date) [_addMonths $state($path,date) -1]
    }
    _render $path
    return $state($path,date)
}
proc ::tkutils::tkutical::today {path} {
    variable state
    set state($path,date) [_today]
    _render $path
    return $state($path,date)
}

# --- selection (delegates to the tical canvas renderer) ---------------------

proc ::tkutils::tkutical::selectMode {path mode} {
    if {$mode ni {none single multiple}} {
        return -code error -errorcode {TKUTILS TKUTICAL SELECTMODE} \
            "selectmode must be none|single|multiple"
    }
    return [tical::render::canvas::setSelectMode $path.c $mode]
}
proc ::tkutils::tkutical::getSelection {path} {
    return [tical::render::canvas::getSelection $path.c]
}
# Accepts ISO dates and YYYY-MM-DD..YYYY-MM-DD ranges.
proc ::tkutils::tkutical::setSelection {path dates} {
    return [tical::render::canvas::setSelection $path.c $dates]
}
proc ::tkutils::tkutical::clearSelection {path} {
    tical::render::canvas::clearSelection $path.c
}
# Expose the underlying canvas for advanced use.
proc ::tkutils::tkutical::canvasWidget {path} { return $path.c }

package provide tkutils::tkutical 0.2
