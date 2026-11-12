# tkutils::tkuxdo -- drive a Tk user interface with real X input (xdotool)
# Description: keyboard and mouse input through the X server for end-to-end GUI tests
# Category: Tk · testing
#
# Where tkutils::tkutest generates events inside Tk, tkuxdo sends them through
# the X server with xdotool (XTEST), as a user's keyboard and mouse would:
# focus, keyboard map, key repeat of the window manager-less display, menu
# traversal with F10 and the arrow keys. Meant for an X display without a
# window manager, typically Xvfb (xvfb-run). X11 only; on other platforms
# `available` is 0 and tests should skip.
#
#   available                     -> 1 if xdotool and an X display are there
#   setup ?-layout de?            -> keyboard map for the display (setxkbmap)
#   pump ?ms?                     -> process events for ms (default 150)
#   focusWindow top               -> give the toplevel the X input focus
#   type text ?-delay ms?         -> type text (umlauts need a matching layout)
#   key keys…                     -> e.g. ctrl+s Return Tab shift+Tab Escape
#   click w ?-button n? ?-double 0|1? ?-x x? ?-y y? -> pointer to w, click
#   menuSelect top labelPath      -> F10, Right/Down, Return: "Datei/Firmendaten…"
#   dialog ?-title glob? ?-timeout ms? steps -> token (tkutils::tkutest::result)
#       steps: list of tkuxdo commands run once the dialog is there and focused,
#       e.g. {{type Rose} {key Tab} {type 12} {key Return}}
#   focusWidget w                  -> X focus to w's toplevel, Tk focus to w
#   choose combo value             -> readonly combobox by keyboard: Down posts the
#                                     list, arrows to the value, Return; waits for
#                                     the list to open and to close
#   chooseField name value         -> the same for a tkuform field of the dialog
#   clickField name                -> pointer click into a tkuform field of the dialog
#   clickButton label ?top?        -> click a button by label or path tail; without
#                                     top: in the dialog of the running steps
#
# All commands wait for the X server (xdotool --sync where it exists) and then
# pump the Tk event loop, so the result of an input is visible to the next
# line of the test. focusWindow and menuSelect avoid Tk's focus and menu;
# type, key and click have the same names as in tkutest, so import only one
# of the two namespaces. Errors: {TKUTILS TKUXDO <REASON>}. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tkutils::tkuopts 0.1
package require tkutils::tkutest 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuxdo {
    namespace export available unavailable windowManager setup pump focusWindow focusWidget type key click clickButton \
        choose chooseField clickField menuSelect dialog
    variable dialog ""
}

proc ::tkutils::tkuxdo::_error {kind msg} {
    return -code error -level 2 -errorcode [list TKUTILS TKUXDO $kind] $msg
}

# Input goes to whichever window has the X focus. On a desktop with a
# window manager that may be another program (a terminal, an editor), so
# tkuxdo works only on a display of its own, such as Xvfb, unless
# TKUXDO_DESKTOP=1 says otherwise.
proc ::tkutils::tkuxdo::available {} {
    expr {[unavailable] eq ""}
}

# why not available, "" if it is
proc ::tkutils::tkuxdo::unavailable {} {
    if {[tk windowingsystem] ne "x11" || ![info exists ::env(DISPLAY)]} { return "no X11 display" }
    if {[auto_execok xdotool] eq ""} { return "xdotool is not installed" }
    if {[windowManager] && !([info exists ::env(TKUXDO_DESKTOP)] && $::env(TKUXDO_DESKTOP) eq "1")} {
        return "a window manager runs on $::env(DISPLAY); use a display of its own (xvfb-run -a …) or set TKUXDO_DESKTOP=1"
    }
    return ""
}

# 1 if a window manager runs on the display (EWMH property on the root
# window, otherwise a reparented toplevel)
proc ::tkutils::tkuxdo::windowManager {} {
    if {[auto_execok xprop] ne ""} {
        if {![catch {exec xprop -root _NET_SUPPORTING_WM_CHECK} m]} {
            return [string match "*window id*" $m]
        }
    }
    update idletasks
    if {[winfo ismapped .]} { return [expr {[wm frame .] ne [winfo id .]}] }
    return 0
}

