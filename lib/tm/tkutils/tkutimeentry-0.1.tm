# tkutils::tkutimeentry -- time entry with hour/minute (optional second) spinboxes.
# getTime/setTime use "HH:MM" (or "HH:MM:SS" with -seconds). Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutimeentry {
    namespace export widget getTime setTime
    variable state
}

proc ::tkutils::tkutimeentry::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the time entry under $path.
# Options: -time HH:MM(:SS), -increment minutes (default 5), -seconds bool,
# -command cmd (called with the time string on change).
proc ::tkutils::tkutimeentry::widget {path args} {
    variable state
    array set opts {-time "" -increment 5 -seconds 0 -command ""}
    array set opts $args

    ttk::frame $path
    set state($path,cmd) $opts(-command)
    set state($path,sec) [expr {$opts(-seconds) ? 1 : 0}]
    set state($path,h) 0
    set state($path,m) 0
    set state($path,s) 0
    bind $path <Destroy> [list ::tkutils::tkutimeentry::_cleanup $path %W]

    set ns ::tkutils::tkutimeentry::state
    set chg [list ::tkutils::tkutimeentry::_onChange $path]
    ttk::spinbox $path.h -from 0 -to 23 -width 3 -format %02.0f -wrap 1 \
        -textvariable ${ns}($path,h) -command $chg
    ttk::label $path.c1 -text ":"
    ttk::spinbox $path.m -from 0 -to 59 -width 3 -format %02.0f -wrap 1 \
        -increment $opts(-increment) -textvariable ${ns}($path,m) -command $chg
    grid $path.h $path.c1 $path.m -sticky w
    if {$state($path,sec)} {
        ttk::label $path.c2 -text ":"
        ttk::spinbox $path.s -from 0 -to 59 -width 3 -format %02.0f -wrap 1 \
            -textvariable ${ns}($path,s) -command $chg
        grid $path.c2 $path.s -row 0 -sticky w
    }
    foreach sb {h m s} {
        if {[winfo exists $path.$sb]} {
            bind $path.$sb <Return>   $chg
            bind $path.$sb <FocusOut> $chg
        }
    }

    if {$opts(-time) ne ""} { setTime $path $opts(-time) }
    return $path
}

# --- public API ----------------------------------------------------------

# Parse a (possibly zero-padded) field to a plain integer; non-digits -> 0.
proc ::tkutils::tkutimeentry::_int {v} {
    set v [string trim $v]
    if {[regexp {^\d+$} $v]} { return [scan $v %d] }
    return 0
}

proc ::tkutils::tkutimeentry::getTime {path} {
    variable state
    set h [_int $state($path,h)]
    set m [_int $state($path,m)]
    set s [_int $state($path,s)]
    if {$state($path,sec)} { return [format %02d:%02d:%02d $h $m $s] }
    return [format %02d:%02d $h $m]
}

# Set from "HH:MM" or "HH:MM:SS".
proc ::tkutils::tkutimeentry::setTime {path str} {
    variable state
    set parts [split $str :]
    if {[llength $parts] < 2 || [llength $parts] > 3} {
        return -code error -errorcode {TKUTILS TKTIMEENTRY TIME} \
            "not a time (HH:MM or HH:MM:SS): \"$str\""
    }
    lassign $parts h m s
    if {$s eq ""} { set s 0 }
    foreach {v lo hi} [list $h 0 23 $m 0 59 $s 0 59] {
        if {![regexp {^\d+$} [string trim $v]] \
                || [scan [string trim $v] %d] < $lo \
                || [scan [string trim $v] %d] > $hi} {
            return -code error -errorcode {TKUTILS TKTIMEENTRY TIME} \
                "time out of range: \"$str\""
        }
    }
    set state($path,h) [_int $h]
    set state($path,m) [_int $m]
    set state($path,s) [_int $s]
    return [getTime $path]
}

# --- internals -----------------------------------------------------------

proc ::tkutils::tkutimeentry::_onChange {path} {
    variable state
    if {$state($path,cmd) ne ""} {
        uplevel #0 [linsert $state($path,cmd) end [getTime $path]]
    }
}

package provide tkutils::tkutimeentry 0.1
