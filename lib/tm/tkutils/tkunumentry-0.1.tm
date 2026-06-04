# tkutils::tkunumentry -- numeric entry with input validation, fixed decimals
# and optional min/max clamping (applied on commit: Return / focus-out).
# Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkunumentry {
    namespace export widget getValue setValue clear
    variable state
}

proc ::tkutils::tkunumentry::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the numeric entry under $path.
# Options: -decimals n (default 0), -min v, -max v ("" = unbounded),
# -textvariable var, -width n, -command cmd (called with the value on commit).
proc ::tkutils::tkunumentry::widget {path args} {
    variable state
    array set opts {-decimals 0 -min "" -max "" -textvariable "" -width 12 -command ""}
    array set opts $args

    ttk::frame $path
    set state($path,dec) $opts(-decimals)
    set state($path,min) $opts(-min)
    set state($path,max) $opts(-max)
    set state($path,cmd) $opts(-command)
    bind $path <Destroy> [list ::tkutils::tkunumentry::_cleanup $path %W]

    set evar [list]
    if {$opts(-textvariable) ne ""} { set evar [list -textvariable $opts(-textvariable)] }
    ttk::entry $path.e -width $opts(-width) -justify right {*}$evar \
        -validate key \
        -validatecommand [list ::tkutils::tkunumentry::_validate $path %P]
    grid $path.e -sticky ew
    grid columnconfigure $path 0 -weight 1
    bind $path.e <Return>   [list ::tkutils::tkunumentry::_commit $path]
    bind $path.e <FocusOut> [list ::tkutils::tkunumentry::_commit $path]
    return $path
}

# --- public API ----------------------------------------------------------

# Numeric value, or "" if the field is empty.
proc ::tkutils::tkunumentry::getValue {path} {
    set s [string trim [$path.e get]]
    if {$s eq "" || $s eq "-" || $s eq "."} { return "" }
    return $s
}

proc ::tkutils::tkunumentry::setValue {path value} {
    variable state
    if {$value eq ""} { _replace $path ""; return "" }
    if {![string is double -strict $value]} {
        return -code error -errorcode {TKUTILS TKNUMENTRY VALUE} \
            "not a number: \"$value\""
    }
    set v [_clamp $path $value]
    _replace $path [format %.*f $state($path,dec) $v]
    return [getValue $path]
}

proc ::tkutils::tkunumentry::clear {path} { _replace $path ""; return "" }

# --- internals -----------------------------------------------------------

proc ::tkutils::tkunumentry::_replace {path text} {
    set v [$path.e cget -validate]
    $path.e configure -validate none
    $path.e delete 0 end
    if {$text ne ""} { $path.e insert 0 $text }
    $path.e configure -validate $v
}

# Allow an empty field, a lone "-", and partial numbers with at most -decimals
# fractional digits.
proc ::tkutils::tkunumentry::_validate {path proposed} {
    variable state
    if {$proposed in {"" "-"}} { return 1 }
    set dec $state($path,dec)
    if {$dec > 0} {
        return [regexp "^-?\\d*(\\.\\d{0,$dec})?\$" $proposed]
    }
    return [regexp {^-?\d*$} $proposed]
}

proc ::tkutils::tkunumentry::_clamp {path value} {
    variable state
    if {$state($path,min) ne "" && $value < $state($path,min)} {
        set value $state($path,min)
    }
    if {$state($path,max) ne "" && $value > $state($path,max)} {
        set value $state($path,max)
    }
    return $value
}

proc ::tkutils::tkunumentry::_commit {path} {
    variable state
    set s [getValue $path]
    if {$s ne ""} {
        set v [_clamp $path $s]
        _replace $path [format %.*f $state($path,dec) $v]
    }
    if {$state($path,cmd) ne ""} {
        uplevel #0 [linsert $state($path,cmd) end [getValue $path]]
    }
}

package provide tkutils::tkunumentry 0.1
