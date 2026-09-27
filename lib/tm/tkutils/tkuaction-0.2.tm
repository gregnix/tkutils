# tkutils::tkuaction 0.2 -- action abstraction (one action, many widgets)
# Description: action abstraction (one action, many widgets)
# Category: Tk · widgets
#
# Define a UI action once (label, command, icon, accelerator, enabled/checked
# state) and register any number of widgets against it. A single setEnabled /
# setChecked / invoke then keeps every registered widget in sync. This module is
# the *model*; the rendering stays in the widgets (e.g. tkutils::tkutoolbar's
# `addAction`), so there is no duplicated toolbar/menu code. Pure Tk. 8.6+ / 9.x.
#
#   tkuaction::define  save -label "Save" -command {saveDoc} -accelerator "Ctrl+S"
#   tkuaction::register save $someButton        ;# usually done by the widget
#   tkuaction::addMenuItem $menu save           ;# command entry; follows setEnabled
#   tkuaction::setEnabled save 0                ;# greys out every bound widget
#   tkuaction::setEnabled save 0 $win           ;# only widgets in that toplevel
#   tkuaction::invoke  save                     ;# runs the command (if enabled)
#
# Error codes: {TKUTILS TKUACTION <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuaction {
    namespace export define exists get names delete \
        setEnabled setChecked getEnabled getChecked toggle invoke \
        register unregister addMenuItem registerMenu unregisterMenu \
        groupDefine groupSet groupAdd groupList reset
    variable actions
    variable groups
    variable winEnabled
    variable watched
    array set actions    {}
    array set groups     {}
    array set winEnabled {}
    array set watched    {}
}

# --- definition ------------------------------------------------------------

proc ::tkutils::tkuaction::define {name args} {
    variable actions
    set a [dict create command {} label $name icon {} iconChecked {} \
        checkable 0 enabled 1 checked 0 accelerator {} tooltip {} \
        compound {} widgets {} menus {}]
    foreach {opt val} $args {
        switch -- $opt {
            -command     { dict set a command $val }
            -label       { dict set a label $val }
            -icon        { dict set a icon $val }
            -iconChecked { dict set a iconChecked $val }
            -checkable   { dict set a checkable [expr {$val ? 1 : 0}] }
            -enabled     { dict set a enabled [expr {$val ? 1 : 0}] }
            -checked     { dict set a checked [expr {$val ? 1 : 0}] }
            -accelerator { dict set a accelerator $val }
            -tooltip     { dict set a tooltip $val }
            -compound    { dict set a compound $val }
            default {
                return -code error -errorcode {TKUTILS TKUACTION OPTION} \
                    "unknown option '$opt'"
            }
        }
    }
    # derive a tooltip from label (+ accelerator) when not given
    if {[dict get $a tooltip] eq ""} {
        set tip [dict get $a label]
        if {[dict get $a accelerator] ne ""} {
            append tip " ([dict get $a accelerator])"
        }
        dict set a tooltip $tip
    }
    set actions($name) $a
    return $name
}

proc ::tkutils::tkuaction::exists {name} {
    variable actions
    return [info exists actions($name)]
}

