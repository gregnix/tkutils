# tkutils::tkuwheel -- forward mouse-wheel events to a scrollable target
#
# Solves a common Tk problem: embedded windows (e.g. a frame inside a text
# widget) and ordinary child widgets receive the mouse-wheel event themselves,
# so an outer scroller stops scrolling while the pointer is over them. This
# module re-binds the wheel on a widget -- and, by default, its whole subtree --
# so the events are forwarded to a target widget's yview / xview.
#
# Cross-platform: <MouseWheel> (Windows/macOS, uses %D) and <Button-4>/<Button-5>
# (X11). Direction is taken from the sign of the delta, so one notch scrolls by
# a fixed number of units regardless of the platform's delta magnitude.
#
# Pure Tk. Tcl/Tk 8.6+ / 9.x.
#
# Public API:
#   ::tkutils::tkuwheel::redirect target w ?-orient y|x|both? ?-amount N? \
#                                        ?-recursive 0|1?
#   ::tkutils::tkuwheel::unbind   w ?-recursive 0|1?
#
# Error codes: {TKUTILS TKUWHEEL <REASON>}  with REASON in {OPTION WINDOW}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils::tkuwheel {
    namespace export redirect unbind
}

proc ::tkutils::tkuwheel::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUWHEEL $reason] $msg
}

proc ::tkutils::tkuwheel::_parseOpts {arrName allowed argList} {
    upvar 1 $arrName opt
    if {[llength $argList] % 2} {
        _err OPTION "option \"[lindex $argList end]\" requires a value"
    }
    foreach {k v} $argList {
        if {[string index $k 0] ne "-"} { _err OPTION "expected an option, got \"$k\"" }
        set name [string range $k 1 end]
        if {$name ni $allowed} { _err OPTION "unknown option \"$k\"" }
        set opt($name) $v
    }
}

# delta: <Button-4> passes 1, <Button-5> passes -1, <MouseWheel> passes %D.
# delta > 0 means "scroll up" (towards the start) on every platform.
proc ::tkutils::tkuwheel::_wheel {target axis amount delta} {
    set n [expr {$delta > 0 ? -$amount : $amount}]
    catch {$target ${axis}view scroll $n units}
}

proc ::tkutils::tkuwheel::_bindTree {target w orient amount recursive} {
    switch -- $orient {
        y {
            bind $w <MouseWheel> [list ::tkutils::tkuwheel::_wheel $target y $amount %D]
            bind $w <Button-4>   [list ::tkutils::tkuwheel::_wheel $target y $amount 1]
            bind $w <Button-5>   [list ::tkutils::tkuwheel::_wheel $target y $amount -1]
        }
        x {
            bind $w <MouseWheel> [list ::tkutils::tkuwheel::_wheel $target x $amount %D]
            bind $w <Button-4>   [list ::tkutils::tkuwheel::_wheel $target x $amount 1]
            bind $w <Button-5>   [list ::tkutils::tkuwheel::_wheel $target x $amount -1]
        }
        both {
            bind $w <MouseWheel>       [list ::tkutils::tkuwheel::_wheel $target y $amount %D]
            bind $w <Button-4>         [list ::tkutils::tkuwheel::_wheel $target y $amount 1]
            bind $w <Button-5>         [list ::tkutils::tkuwheel::_wheel $target y $amount -1]
            bind $w <Shift-MouseWheel> [list ::tkutils::tkuwheel::_wheel $target x $amount %D]
            bind $w <Shift-Button-4>   [list ::tkutils::tkuwheel::_wheel $target x $amount 1]
            bind $w <Shift-Button-5>   [list ::tkutils::tkuwheel::_wheel $target x $amount -1]
        }
    }
    if {$recursive} {
        foreach c [winfo children $w] {
            _bindTree $target $c $orient $amount $recursive
        }
    }
}

# Forward wheel events on $w (and its subtree unless -recursive 0) to $target.
proc ::tkutils::tkuwheel::redirect {target w args} {
    if {![winfo exists $target]} { _err WINDOW "target window \"$target\" does not exist" }
    if {![winfo exists $w]}      { _err WINDOW "window \"$w\" does not exist" }
    array set opt {orient y amount 3 recursive 1}
    _parseOpts opt {orient amount recursive} $args
    if {$opt(orient) ni {y x both}} {
        _err OPTION "bad -orient \"$opt(orient)\": must be y, x, or both"
    }
    if {![string is integer -strict $opt(amount)] || $opt(amount) <= 0} {
        _err OPTION "bad -amount \"$opt(amount)\": must be a positive integer"
    }
    if {![string is boolean -strict $opt(recursive)]} {
        _err OPTION "bad -recursive \"$opt(recursive)\": must be boolean"
    }
    _bindTree $target $w $opt(orient) $opt(amount) [expr {$opt(recursive) ? 1 : 0}]
    return $w
}

# Remove wheel bindings set by redirect (subtree unless -recursive 0).
proc ::tkutils::tkuwheel::unbind {w args} {
    array set opt {recursive 1}
    _parseOpts opt {recursive} $args
    if {![string is boolean -strict $opt(recursive)]} {
        _err OPTION "bad -recursive \"$opt(recursive)\": must be boolean"
    }
    foreach ev {<MouseWheel> <Button-4> <Button-5>
                <Shift-MouseWheel> <Shift-Button-4> <Shift-Button-5>} {
        catch {::bind $w $ev {}}
    }
    if {$opt(recursive)} {
        foreach c [winfo children $w] { unbind $c }
    }
    return ""
}

package provide tkutils::tkuwheel 0.1
