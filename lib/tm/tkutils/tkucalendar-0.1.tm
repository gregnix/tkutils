# tkutils::tkucalendar -- a clickable month calendar widget.
#
# A month grid with previous/next/today navigation and click-to-select day
# cells -- a dependency-free replacement for widget::calendar. The reference
# month and the selected day are tracked as ISO dates; the display uses the
# system locale for month and weekday names (or a given -locale). Pure Tk +
# clock; nothing external. Tk 8.6+ and 9.x.
#
#   ::tkutils::tkucalendar::widget .cal ?options?
#
# Options:
#   -date iso        initially selected day (ISO yyyy-mm-dd); default: none
#   -firstday        first column: monday (default) or sunday
#   -dateformat fmt  clock format for getFormatted (default %Y-%m-%d)
#   -locale name     locale for month/weekday names (default: current)
#   -command script  appended the selected ISO date on each selection
#
# API:
#   getDate path        -> selected ISO date, or "" if none
#   getFormatted path   -> the selected date via -dateformat, or ""
#   setDate path iso    -> select a date and show its month
#   today path          -> select today
#   next path / prev path -> move one month, keep the selection
#   getMonth path       -> "yyyy mm" of the displayed month

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkucalendar {
    namespace export widget getDate getFormatted setDate today next prev getMonth
    variable state
}

proc ::tkutils::tkucalendar::widget {path args} {
    variable state
    array set o {-date "" -firstday monday -dateformat %Y-%m-%d -locale "" -command ""}
    array set o $args
    if {$o(-firstday) ni {monday sunday}} {
        return -code error "bad -firstday \"$o(-firstday)\": must be monday or sunday"
    }
    set state($path,fmt)    $o(-dateformat)
    set state($path,first)  $o(-firstday)
    set state($path,locale) $o(-locale)
    set state($path,cmd)    $o(-command)
    set state($path,sel)    ""
    # reference date: the selected date's month, else today
    if {$o(-date) ne "" && ![catch {_iso $o(-date)} iso]} {
        set state($path,sel) $iso
        set state($path,ref) $iso
    } else {
        set state($path,ref) [clock format [clock seconds] -format %Y-%m-%d]
    }

    ttk::frame $path
    ttk::frame $path.nav
    ttk::button $path.nav.prev  -text "\u2039" -width 3 \
        -command [list ::tkutils::tkucalendar::prev $path]
    ttk::label  $path.nav.title -anchor center
    ttk::button $path.nav.today -text "Today" \
        -command [list ::tkutils::tkucalendar::today $path]
    ttk::button $path.nav.next  -text "\u203a" -width 3 \
        -command [list ::tkutils::tkucalendar::next $path]
    grid $path.nav.prev $path.nav.title $path.nav.today $path.nav.next -sticky ew -padx 2
    grid columnconfigure $path.nav 1 -weight 1
    pack $path.nav -fill x -padx 2 -pady 2

    ttk::frame $path.grid
    pack $path.grid -fill both -expand 1 -padx 2 -pady {0 2}

    _draw $path
    bind $path <Destroy> [list ::tkutils::tkucalendar::_cleanup $path %W]
    return $path
}

# normalize an ISO date via clock (throws on a bad date)
proc ::tkutils::tkucalendar::_iso {date} {
    return [clock format [clock scan $date -format %Y-%m-%d] -format %Y-%m-%d]
}

proc ::tkutils::tkucalendar::_fmt {path fmt secs} {
    variable state
    if {$state($path,locale) ne ""} {
        return [clock format $secs -format $fmt -locale $state($path,locale)]
    }
    return [clock format $secs -format $fmt]
}