proc ::tkutils::tkuxdo::_x {args} {
    if {[catch {exec xdotool {*}$args} m]} { _error XDOTOOL "xdotool $args: $m" }
    return $m
}

proc ::tkutils::tkuxdo::setup {args} {
    # never change the keyboard map of someone's desktop by accident
    set why [unavailable]
    if {$why ne ""} { _error DISPLAY $why }
    array set o {-layout ""}
    array set o [::tkutils::tkuopts::merge TKUXDO [array get o] $args]
    if {![available]} { _error DISPLAY [unavailable] }
    if {$o(-layout) ne ""} {
        if {[catch {exec setxkbmap $o(-layout)} m]} { _error LAYOUT "setxkbmap $o(-layout): $m" }
    }
    pump
    return
}

proc ::tkutils::tkuxdo::pump {{ms 150}} {
    set ende [expr {[clock milliseconds] + $ms}]
    update
    while {[clock milliseconds] < $ende} {
        after 10
        update
    }
    return
}

proc ::tkutils::tkuxdo::focusWindow {top} {
    ::tkutils::tkutest::wait {[winfo ismapped $top]} -timeout 3000
    _x windowfocus --sync [wm frame $top]
    pump
    return
}

proc ::tkutils::tkuxdo::type {text args} {
    array set o {-delay 12}
    array set o [::tkutils::tkuopts::merge TKUXDO [array get o] $args]
    _x type --delay $o(-delay) -- $text
    pump [expr {150 + [string length $text] * 5}]
    return
}

proc ::tkutils::tkuxdo::key {args} {
    foreach k $args {
        _x key -- $k
        pump 80
    }
    pump
    return
}

proc ::tkutils::tkuxdo::click {w args} {
    array set o {-button 1 -double 0 -x "" -y ""}
    array set o [::tkutils::tkuopts::merge TKUXDO [array get o] $args]
    ::tkutils::tkutest::wait {[winfo ismapped $w]} -timeout 3000
    update
    set x [expr {[winfo rootx $w] + ($o(-x) eq "" ? [winfo width $w] / 2 : $o(-x))}]
    set y [expr {[winfo rooty $w] + ($o(-y) eq "" ? [winfo height $w] / 2 : $o(-y))}]
    # --sync waits until the pointer has moved: never when it is already
    # there (a second click on the same button), so move only if needed
    if {[winfo pointerxy $w] ne [list $x $y]} {
        _x mousemove --sync $x $y
        pump 50
    }
    if {$o(-double)} {
        _x click --repeat 2 --delay 60 $o(-button)
    } else {
        _x click $o(-button)
    }
    pump
    return
}

# Menu by keyboard: F10 posts the first menu with its first entry active,
# Right moves to the next cascade, Down to the next entry (separators are
# skipped by Tk), Return invokes. Nested cascades: Right opens them.
proc ::tkutils::tkuxdo::menuSelect {top path} {
    set m [$top cget -menu]
    if {$m eq ""} { _error MENU "$top has no menu bar" }
    set labels [split $path /]
    set keys {}
    set first 1
    foreach lab $labels {
        set idx ""
        set pos 0
        set last [$m index end]
        for {set i 0} {$last ne "none" && $i <= $last} {incr i} {
            if {[$m type $i] in {separator tearoff}} continue
            if {[$m entrycget $i -label] eq $lab} { set idx $i; break }
            # keyboard traversal skips disabled entries
            if {[$m entrycget $i -state] ne "disabled"} { incr pos }
        }
        if {$idx eq ""} { _error MENU "no entry \"$lab\" in $m" }
        if {[$m entrycget $idx -state] eq "disabled"} { _error MENU "\"$lab\" is disabled" }
        if {$first} {
            lappend keys F10 {*}[lrepeat $pos Right]
            set first 0
        } else {
            lappend keys {*}[lrepeat $pos Down]
            if {[$m type $idx] eq "cascade"} { lappend keys Right }
        }
        if {[$m type $idx] eq "cascade"} {
            set m [$m entrycget $idx -menu]
        } else {
            lappend keys Return
            focusWindow $top
            # after an entry whose command ran a modal dialog the keyboard
            # focus can stay on the menu bar, and F10 would then close it
            set f [::focus]
            if {$f ne "" && [winfo exists $f] && [winfo class $f] eq "Menu"} {
                ::focus -force $top
                pump 50
            }
            key {*}$keys
            return
        }
    }
    _error MENU "\"$path\" ends in a cascade"
}

