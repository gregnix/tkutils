# tkutils::tkcal -- calendar view
#
# Tk front-end on top of the tclutils calendar engine (tucal). Shows a month in
# a monospace view with previous/next/today navigation. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tucal 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkcal {
    namespace export widget setMonth getMonth next prev today getText
    variable state
}

proc ::tkutils::tkcal::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkcal::_todayYM {} {
    scan [clock format [clock seconds] -format %Y] %d y
    scan [clock format [clock seconds] -format %m] %d m
    return [list $y $m]
}

# Build the calendar widget under $path. Options: -year Y -month M
# (default: current month).
proc ::tkutils::tkcal::widget {path args} {
    variable state
    array set opts {-year 0 -month 0 -weeknumbers 0}
    array set opts $args
    if {$opts(-year) == 0 || $opts(-month) == 0} {
        lassign [_todayYM] opts(-year) opts(-month)
    }

    ttk::frame $path
    set state($path,year) $opts(-year)
    set state($path,month) $opts(-month)
    set state($path,weeknumbers) $opts(-weeknumbers)
    set state($path,text) ""
    bind $path <Destroy> [list ::tkutils::tkcal::_cleanup $path %W]

    ttk::frame $path.bar
    ttk::button $path.bar.prev -text "\u25C0" -width 3 \
        -command [list ::tkutils::tkcal::prev $path]
    ttk::label  $path.bar.title -anchor center
    ttk::button $path.bar.next -text "\u25B6" -width 3 \
        -command [list ::tkutils::tkcal::next $path]
    ttk::button $path.bar.today -text "Today" \
        -command [list ::tkutils::tkcal::today $path]
    ttk::checkbutton $path.bar.wk -text "Wk" \
        -variable ::tkutils::tkcal::state($path,weeknumbers) \
        -command [list ::tkutils::tkcal::_render $path]
    grid $path.bar.prev $path.bar.title $path.bar.next $path.bar.today \
        $path.bar.wk -sticky ew -padx 2
    grid columnconfigure $path.bar 1 -weight 1

    text $path.cal -font TkFixedFont -width 24 -height 9 -wrap none
    $path.cal configure -state disabled

    grid $path.bar -sticky ew
    grid $path.cal -sticky nsew
    grid rowconfigure $path 1 -weight 1
    grid columnconfigure $path 0 -weight 1

    _render $path
    return $path
}

# Show year/month. Returns {year month}. Throws on an invalid date.
proc ::tkutils::tkcal::setMonth {path year month} {
    variable state
    ::tclutils::tucal::render $year $month \
        -weeknumbers $state($path,weeknumbers)   ;# validates; throws on bad input
    set state($path,year) $year
    set state($path,month) $month
    _render $path
    return [list $year $month]
}

proc ::tkutils::tkcal::getMonth {path} {
    variable state
    return [list $state($path,year) $state($path,month)]
}

proc ::tkutils::tkcal::next {path} {
    variable state
    set y $state($path,year)
    set m $state($path,month)
    incr m
    if {$m > 12} { set m 1; incr y }
    return [setMonth $path $y $m]
}

proc ::tkutils::tkcal::prev {path} {
    variable state
    set y $state($path,year)
    set m $state($path,month)
    incr m -1
    if {$m < 1} { set m 12; incr y -1 }
    return [setMonth $path $y $m]
}

proc ::tkutils::tkcal::today {path} {
    lassign [_todayYM] y m
    return [setMonth $path $y $m]
}

# Return the rendered calendar text for the current month.
proc ::tkutils::tkcal::getText {path} {
    variable state
    return $state($path,text)
}

proc ::tkutils::tkcal::_render {path} {
    variable state
    set txt [::tclutils::tucal::render $state($path,year) $state($path,month) \
        -weeknumbers $state($path,weeknumbers)]
    set state($path,text) $txt
    $path.cal configure -state normal
    $path.cal delete 1.0 end
    $path.cal insert end $txt
    $path.cal configure -state disabled
    $path.bar.title configure -text [string trim [lindex [split $txt \n] 0]]
}

package provide tkutils::tkcal 0.1
