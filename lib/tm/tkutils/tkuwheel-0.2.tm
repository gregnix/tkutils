# tkutils::tkuwheel -- forward mouse-wheel events to a scrollable target
# Description: forward mouse-wheel events to a scrollable target
# Category: Tk · widgets
#
# Solves a common Tk problem: embedded windows (e.g. a frame inside a text
# widget) and ordinary child widgets receive the mouse-wheel event themselves,
# so an outer scroller stops scrolling while the pointer is over them. This
# module re-binds the wheel on a widget -- and, by default, its whole subtree --
# so the events are forwarded to a target widget's yview / xview.
#
# Cross-platform: <MouseWheel> (Windows/macOS, uses %D) and <Button-4>/<Button-5>
# (X11 vertical). For horizontal scrolling on X11 the tilt-wheel buttons
# <Button-6>/<Button-7> are honoured as well. Direction is taken from the sign
# of the delta, so one notch scrolls by a fixed number of units regardless of
# the platform's delta magnitude.
#
# Bindings are attached directly on each widget (widget-level, i.e. before the
# widget's class bindings), so the forward wins over a child's own wheel
# handling.
#
# Pure Tk. Tcl/Tk 8.6+ / 9.x.
#
# Public API:
#   ::tkutils::tkuwheel::redirect target w ?-orient y|x|both? ?-amount N? \
#                                        ?-recursive 0|1? ?-dynamic 0|1?
#   ::tkutils::tkuwheel::unbind   w ?-recursive 0|1?
#
# -recursive 1 (default) also binds the whole current subtree.
# -dynamic 1 additionally keeps the subtree covered when widgets are added
#   later (e.g. a palette populated at runtime): a <Configure> hook on the
#   root re-applies the binding to any new descendants (coalesced via
#   `after idle`). Default 0 -- for a static tree a single redirect is enough.
#
# Error codes: {TKUTILS TKUWHEEL <REASON>}  with REASON in {OPTION WINDOW}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils::tkuwheel {
    namespace export redirect unbind
    # Per-root dynamic state and idle-coalescing handles.
    variable dyn   ;  array set dyn   {}
    variable sched ;  array set sched {}
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

# delta: <Button-4>/<Button-6> pass 1, <Button-5>/<Button-7> pass -1,
# <MouseWheel> passes %D.  delta > 0 means "towards the start" on every platform.
proc ::tkutils::tkuwheel::_wheel {target axis amount delta} {
    set n [expr {$delta > 0 ? -$amount : $amount}]
    catch {$target ${axis}view scroll $n units}
}

# All wheel events this module ever binds (used by unbind).
proc ::tkutils::tkuwheel::_events {} {
    return {<MouseWheel> <Button-4> <Button-5> <Button-6> <Button-7>
            <Shift-MouseWheel> <Shift-Button-4> <Shift-Button-5>}
}

proc ::tkutils::tkuwheel::_bindOne {target w orient amount} {
    set p ::tkutils::tkuwheel::_wheel
    switch -- $orient {
        y {
            bind $w <MouseWheel> [list $p $target y $amount %D]
            bind $w <Button-4>   [list $p $target y $amount 1]
            bind $w <Button-5>   [list $p $target y $amount -1]
        }
        x {
            # single horizontal axis: the plain wheel scrolls it, plus the X11
            # tilt-wheel buttons (Button-6/7 exist only on Tk 8.7+ -> catch).
            bind $w <MouseWheel> [list $p $target x $amount %D]
            bind $w <Button-4>   [list $p $target x $amount 1]
            bind $w <Button-5>   [list $p $target x $amount -1]
            catch { bind $w <Button-6> [list $p $target x $amount 1] }
            catch { bind $w <Button-7> [list $p $target x $amount -1] }
        }
        both {
            bind $w <MouseWheel>       [list $p $target y $amount %D]
            bind $w <Button-4>         [list $p $target y $amount 1]
            bind $w <Button-5>         [list $p $target y $amount -1]
            bind $w <Shift-MouseWheel> [list $p $target x $amount %D]
            bind $w <Shift-Button-4>   [list $p $target x $amount 1]
            bind $w <Shift-Button-5>   [list $p $target x $amount -1]
            catch { bind $w <Button-6> [list $p $target x $amount 1] }
            catch { bind $w <Button-7> [list $p $target x $amount -1] }
        }
    }
}

proc ::tkutils::tkuwheel::_bindTree {target w orient amount recursive} {
    _bindOne $target $w $orient $amount
    if {$recursive} {
        foreach c [winfo children $w] {
            _bindTree $target $c $orient $amount $recursive
        }
    }
}

# <Configure> hook for -dynamic: coalesce and re-apply to new descendants.
proc ::tkutils::tkuwheel::_onConfigure {target w orient amount} {
    variable dyn
    variable sched
    if {![info exists dyn($w)] || !$dyn($w)} return
    if {[info exists sched($w)]} return
    set sched($w) [after idle [list ::tkutils::tkuwheel::_reapply \
        $target $w $orient $amount]]
}
proc ::tkutils::tkuwheel::_reapply {target w orient amount} {
    variable dyn
    variable sched
    unset -nocomplain sched($w)
    if {![winfo exists $w]} { unset -nocomplain dyn($w); return }
    if {![info exists dyn($w)] || !$dyn($w)} return
    _bindTree $target $w $orient $amount 1
}

# Forward wheel events on $w (and its subtree unless -recursive 0) to $target.
proc ::tkutils::tkuwheel::redirect {target w args} {
    variable dyn
    if {![winfo exists $target]} { _err WINDOW "target window \"$target\" does not exist" }
    if {![winfo exists $w]}      { _err WINDOW "window \"$w\" does not exist" }
    array set opt {orient y amount 3 recursive 1 dynamic 0}
    _parseOpts opt {orient amount recursive dynamic} $args
    if {$opt(orient) ni {y x both}} {
        _err OPTION "bad -orient \"$opt(orient)\": must be y, x, or both"
    }
    if {![string is integer -strict $opt(amount)] || $opt(amount) <= 0} {
        _err OPTION "bad -amount \"$opt(amount)\": must be a positive integer"
    }
    if {![string is boolean -strict $opt(recursive)]} {
        _err OPTION "bad -recursive \"$opt(recursive)\": must be boolean"
    }
    if {![string is boolean -strict $opt(dynamic)]} {
        _err OPTION "bad -dynamic \"$opt(dynamic)\": must be boolean"
    }
    set rec [expr {$opt(recursive) ? 1 : 0}]
    _bindTree $target $w $opt(orient) $opt(amount) $rec
    if {$opt(dynamic)} {
        set dyn($w) 1
        bind $w <Configure> +[list ::tkutils::tkuwheel::_onConfigure \
            $target $w $opt(orient) $opt(amount)]
    }
    return $w
}

# Remove wheel bindings set by redirect (subtree unless -recursive 0) and stop
# any dynamic re-application on this root.
proc ::tkutils::tkuwheel::unbind {w args} {
    variable dyn
    array set opt {recursive 1}
    _parseOpts opt {recursive} $args
    if {![string is boolean -strict $opt(recursive)]} {
        _err OPTION "bad -recursive \"$opt(recursive)\": must be boolean"
    }
    set dyn($w) 0
    unset -nocomplain dyn($w)
    foreach ev [_events] { catch {::bind $w $ev {}} }
    if {$opt(recursive)} {
        foreach c [winfo children $w] { unbind $c }
    }
    return ""
}

package provide tkutils::tkuwheel 0.2
