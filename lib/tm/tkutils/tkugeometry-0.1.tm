# tkutils::tkugeometry -- remember window size and position between runs
# Description: save and restore a toplevel's size, position and zoom state, kept on the screen
# Category: Tk · widgets
#
# Twelve apps called [wm geometry] themselves to remember their window. This
# does it once, stored per app through tclutils::tusettings in its own file
# (<config dir>/<app>/geometry.ini), so an app that saves its own settings
# dict at exit cannot overwrite it.
#
#   tkugeometry::track . myapp            ;# restore now, save when . is destroyed
#   tkugeometry::restore .dlg myapp -default 400x300
#   tkugeometry::save .dlg myapp
#
# A stored position that is no longer on the screen -- the second monitor is
# gone, the resolution shrank -- is not used: the window keeps its size
# (shrunk to the screen if needed) and is centred. "On the screen" means
# Tk's virtual root (all monitors as one rectangle on X11; on Windows the
# virtual desktop): a gap between monitors of different size is not seen.
#
# Zoom state: "zoomed" is stored and restored where Tk has it
# (wm state zoomed on Windows/macOS, wm attributes -zoomed on X11).
#
# Errors: {TKUTILS TKUGEOMETRY WINDOW} (not a toplevel). Others come from
# tusettings (bad app name, unreadable file).
#
# Pure Tk + tclutils. Tcl/Tk 8.6+ / 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::common 0.1
package require tclutils::tusettings 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkugeometry {
    namespace export save restore track key
    variable version 0.1
    variable file geometry          ;# tusettings -name
}

proc ::tkutils::tkugeometry::_toplevel {w} {
    if {![winfo exists $w] || [winfo toplevel $w] ne $w} {
        return -code error -errorcode {TKUTILS TKUGEOMETRY WINDOW} \
            "\"$w\" is not an existing toplevel"
    }
}

# Settings key of a window: "." -> main, ".dlg.x" -> dlg.x
proc ::tkutils::tkugeometry::key {w} {
    if {$w eq "."} { return main }
    return [string range $w 1 end]
}

proc ::tkutils::tkugeometry::_zoomed {w} {
    if {[tk windowingsystem] eq "x11"} {
        if {![catch {wm attributes $w -zoomed} z]} { return [expr {$z ? 1 : 0}] }
        return 0
    }
    return [expr {[wm state $w] eq "zoomed"}]
}

proc ::tkutils::tkugeometry::_zoom {w} {
    if {[tk windowingsystem] eq "x11"} {
        catch {wm attributes $w -zoomed 1}
    } else {
        catch {wm state $w zoomed}
    }
}

# Store W's geometry and zoom state for APP. Returns the geometry string.
proc ::tkutils::tkugeometry::save {w app args} {
    variable file
    _toplevel $w
    set opts [::tclutils::common::parseOptions [list -key [key $w]] {*}$args]
    return [_store $w $app [dict get $opts -key]]
}

# Write without the toplevel check: inside <Destroy> [winfo exists] is
# already 0, while [wm geometry] still answers.
proc ::tkutils::tkugeometry::_store {w app k} {
    variable file
    set geo [wm geometry $w]
    set s [::tclutils::tusettings::load $app -name $file]
    dict set s $k geometry $geo
    dict set s $k zoomed [_zoomed $w]
    ::tclutils::tusettings::save $app $s -name $file
    return $geo
}

# Parse WxH+X+Y (X/Y may be negative, "+-10"). Returns {w h x y} or {}.
proc ::tkutils::tkugeometry::_parse {geo} {
    if {[regexp {^=?(\d+)x(\d+)([+-]-?\d+)([+-]-?\d+)$} $geo -> gw gh gx gy]} {
        foreach v {gx gy} {
            set t [set $v]
            # "+-10" means -10; "-10" means 10 from the right/bottom edge,
            # which a saved [wm geometry] never produces -- treat as offscreen.
            if {[string match +* $t]} {
                set $v [string range $t 1 end]
            } else {
                return {}
            }
        }
        return [list $gw $gh $gx $gy]
    }
    return {}
}

# Bring a stored rectangle onto the virtual root. Returns a geometry string.
proc ::tkutils::tkugeometry::_fit {w gw gh gx gy} {
    set rx [winfo vrootx $w]; set ry [winfo vrooty $w]
    set rw [winfo vrootwidth $w]; set rh [winfo vrootheight $w]
    # vrootx/y are the root's offset as seen from the window: 0 or negative
    set left [expr {-$rx}]; set top [expr {-$ry}]
    set gw [expr {min($gw, $rw)}]; set gh [expr {min($gh, $rh)}]
    # usable: the top strip (title bar region, 100x30) must be on the screen
    set visible [expr {
        $gx + $gw - 100 >= $left && $gx + 100 <= $left + $rw &&
        $gy >= $top && $gy + 30 <= $top + $rh
    }]
    if {!$visible} {
        set sw [winfo screenwidth $w]; set sh [winfo screenheight $w]
        set gw [expr {min($gw, $sw)}]; set gh [expr {min($gh, $sh)}]
        set gx [expr {max(0, ($sw - $gw) / 2)}]
        set gy [expr {max(0, ($sh - $gh) / 2)}]
    }
    return "${gw}x${gh}+${gx}+${gy}"
}

# Apply the stored geometry of W for APP. Without a stored value -default
# (a size such as 800x600, or a full geometry) is used, if given. Returns the
# geometry applied, "" if none.
proc ::tkutils::tkugeometry::restore {w app args} {
    variable file
    _toplevel $w
    set opts [::tclutils::common::parseOptions \
        [list -key [key $w] -default ""] {*}$args]
    set k [dict get $opts -key]
    set s [::tclutils::tusettings::load $app -name $file]
    set geo [::tclutils::tusettings::value $s $k geometry ""]
    set zoomed [::tclutils::tusettings::value $s $k zoomed 0]
    set rect [_parse $geo]
    if {[llength $rect]} {
        set geo [_fit $w {*}$rect]
    } elseif {[dict get $opts -default] ne ""} {
        set geo [dict get $opts -default]
        set zoomed 0
    } else {
        return ""
    }
    wm geometry $w $geo
    if {$zoomed} { _zoom $w }
    return $geo
}

# Restore W now and save it when W is destroyed. Uses an own bindtag, so the
# app's <Destroy> bindings stay untouched.
proc ::tkutils::tkugeometry::track {w app args} {
    _toplevel $w
    set opts [::tclutils::common::parseOptions \
        [list -key [key $w] -default ""] {*}$args]
    set k [dict get $opts -key]
    set geo [restore $w $app -key $k -default [dict get $opts -default]]
    set tag tkugeometry[string map {. _} $w]
    bind $tag <Destroy> [list ::tkutils::tkugeometry::_onDestroy %W $w $app $k]
    if {$tag ni [bindtags $w]} { bindtags $w [linsert [bindtags $w] 0 $tag] }
    return $geo
}

proc ::tkutils::tkugeometry::_onDestroy {W w app k} {
    if {$W ne $w} return
    catch {_store $w $app $k}
}

package provide tkutils::tkugeometry 0.1
