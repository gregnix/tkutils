# tkutils::tkutoolbar -- toolbar widget (v0.2)
# Description: toolbar widget (v0.2)
# Category: Tk · widgets
#
# A toolbar holding buttons, toggles, dropdowns, separators and arbitrary
# embedded widgets, addressed by caller-chosen ids. Pure Tk, theme-native
# (built-in "Toolbutton" style; no hard-coded colours, dark-theme safe).
# Tcl/Tk 8.6+ / 9.x.
#
# New in 0.2 (all additive, the 0.1 positional API stays a strict subset):
#   - widget options -orient, -displaymode, -spacing, -padding, -buttonstyle
#   - per-button -icon, -tooltip, -shortcut, -compound, -displaymode, -side
#   - addDropdown (ttk::menubutton + menu)
#   - configureButton, setCallback, setDisplayMode, getDisplayMode
#   - keyboard shortcuts bound on the toplevel, auto-unbound on <Destroy>
#
# Error codes: {TKUTILS TKUTOOLBAR <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-
package require tkutils::tkuballoon

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutoolbar {
    namespace export widget addButton addToggle addSeparator addWidget \
        addDropdown addAction setEnabled buttonWidget items \
        configureButton setCallback setDisplayMode getDisplayMode
    variable state
}

# --- internal helpers ------------------------------------------------------

proc ::tkutils::tkutoolbar::_require {path} {
    variable state
    if {![info exists state($path,items)]} {
        return -code error -errorcode {TKUTILS TKUTOOLBAR NOTOOLBAR} \
            "unknown toolbar '$path'"
    }
}

proc ::tkutils::tkutoolbar::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    # release any toplevel shortcut bindings owned by this toolbar
    if {[info exists state($path,shortcuts)]} {
        foreach {top spec} $state($path,shortcuts) {
            catch {bind $top $spec {}}
        }
    }
    array unset state $path,*
}

# Pack a child according to the toolbar orientation.
proc ::tkutils::tkutoolbar::_pack {path w side} {
    variable state
    set sp $state($path,spacing)
    if {$state($path,orient) eq "vertical"} {
        pack $w -side top -padx 1 -pady $sp -fill x
    } else {
        pack $w -side $side -padx $sp -pady 1
    }
    return $w
}

# Register a child widget under id and record its meta dict.
proc ::tkutils::tkutoolbar::_register {path id w meta} {
    variable state
    if {$id ne ""} {
        dict set state($path,map) $id $w
        dict set state($path,info) $id $meta
        lappend state($path,items) $id
    }
    return $w
}

# Decide -text/-image/-compound for a given display mode.
proc ::tkutils::tkutoolbar::_visual {mode text icon compound} {
    switch -- $mode {
        icon {
            if {$icon ne ""} { return [list -image $icon] }
            return [list -text $text]
        }
        text {
            return [list -text $text]
        }
        both -
        default {
            if {$icon ne "" && $text ne ""} {
                return [list -text $text -image $icon -compound $compound]
            } elseif {$icon ne ""} {
                return [list -image $icon]
            } else {
                return [list -text $text]
            }
        }
    }
}

# --- construction ----------------------------------------------------------

# Build the toolbar under $path.
#   -orient      horizontal|vertical   (default horizontal)
#   -displaymode icon|text|both        (default both)
#   -spacing     pixels between items   (default 2)
#   -buttonstyle flat|raised  flat=Toolbutton, raised=bordered TButton (default flat)
#   -padding     frame padding          (default 2)
proc ::tkutils::tkutoolbar::widget {path args} {
    variable state
    array set opts {-orient horizontal -displaymode both -spacing 2 -padding 2 -buttonstyle flat}
    foreach {o v} $args {
        if {![info exists opts($o)]} {
            return -code error -errorcode {TKUTILS TKUTOOLBAR OPTION} \
                "unknown option '$o'"
        }
        set opts($o) $v
    }
    if {$opts(-orient) ni {horizontal vertical}} {
        return -code error -errorcode {TKUTILS TKUTOOLBAR ORIENT} \
            "bad orient '$opts(-orient)': must be horizontal or vertical"
    }
    if {$opts(-displaymode) ni {icon text both}} {
        return -code error -errorcode {TKUTILS TKUTOOLBAR DISPLAYMODE} \
            "bad displaymode '$opts(-displaymode)': must be icon, text or both"
    }
    if {$opts(-buttonstyle) ni {flat raised}} {
        return -code error -errorcode {TKUTILS TKUTOOLBAR BUTTONSTYLE} \
            "bad buttonstyle '$opts(-buttonstyle)': must be flat or raised"
    }

    ttk::frame $path -padding $opts(-padding)
    set state($path,count)       0
    set state($path,items)       {}
    set state($path,map)         [dict create]
    set state($path,info)        [dict create]
    set state($path,orient)      $opts(-orient)
    set state($path,displaymode) $opts(-displaymode)
    set state($path,spacing)     $opts(-spacing)
    set state($path,buttonstyle) $opts(-buttonstyle)
    set state($path,shortcuts)   {}
    bind $path <Destroy> [list ::tkutils::tkutoolbar::_cleanup $path %W]
    return $path
}

