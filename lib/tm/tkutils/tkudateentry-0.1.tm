# tkutils::tkudateentry -- date entry with a drop-down calendar picker.
# Description: date entry with a drop-down calendar picker.
# Category: Tk · widgets
#
# An entry showing a date plus a button that drops down a month grid of day
# buttons (Monday-first) with previous/next navigation, Today and Clear. The
# displayed text uses -dateformat; getDate always returns the ISO date derived
# from the entry. Date math uses the Tcl clock command. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkudateentry {
    namespace export widget getText getDate setDate today clear
    variable state
    variable WD {Mo Tu We Th Fr Sa Su}
}

proc ::tkutils::tkudateentry::_cleanup {path w} {
    variable state
    if {$w eq $path} {
        catch {destroy $path.pop}
        array unset state $path,*
    }
}

# Build the date entry under $path.
# Options: -textvariable var, -dateformat fmt (default %Y-%m-%d), -width n,
# -command cmd (called with the ISO date when a day is picked).
proc ::tkutils::tkudateentry::widget {path args} {
    variable state
    array set opts {-textvariable "" -dateformat "%Y-%m-%d" -width 12 -command ""}
    array set opts $args

    ttk::frame $path
    set state($path,fmt) $opts(-dateformat)
    set state($path,cmd) $opts(-command)
    bind $path <Destroy> [list ::tkutils::tkudateentry::_cleanup $path %W]

    set evar [list]
    if {$opts(-textvariable) ne ""} { set evar [list -textvariable $opts(-textvariable)] }
    ttk::entry $path.e -width $opts(-width) {*}$evar
    ttk::button $path.b -text "\u25BC" -width 2 \
        -command [list ::tkutils::tkudateentry::_toggle $path]
    grid $path.e $path.b -sticky ew
    grid columnconfigure $path 0 -weight 1
    return $path
}

# --- public API ----------------------------------------------------------

proc ::tkutils::tkudateentry::getText {path} { return [$path.e get] }

# ISO date (yyyy-mm-dd) parsed from the entry text via -dateformat, or "".
proc ::tkutils::tkudateentry::getDate {path} {
    variable state
    set s [string trim [$path.e get]]
    if {$s eq ""} { return "" }
    if {[catch {clock scan $s -format $state($path,fmt) -base 0 -gmt 1} t]} {
        return ""
    }
    return [clock format $t -format %Y-%m-%d -gmt 1]
}

# Set the entry from an ISO date ("" clears it).
proc ::tkutils::tkudateentry::setDate {path iso} {
    variable state
    if {$iso eq ""} { $path.e delete 0 end; return "" }
    if {[catch {clock scan $iso -format %Y-%m-%d -gmt 1} t]} {
        return -code error -errorcode {TKUTILS TKDATEENTRY DATE} \
            "not an ISO date (yyyy-mm-dd): \"$iso\""
    }
    set txt [clock format $t -format $state($path,fmt) -gmt 1]
    $path.e delete 0 end
    $path.e insert 0 $txt
    return $txt
}

proc ::tkutils::tkudateentry::today {path} {
    return [setDate $path [clock format [clock seconds] -format %Y-%m-%d]]
}

proc ::tkutils::tkudateentry::clear {path} { $path.e delete 0 end; return "" }

# --- popup ---------------------------------------------------------------

proc ::tkutils::tkudateentry::_toggle {path} {
    if {[winfo exists $path.pop]} { _hide $path } else { _show $path }
}

proc ::tkutils::tkudateentry::_hide {path} {
    catch {grab release $path.pop}
    catch {destroy $path.pop}
}

proc ::tkutils::tkudateentry::_show {path} {
    variable state
    # seed the popup month from the current value, else today
    set iso [getDate $path]
    if {$iso eq ""} { set iso [clock format [clock seconds] -format %Y-%m-%d] }
    set t [clock scan $iso -format %Y-%m-%d -gmt 1]
    set state($path,py) [clock format $t -format %Y -gmt 1]
    set state($path,pm) [scan [clock format $t -format %m -gmt 1] %d]

    set pop $path.pop
    toplevel $pop
    wm overrideredirect $pop 1
    wm transient $pop [winfo toplevel $path]
    # position just below the entry
    set x [winfo rootx $path]
    set y [expr {[winfo rooty $path] + [winfo height $path]}]
    wm geometry $pop +$x+$y
    ttk::frame $pop.f -relief solid -borderwidth 1 -padding 4
    pack $pop.f -fill both -expand 1
    _render $path
    bind $pop <Escape> [list ::tkutils::tkudateentry::_hide $path]
    # close when focus leaves the popup
    bind $pop <FocusOut> [list ::tkutils::tkudateentry::_focusOut $path]
    catch {grab -global $pop}
    focus $pop
}