# answer the next dialog with real input; see tkutils::tkutest::answer
proc ::tkutils::tkuxdo::dialog {args} {
    if {![llength $args]} { _error USAGE "dialog ?-title glob? ?-timeout ms? steps" }
    set steps [lindex $args end]
    array set o {-title * -timeout 5000}
    array set o [::tkutils::tkuopts::merge TKUXDO [array get o] [lrange $args 0 end-1]]
    ::tkutils::tkutest::answer -title $o(-title) -timeout $o(-timeout) -button "" \
        -script [list ::tkutils::tkuxdo::_steps $steps]
}

proc ::tkutils::tkuxdo::focusWidget {w} {
    focusWindow [winfo toplevel $w]
    ::focus -force $w
    pump 50
    return
}

# A pointer click on a readonly combobox posts or unposts its list depending
# on its state, and keys pressed before the list is mapped go elsewhere; so
# choose works with the keyboard and waits for the list each time.
proc ::tkutils::tkuxdo::choose {combo value} {
    set vals [$combo cget -values]
    set i [lsearch -exact $vals $value]
    if {$i < 0} { _error VALUE "\"$value\" is not a choice of $combo" }
    focusWidget $combo
    set lb $combo.popdown.f.l
    key Down
    ::tkutils::tkutest::wait {[winfo exists $lb] && [winfo ismapped $lb]} -timeout 3000
    set a [$lb index active]
    if {$a eq "" || $a < 0} { set a 0 }
    set n [expr {$i - $a}]
    if {$n > 0} { key {*}[lrepeat $n Down] }
    if {$n < 0} { key {*}[lrepeat [expr {-$n}] Up] }
    key Return
    ::tkutils::tkutest::wait {![winfo ismapped $lb]} -timeout 3000
    if {[$combo get] ne $value} { _error VALUE "$combo shows \"[$combo get]\", not \"$value\"" }
    return
}

proc ::tkutils::tkuxdo::chooseField {name value} {
    variable dialog
    if {$dialog eq ""} { _error USAGE "chooseField is a dialog step" }
    choose [::tkutils::tkuform::widgetOf $dialog.form $name] $value
    # back to the dialog window for the next steps
    focusWindow $dialog
}

proc ::tkutils::tkuxdo::clickField {name} {
    variable dialog
    if {$dialog eq ""} { _error USAGE "clickField is a dialog step" }
    set w [::tkutils::tkuform::widgetOf $dialog.form $name]
    # a field further down a long form may lie outside the visible part
    update
    click $w
}

proc ::tkutils::tkuxdo::clickButton {label {top ""}} {
    variable dialog
    if {$top eq ""} { set top $dialog }
    if {$top eq ""} { _error USAGE "clickButton outside a dialog needs top" }
    click [::tkutils::tkutest::findButton $top $label]
}

proc ::tkutils::tkuxdo::_steps {steps w} {
    variable dialog
    set dialog $w
    focusWindow $w
    try {
        foreach s $steps {
            ::tkutils::tkuxdo::[lindex $s 0] {*}[lrange $s 1 end]
        }
    } finally {
        set dialog ""
    }
    return [llength $steps]
}

package provide tkutils::tkuxdo 0.1