proc ::tkutils::tkuaction::get {name {key ""}} {
    variable actions
    if {![info exists actions($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOACTION} \
            "unknown action '$name'"
    }
    if {$key eq ""} { return $actions($name) }
    return [dict get $actions($name) $key]
}

proc ::tkutils::tkuaction::names {} {
    variable actions
    return [array names actions]
}

proc ::tkutils::tkuaction::delete {name} {
    variable actions
    if {[info exists actions($name)]} { unset actions($name) }
    _clearWin $name
    return
}

# --- registration ----------------------------------------------------------

# Bind a widget to an action; it is synced immediately and on every state
# change. Usually called by the rendering widget (e.g. tkutoolbar::addAction).
proc ::tkutils::tkuaction::register {name widget} {
    variable actions
    if {![info exists actions($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOACTION} \
            "unknown action '$name'"
    }
    set ws [dict get $actions($name) widgets]
    if {$widget ni $ws} {
        lappend ws $widget
        dict set actions($name) widgets $ws
    }
    _syncWidget $name $widget
    return $widget
}

proc ::tkutils::tkuaction::unregister {name widget} {
    variable actions
    if {![info exists actions($name)]} return
    set ws [dict get $actions($name) widgets]
    set i [lsearch -exact $ws $widget]
    if {$i >= 0} {
        dict set actions($name) widgets [lreplace $ws $i $i]
    }
    return
}

# Bind a menu command entry. The index is stored as a number so later
# additions do not shift it. Usually called by addMenuItem.
proc ::tkutils::tkuaction::registerMenu {name menu {index end}} {
    variable actions
    if {![info exists actions($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOACTION} \
            "unknown action '$name'"
    }
    if {![winfo exists $menu]} {
        return -code error -errorcode {TKUTILS TKUACTION WINDOW} \
            "unknown window '$menu'"
    }
    set idx [$menu index $index]
    set ms [dict get $actions($name) menus]
    set pair [list $menu $idx]
    if {$pair ni $ms} {
        lappend ms $pair
        dict set actions($name) menus $ms
    }
    _syncMenu $name $menu $idx
    return $idx
}

proc ::tkutils::tkuaction::unregisterMenu {name menu {index ""}} {
    variable actions
    if {![info exists actions($name)]} return
    set ms [dict get $actions($name) menus]
    set out {}
    foreach pair $ms {
        lassign $pair m idx
        if {$m eq $menu && ($index eq "" || $idx eq $index)} continue
        lappend out $pair
    }
    dict set actions($name) menus $out
    return
}

# Add a command entry from the action (label, accelerator, invoke) and
# register it so setEnabled greys that row.
proc ::tkutils::tkuaction::addMenuItem {menu name} {
    variable actions
    if {![info exists actions($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOACTION} \
            "unknown action '$name'"
    }
    set a $actions($name)
    set acc [dict get $a accelerator]
    if {$acc ne ""} {
        $menu add command -label [dict get $a label] -accelerator $acc \
            -command [list ::tkutils::tkuaction::invoke $name]
    } else {
        $menu add command -label [dict get $a label] \
            -command [list ::tkutils::tkuaction::invoke $name]
    }
    return [registerMenu $name $menu end]
}

proc ::tkutils::tkuaction::_top {w} {
    if {![winfo exists $w]} {
        return -code error -errorcode {TKUTILS TKUACTION WINDOW} \
            "unknown window '$w'"
    }
    return [_ownerTop $w]
}

# Menu widgets are themselves toplevels; the window they belong to is the
# first non-Menu ancestor (the frame that holds the menubar, or "." ).
proc ::tkutils::tkuaction::_ownerTop {w} {
    if {![winfo exists $w]} { return "" }
    if {[winfo class $w] eq "Menu"} {
        set p [winfo parent $w]
        while {$p ne "" && [winfo exists $p] && [winfo class $p] eq "Menu"} {
            set p [winfo parent $p]
        }
        if {$p ne "" && [winfo exists $p]} { return [winfo toplevel $p] }
    }
    return [winfo toplevel $w]
}

proc ::tkutils::tkuaction::_watchTop {top} {
    variable watched
    if {[info exists watched($top)]} return
    set watched($top) 1
    bind $top <Destroy> +[list ::tkutils::tkuaction::_forgetTop $top]
}

proc ::tkutils::tkuaction::_forgetTop {top} {
    variable winEnabled
    variable watched
    unset -nocomplain watched($top)
    foreach key [array names winEnabled *,$top] {
        unset -nocomplain winEnabled($key)
    }
}

proc ::tkutils::tkuaction::_clearWin {name} {
    variable winEnabled
    foreach key [array names winEnabled ${name},*] {
        unset -nocomplain winEnabled($key)
    }
}

proc ::tkutils::tkuaction::_effectiveEnabled {name widget} {
    variable actions
    variable winEnabled
    if {![info exists actions($name)]} { return 0 }
    if {[winfo exists $widget]} {
        set top [_ownerTop $widget]
        if {[info exists winEnabled($name,$top)]} {
            return $winEnabled($name,$top)
        }
    }
    return [dict get $actions($name) enabled]
}

proc ::tkutils::tkuaction::_syncWidget {name widget} {
    variable actions
    if {![winfo exists $widget]} return
    set a $actions($name)
    set state [expr {[_effectiveEnabled $name $widget] ? "normal" : "disabled"}]
    catch {$widget configure -state $state}
    if {[dict get $a checkable]} {
        set icon [dict get $a icon]
        set iconChecked [dict get $a iconChecked]
        set useIcon [expr {([dict get $a checked] && $iconChecked ne "") ? $iconChecked : $icon}]
        if {$useIcon ne ""} { catch {$widget configure -image $useIcon} }
        catch {
            if {[dict get $a checked]} { $widget state pressed } else { $widget state !pressed }
        }
    }
    return
}

proc ::tkutils::tkuaction::_syncMenu {name menu idx} {
    if {![winfo exists $menu]} return
    set state [expr {[_effectiveEnabled $name $menu] ? "normal" : "disabled"}]
    catch {$menu entryconfigure $idx -state $state}
    return
}

proc ::tkutils::tkuaction::_syncName {name {top ""}} {
    variable actions
    if {![info exists actions($name)]} return
    foreach w [dict get $actions($name) widgets] {
        if {![winfo exists $w]} continue
        if {$top ne "" && [_ownerTop $w] ne $top} continue
        _syncWidget $name $w
    }
    foreach pair [dict get $actions($name) menus] {
        lassign $pair m idx
        if {![winfo exists $m]} continue
        if {$top ne "" && [_ownerTop $m] ne $top} continue
        _syncMenu $name $m $idx
    }
}

# --- state API (the heart) -------------------------------------------------

proc ::tkutils::tkuaction::setEnabled {name enabled {win ""}} {
    variable actions
    variable winEnabled
    if {![info exists actions($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOACTION} \
            "unknown action '$name'"
    }
    set enabled [expr {$enabled ? 1 : 0}]
    if {$win eq ""} {
        dict set actions($name) enabled $enabled
        _clearWin $name
        _syncName $name
        return $enabled
    }
    set top [_top $win]
    set winEnabled($name,$top) $enabled
    _watchTop $top
    _syncName $name $top
    return $enabled
}

proc ::tkutils::tkuaction::setChecked {name checked} {
    variable actions
    if {![info exists actions($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOACTION} \
            "unknown action '$name'"
    }
    set checked [expr {$checked ? 1 : 0}]
    dict set actions($name) checked $checked
    set icon [dict get $actions($name) icon]
    set iconChecked [dict get $actions($name) iconChecked]
    set useIcon [expr {($checked && $iconChecked ne "") ? $iconChecked : $icon}]
    foreach w [dict get $actions($name) widgets] {
        if {![winfo exists $w]} continue
        if {$useIcon ne ""} { catch {$w configure -image $useIcon} }
        catch {
            if {$checked} { $w state pressed } else { $w state !pressed }
        }
    }
    return $checked
}

proc ::tkutils::tkuaction::getEnabled {name {win ""}} {
    variable actions
    variable winEnabled
    if {![info exists actions($name)]} { return 0 }
    if {$win eq ""} {
        return [dict get $actions($name) enabled]
    }
    set top [_top $win]
    if {[info exists winEnabled($name,$top)]} {
        return $winEnabled($name,$top)
    }
    return [dict get $actions($name) enabled]
}

proc ::tkutils::tkuaction::getChecked {name} {
    variable actions
    if {![info exists actions($name)]} { return 0 }
    return [dict get $actions($name) checked]
}

proc ::tkutils::tkuaction::toggle {name} {
    setChecked $name [expr {![getChecked $name]}]
    return [getChecked $name]
}

proc ::tkutils::tkuaction::invoke {name} {
    variable actions
    if {![info exists actions($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOACTION} \
            "unknown action '$name'"
    }
    if {![dict get $actions($name) enabled]} return
    if {[dict get $actions($name) checkable]} { toggle $name }
    set cmd [dict get $actions($name) command]
    if {$cmd ne ""} { uplevel #0 $cmd }
    return
}

# --- groups ----------------------------------------------------------------

proc ::tkutils::tkuaction::groupDefine {name actionList} {
    variable groups
    set groups($name) $actionList
    return $name
}

proc ::tkutils::tkuaction::groupSet {name enabled {win ""}} {
    variable groups
    if {![info exists groups($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOGROUP} \
            "unknown group '$name'"
    }
    foreach action $groups($name) {
        if {[exists $action]} { setEnabled $action $enabled $win }
    }
    return $enabled
}

proc ::tkutils::tkuaction::groupAdd {name action} {
    variable groups
    if {![info exists groups($name)]} { set groups($name) {} }
    if {$action ni $groups($name)} { lappend groups($name) $action }
    return $name
}

proc ::tkutils::tkuaction::groupList {{name ""}} {
    variable groups
    if {$name eq ""} { return [array names groups] }
    if {![info exists groups($name)]} { return {} }
    return $groups($name)
}

# --- teardown --------------------------------------------------------------

proc ::tkutils::tkuaction::reset {} {
    variable actions
    variable groups
    variable winEnabled
    variable watched
    array unset actions
    array unset groups
    array unset winEnabled
    array unset watched
    array set actions    {}
    array set groups     {}
    array set winEnabled {}
    array set watched    {}
    return
}

package provide tkutils::tkuaction 0.2