# Peel the toolbar-managed options out of a raw option list, returning
# {optsDict passthrough}. Unknown -options are passed through to the widget.
proc ::tkutils::tkutoolbar::_peel {optlist known} {
    set out  [dict create]
    set rest {}
    foreach {o v} $optlist {
        if {[dict exists $known $o]} {
            dict set out $o $v
        } else {
            lappend rest $o $v
        }
    }
    return [list $out $rest]
}

# Add a push button. Backward-compatible positional form:
#   addButton $path $id $label $command ?-option value ...?
# Recognised options: -icon -tooltip -shortcut -compound -displaymode -side.
# Any other -option is forwarded to ttk::button (e.g. -width).
proc ::tkutils::tkutoolbar::addButton {path id label command args} {
    variable state
    _require $path
    set known {-icon {} -tooltip {} -shortcut {} -compound left \
               -displaymode {} -side left}
    lassign [_peel $args $known] o pass
    set d [dict merge $known $o]
    set mode [dict get $d -displaymode]
    if {$mode eq ""} { set mode $state($path,displaymode) }
    set icon [dict get $d -icon]

    set w $path.w[incr state($path,count)]
    set vis [_visual $mode $label $icon [dict get $d -compound]]
    set bstyle [expr {$state($path,buttonstyle) eq "raised" ? "TButton" : "Toolbutton"}]
    ttk::button $w {*}$vis -command $command -style $bstyle {*}$pass
    _pack $path $w [dict get $d -side]

    set meta [dict create type button text $label icon $icon \
        command $command compound [dict get $d -compound]]
    _register $path $id $w $meta

    set tip [dict get $d -tooltip]
    if {$tip ne ""} { _attachTip $w $tip }
    set sc [dict get $d -shortcut]
    if {$sc ne ""} { _bindShortcut $path $id $sc }
    return $w
}

# Add a toggle (checkbutton) bound to $varName. Positional form preserved:
#   addToggle $path $id $label $varName ?-option value ...?
proc ::tkutils::tkutoolbar::addToggle {path id label varName args} {
    variable state
    _require $path
    set known {-icon {} -tooltip {} -compound left -displaymode {} \
               -side left -command {} -onvalue 1 -offvalue 0}
    lassign [_peel $args $known] o pass
    set d [dict merge $known $o]
    set mode [dict get $d -displaymode]
    if {$mode eq ""} { set mode $state($path,displaymode) }
    set icon [dict get $d -icon]

    set w $path.w[incr state($path,count)]
    set vis [_visual $mode $label $icon [dict get $d -compound]]
    ttk::checkbutton $w {*}$vis -variable $varName \
        -onvalue [dict get $d -onvalue] -offvalue [dict get $d -offvalue] \
        -style Toolbutton {*}$pass
    if {[dict get $d -command] ne ""} {
        $w configure -command [dict get $d -command]
    }
    _pack $path $w [dict get $d -side]

    set meta [dict create type toggle text $label icon $icon \
        variable $varName compound [dict get $d -compound]]
    _register $path $id $w $meta

    set tip [dict get $d -tooltip]
    if {$tip ne ""} { _attachTip $w $tip }
    return $w
}

# Add a dropdown (menubutton). -menu is a list of {label command} pairs,
# with "-" producing a separator.
#   addDropdown $path $id $label ?-icon img? ?-menu spec? ?-tooltip s? ...
proc ::tkutils::tkutoolbar::addDropdown {path id label args} {
    variable state
    _require $path
    set known {-icon {} -tooltip {} -menu {} -compound left \
               -displaymode {} -side left}
    lassign [_peel $args $known] o pass
    set d [dict merge $known $o]
    set mode [dict get $d -displaymode]
    if {$mode eq ""} { set mode $state($path,displaymode) }
    set icon [dict get $d -icon]

    set w  $path.w[incr state($path,count)]
    set mw $w.menu
    set vis [_visual $mode $label $icon [dict get $d -compound]]
    set bstyle [expr {$state($path,buttonstyle) eq "raised" ? "TMenubutton" : "Toolbutton"}]
    ttk::menubutton $w {*}$vis -style $bstyle -menu $mw {*}$pass
    menu $mw -tearoff 0
    foreach item [dict get $d -menu] {
        if {$item eq "-"} {
            $mw add separator
        } else {
            lassign $item lbl cmd
            $mw add command -label $lbl -command $cmd
        }
    }
    _pack $path $w [dict get $d -side]

    set meta [dict create type dropdown text $label icon $icon menu $mw \
        compound [dict get $d -compound]]
    _register $path $id $w $meta

    set tip [dict get $d -tooltip]
    if {$tip ne ""} { _attachTip $w $tip }
    return $w
}

