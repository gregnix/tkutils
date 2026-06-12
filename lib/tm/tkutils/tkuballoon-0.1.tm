# tkutils::tkuballoon -- balloon help / tooltips for any widget
#
# Attach a short help text to a widget; it pops up in a small, theme-native
# balloon after a hover delay and disappears on leave, click or motion away.
# One shared popup is reused, so many balloons cost nothing while idle.
# Per-widget state is released automatically on <Destroy>. Pure Tk. 8.6+ / 9.x.
#
#   tkuballoon::add    $w "Save the file"  ?-delay ms? ?-wraplength px?
#   tkuballoon::clear  $w
#   tkuballoon::configure ?-delay ms? ?-wraplength px?   ;# global defaults
#   tkuballoon::enable / tkuballoon::disable             ;# globally on/off
#
# Error codes: {TKUTILS TKUBALLOON <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuballoon {
    namespace export add clear configure cget enable disable
    variable state            ;# per-widget: $w,text $w,delay $w,wraplength
    variable defaults
    array set defaults {-delay 600 -wraplength 320}
    variable enabled 1
    variable tipWin  ".tkuballoon_tip"
    variable after   ""
}

# --- global configuration --------------------------------------------------

proc ::tkutils::tkuballoon::configure {args} {
    variable defaults
    foreach {o v} $args {
        if {![info exists defaults($o)]} {
            return -code error -errorcode {TKUTILS TKUBALLOON OPTION} \
                "unknown option '$o'"
        }
        if {![string is integer -strict $v] || $v < 0} {
            return -code error -errorcode {TKUTILS TKUBALLOON VALUE} \
                "option '$o' needs a non-negative integer"
        }
        set defaults($o) $v
    }
    return [array get defaults]
}

proc ::tkutils::tkuballoon::cget {option} {
    variable defaults
    if {![info exists defaults($option)]} {
        return -code error -errorcode {TKUTILS TKUBALLOON OPTION} \
            "unknown option '$option'"
    }
    return $defaults($option)
}

proc ::tkutils::tkuballoon::enable {} {
    variable enabled
    set enabled 1
    return
}

proc ::tkutils::tkuballoon::disable {} {
    variable enabled
    set enabled 0
    _hide
    return
}

# --- attach / detach -------------------------------------------------------

# Attach (or replace) the balloon text for a widget.
proc ::tkutils::tkuballoon::add {w text args} {
    variable state
    variable defaults
    if {![winfo exists $w]} {
        return -code error -errorcode {TKUTILS TKUBALLOON NOWIDGET} \
            "no such widget '$w'"
    }
    array set opts [array get defaults]
    foreach {o v} $args {
        if {![info exists opts($o)]} {
            return -code error -errorcode {TKUTILS TKUBALLOON OPTION} \
                "unknown option '$o'"
        }
        set opts($o) $v
    }
    set first [expr {![info exists state($w,text)]}]
    set state($w,text)       $text
    set state($w,delay)      $opts(-delay)
    set state($w,wraplength) $opts(-wraplength)
    if {$first} {
        bind $w <Enter>       +[list ::tkutils::tkuballoon::_enter %W]
        bind $w <Leave>       +[list ::tkutils::tkuballoon::_hide]
        bind $w <ButtonPress> +[list ::tkutils::tkuballoon::_hide]
        bind $w <Destroy>     +[list ::tkutils::tkuballoon::_cleanup $w %W]
    }
    return $w
}

# Remove the balloon from a widget.
proc ::tkutils::tkuballoon::clear {w} {
    variable state
    if {[info exists state($w,text)]} {
        array unset state $w,*
    }
    return
}

proc ::tkutils::tkuballoon::_cleanup {w eventW} {
    variable state
    if {$w ne $eventW} return
    array unset state $w,*
    return
}

# --- popup mechanics -------------------------------------------------------

proc ::tkutils::tkuballoon::_enter {w} {
    variable state
    variable enabled
    variable after
    if {!$enabled} return
    if {![info exists state($w,text)]} return
    if {$after ne ""} { ::after cancel $after }
    set after [::after $state($w,delay) \
        [list ::tkutils::tkuballoon::_show $w]]
    return
}

proc ::tkutils::tkuballoon::_show {w} {
    variable state
    variable tipWin
    variable after
    set after ""
    if {![winfo exists $w]} return
    if {![info exists state($w,text)]} return
    catch {destroy $tipWin}
    toplevel $tipWin -borderwidth 1 -relief solid
    wm overrideredirect $tipWin 1
    catch {wm attributes $tipWin -topmost 1}
    pack [ttk::label $tipWin.l -text $state($w,text) -padding {6 3} \
        -justify left -wraplength $state($w,wraplength)]
    # position just below the pointer's widget, clamped to the screen
    update idletasks
    set x [winfo pointerx $w]
    set y [expr {[winfo rooty $w] + [winfo height $w] + 2}]
    set sw [winfo screenwidth $w]
    set tw [winfo reqwidth $tipWin]
    if {$x + $tw > $sw} { set x [expr {$sw - $tw - 2}] }
    if {$x < 0} { set x 0 }
    wm geometry $tipWin +$x+$y
    return
}

proc ::tkutils::tkuballoon::_hide {} {
    variable tipWin
    variable after
    if {$after ne ""} { ::after cancel $after; set after "" }
    catch {destroy $tipWin}
    return
}

package provide tkutils::tkuballoon 0.1