proc ::tkutils::tkucalendar::_draw {path} {
    variable state
    set g $path.grid
    foreach c [winfo children $g] { destroy $c }
    set ref [clock scan $state($path,ref) -format %Y-%m-%d]
    scan [clock format $ref -format %Y] %d y
    scan [clock format $ref -format %m] %d m
    $path.nav.title configure -text [_fmt $path "%B %Y" $ref]

    # weekday header, honoring -firstday
    if {$state($path,first) eq "monday"} {
        set order {1 2 3 4 5 6 7}   ;# Mon..Sun (ISO %u)
    } else {
        set order {7 1 2 3 4 5 6}   ;# Sun..Sat
    }
    set col 0
    foreach u $order {
        # a known date with that ISO weekday, for the short name
        set sample [clock scan "2024-01-0[expr {$u==7?7:$u}]" -format %Y-%m-%d]
        ttk::label $g.h$col -text [_fmt $path %a $sample] -anchor center \
            -font TkHeadingFont
        grid $g.h$col -row 0 -column $col -sticky ew -padx 1 -pady 1
        incr col
    }

    set first [clock scan [format "%04d-%02d-01" $y $m] -format %Y-%m-%d]
    scan [clock format $first -format %u] %d wd    ;# 1=Mon..7=Sun
    if {$state($path,first) eq "monday"} {
        set start [expr {$wd - 1}]
    } else {
        set start [expr {$wd % 7}]                 ;# Sun=0
    }
    set nm [expr {$m + 1}] ; set ny $y
    if {$nm > 12} { set nm 1 ; incr ny }
    set last [clock add [clock scan [format "%04d-%02d-01" $ny $nm] -format %Y-%m-%d] -1 day]
    scan [clock format $last -format %d] %d ndays
    set today [clock format [clock seconds] -format %Y-%m-%d]

    set row 1 ; set col $start
    for {set day 1} {$day <= $ndays} {incr day} {
        set iso [format "%04d-%02d-%02d" $y $m $day]
        set b [ttk::button $g.d$day -text $day -width 3 \
            -command [list ::tkutils::tkucalendar::_select $path $iso]]
        if {$iso eq $state($path,sel)} {
            $b state pressed
        } elseif {$iso eq $today} {
            $b configure -style Today.TButton
        }
        grid $g.d$day -row $row -column $col -sticky nsew -padx 1 -pady 1
        incr col
        if {$col > 6} { set col 0 ; incr row }
    }
    for {set c 0} {$c < 7} {incr c} { grid columnconfigure $g $c -weight 1 -uniform cal }
    # a subtle style for "today" if the theme allows it
    catch {ttk::style configure Today.TButton -font TkHeadingFont}
}

proc ::tkutils::tkucalendar::_select {path iso} {
    variable state
    set state($path,sel) $iso
    _draw $path
    if {$state($path,cmd) ne ""} {
        uplevel #0 [list {*}$state($path,cmd) $iso]
    }
}

# ---- public API -----------------------------------------------------------
proc ::tkutils::tkucalendar::getDate {path} {
    variable state
    return $state($path,sel)
}

proc ::tkutils::tkucalendar::getFormatted {path} {
    variable state
    if {$state($path,sel) eq ""} { return "" }
    return [_fmt $path $state($path,fmt) \
        [clock scan $state($path,sel) -format %Y-%m-%d]]
}

proc ::tkutils::tkucalendar::setDate {path iso} {
    variable state
    set norm [_iso $iso]
    set state($path,sel) $norm
    set state($path,ref) $norm
    _draw $path
    return $norm
}

proc ::tkutils::tkucalendar::today {path} {
    _select $path [clock format [clock seconds] -format %Y-%m-%d]
    variable state
    set state($path,ref) $state($path,sel)
    _draw $path
}

proc ::tkutils::tkucalendar::next {path} { _month $path 1 }
proc ::tkutils::tkucalendar::prev {path} { _month $path -1 }

proc ::tkutils::tkucalendar::_month {path dir} {
    variable state
    set ref [clock scan $state($path,ref) -format %Y-%m-%d]
    scan [clock format $ref -format %Y] %d y
    scan [clock format $ref -format %m] %d m
    incr m $dir
    if {$m < 1}  { set m 12 ; incr y -1 }
    if {$m > 12} { set m 1  ; incr y 1 }
    set state($path,ref) [format "%04d-%02d-01" $y $m]
    _draw $path
}

proc ::tkutils::tkucalendar::getMonth {path} {
    variable state
    set ref [clock scan $state($path,ref) -format %Y-%m-%d]
    return "[clock format $ref -format %Y] [clock format $ref -format %m]"
}

proc ::tkutils::tkucalendar::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    array unset state $path,*
}

package provide tkutils::tkucalendar 0.1