proc ::tkutils::tkutoolbar::addSeparator {path} {
    variable state
    _require $path
    set w $path.w[incr state($path,count)]
    if {$state($path,orient) eq "vertical"} {
        ttk::separator $w -orient horizontal
        pack $w -side top -fill x -padx 1 -pady 3
    } else {
        ttk::separator $w -orient vertical
        pack $w -side left -fill y -padx 3 -pady 1
    }
    return $w
}

# Embed an already-created child widget of $path into the toolbar.
proc ::tkutils::tkutoolbar::addWidget {path id w {side left}} {
    _require $path
    _pack $path $w $side
    set meta [dict create type widget]
    return [_register $path $id $w $meta]
}

# --- state / mutation ------------------------------------------------------

# Enable or disable an item by id.
proc ::tkutils::tkutoolbar::setEnabled {path id enabled} {
    variable state
    _require $path
    set w [_widgetOf $path $id]
    if {$enabled} { $w state !disabled } else { $w state disabled }
    return $enabled
}

proc ::tkutils::tkutoolbar::_widgetOf {path id} {
    variable state
    if {![dict exists $state($path,map) $id]} {
        return -code error -errorcode {TKUTILS TKUTOOLBAR NOITEM} \
            "unknown item '$id'"
    }
    return [dict get $state($path,map) $id]
}

# Return the widget path for an item id.
proc ::tkutils::tkutoolbar::buttonWidget {path id} {
    _require $path
    return [_widgetOf $path $id]
}

# Return the list of item ids in insertion order.
proc ::tkutils::tkutoolbar::items {path} {
    variable state
    _require $path
    return $state($path,items)
}

# Reconfigure a button's widget options and keep tracked meta in sync.
proc ::tkutils::tkutoolbar::configureButton {path id args} {
    variable state
    _require $path
    set w [_widgetOf $path $id]
    $w configure {*}$args
    set meta [dict get $state($path,info) $id]
    foreach {o v} $args {
        switch -- $o {
            -text    { dict set meta text $v }
            -image   { dict set meta icon $v }
            -command { dict set meta command $v }
        }
    }
    dict set state($path,info) $id $meta
    return $w
}

# Replace a button's callback after creation.
proc ::tkutils::tkutoolbar::setCallback {path id command} {
    variable state
    _require $path
    set w [_widgetOf $path $id]
    catch {$w configure -command $command}
    set meta [dict get $state($path,info) $id]
    dict set meta command $command
    dict set state($path,info) $id $meta
    return $command
}

# Switch the whole toolbar between icon|text|both, reconfiguring every item.
proc ::tkutils::tkutoolbar::setDisplayMode {path mode} {
    variable state
    _require $path
    if {$mode ni {icon text both}} {
        return -code error -errorcode {TKUTILS TKUTOOLBAR DISPLAYMODE} \
            "bad displaymode '$mode': must be icon, text or both"
    }
    set state($path,displaymode) $mode
    dict for {id meta} $state($path,info) {
        if {[dict get $meta type] ni {button toggle dropdown}} continue
        set w [dict get $state($path,map) $id]
        if {![winfo exists $w]} continue
        set vis [_visual $mode [dict get $meta text] [dict get $meta icon] \
            [dict get $meta compound]]
        # clear both first so a mode with only one of them wins cleanly
        $w configure -text "" -image "" -compound none
        $w configure {*}$vis
    }
    return $mode
}

proc ::tkutils::tkutoolbar::getDisplayMode {path} {
    variable state
    _require $path
    return $state($path,displaymode)
}

# --- shortcuts -------------------------------------------------------------

proc ::tkutils::tkutoolbar::_bindShortcut {path id spec} {
    variable state
    set w   [dict get $state($path,map) $id]
    set top [winfo toplevel $path]
    # invoke through the widget so disabled state is respected
    bind $top <$spec> [list ::tkutils::tkutoolbar::_invoke $w]
    lappend state($path,shortcuts) $top <$spec>
    return
}

proc ::tkutils::tkutoolbar::_invoke {w} {
    if {[winfo exists $w] && ![catch {$w instate disabled} dis] && !$dis} {
        catch {$w invoke}
    }
}

# --- action integration (optional: needs tkutils::tkuaction) ---------------

# Create a toolbar button from a registered action. The button invokes the
# action (so enabled/checkable logic is centralised) and is registered with it,
# so tkuaction::setEnabled / setChecked update this button too.
proc ::tkutils::tkutoolbar::addAction {path name {id ""}} {
    _require $path
    package require tkutils::tkuaction
    if {$id eq ""} { set id $name }
    set label [::tkutils::tkuaction::get $name label]
    set icon  [::tkutils::tkuaction::get $name icon]
    set tip   [::tkutils::tkuaction::get $name tooltip]
    set w [addButton $path $id $label [list ::tkutils::tkuaction::invoke $name] \
        -icon $icon -tooltip $tip]
    ::tkutils::tkuaction::register $name $w
    return $w
}

# --- tooltip (delegated to tkutils::tkuballoon) ----------------------------

proc ::tkutils::tkutoolbar::_attachTip {w text} {
    ::tkutils::tkuballoon::add $w $text
}

package provide tkutils::tkutoolbar 0.2