proc ::tkutils::tkudateentry::_focusOut {path} {
    set pop $path.pop
    if {![winfo exists $pop]} return
    set f [focus -displayof $pop]
    if {$f eq "" || [string first $pop $f] != 0} { _hide $path }
}

proc ::tkutils::tkudateentry::_nav {path delta} {
    variable state
    set m [expr {$state($path,pm) + $delta}]
    set y $state($path,py)
    while {$m < 1}  { incr m 12; incr y -1 }
    while {$m > 12} { incr m -12; incr y 1 }
    set state($path,py) $y
    set state($path,pm) $m
    _render $path
}

proc ::tkutils::tkudateentry::_firstWeekday {y m} {
    # 0=Mon .. 6=Sun (Monday-first)
    set t [clock scan [format %04d-%02d-01 $y $m] -format %Y-%m-%d -gmt 1]
    return [expr {([clock format $t -format %w -gmt 1] + 6) % 7}]
}

proc ::tkutils::tkudateentry::_daysInMonth {y m} {
    set ny [expr {$m == 12 ? $y + 1 : $y}]
    set nm [expr {$m == 12 ? 1 : $m + 1}]
    set firstNext [clock scan [format %04d-%02d-01 $ny $nm] -format %Y-%m-%d -gmt 1]
    set last [clock add $firstNext -1 day -gmt 1]
    return [scan [clock format $last -format %d -gmt 1] %d]
}

proc ::tkutils::tkudateentry::_render {path} {
    variable state
    variable WD
    set f $path.pop.f
    foreach c [winfo children $f] { destroy $c }
    set y $state($path,py)
    set m $state($path,pm)

    # header: prev | "Month YYYY" | next
    ttk::frame $f.h
    ttk::button $f.h.p -text "\u25C0" -width 2 \
        -command [list ::tkutils::tkudateentry::_nav $path -1]
    ttk::label  $f.h.t -anchor center \
        -text [clock format [clock scan [format %04d-%02d-01 $y $m] \
            -format %Y-%m-%d -gmt 1] -format "%B %Y" -gmt 1]
    ttk::button $f.h.n -text "\u25B6" -width 2 \
        -command [list ::tkutils::tkudateentry::_nav $path 1]
    grid $f.h.p $f.h.t $f.h.n -sticky ew
    grid columnconfigure $f.h 1 -weight 1
    grid $f.h -row 0 -column 0 -columnspan 7 -sticky ew -pady {0 2}

    # weekday headers
    set col 0
    foreach d $WD {
        ttk::label $f.wd$col -text $d -anchor center -width 3
        grid $f.wd$col -row 1 -column $col
        incr col
    }

    # day buttons
    set fw [_firstWeekday $y $m]
    set dim [_daysInMonth $y $m]
    set todayIso [clock format [clock seconds] -format %Y-%m-%d]
    set selIso [getDate $path]
    set row 2
    set col $fw
    for {set d 1} {$d <= $dim} {incr d} {
        set iso [format %04d-%02d-%02d $y $m $d]
        set b $f.d$d
        ttk::button $b -text $d -width 3 \
            -command [list ::tkutils::tkudateentry::_pick $path $iso]
        if {$iso eq $selIso}   { $b state pressed }
        if {$iso eq $todayIso} { $b configure -text "\[$d\]" }
        grid $b -row $row -column $col -sticky nsew
        incr col
        if {$col > 6} { set col 0; incr row }
    }

    # footer: Today | Clear
    ttk::frame $f.ft
    ttk::button $f.ft.today -text "Today" \
        -command [list ::tkutils::tkudateentry::_pick $path $todayIso]
    ttk::button $f.ft.clear -text "Clear" \
        -command [list ::tkutils::tkudateentry::_pickClear $path]
    grid $f.ft.today $f.ft.clear -sticky ew -padx 2
    grid $f.ft -row [expr {$row + 1}] -column 0 -columnspan 7 -sticky ew -pady {2 0}
}

proc ::tkutils::tkudateentry::_pick {path iso} {
    variable state
    setDate $path $iso
    _hide $path
    if {$state($path,cmd) ne ""} {
        uplevel #0 [linsert $state($path,cmd) end $iso]
    }
}

proc ::tkutils::tkudateentry::_pickClear {path} {
    variable state
    clear $path
    _hide $path
    if {$state($path,cmd) ne ""} {
        uplevel #0 [linsert $state($path,cmd) end ""]
    }
}

package provide tkutils::tkudateentry 0.1
