# tkutils::tkuaction -- action abstraction (one action, many widgets)
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
#   tkuaction::setEnabled save 0                ;# greys out every bound widget
#   tkuaction::invoke  save                     ;# runs the command (if enabled)
#
# Error codes: {TKUTILS TKUACTION <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuaction {
    namespace export define exists get names delete \
        setEnabled setChecked getEnabled getChecked toggle invoke \
        register unregister \
        groupDefine groupSet groupAdd groupList reset
    variable actions
    variable groups
    array set actions {}
    array set groups  {}
}

# --- definition ------------------------------------------------------------

proc ::tkutils::tkuaction::define {name args} {
    variable actions
    set a [dict create command {} label $name icon {} iconChecked {} \
        checkable 0 enabled 1 checked 0 accelerator {} tooltip {} \
        compound {} widgets {}]
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

proc ::tkutils::tkuaction::_syncWidget {name widget} {
    variable actions
    if {![winfo exists $widget]} return
    set a $actions($name)
    set state [expr {[dict get $a enabled] ? "normal" : "disabled"}]
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

# --- state API (the heart) -------------------------------------------------

proc ::tkutils::tkuaction::setEnabled {name enabled} {
    variable actions
    if {![info exists actions($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOACTION} \
            "unknown action '$name'"
    }
    set enabled [expr {$enabled ? 1 : 0}]
    dict set actions($name) enabled $enabled
    set state [expr {$enabled ? "normal" : "disabled"}]
    foreach w [dict get $actions($name) widgets] {
        if {[winfo exists $w]} { catch {$w configure -state $state} }
    }
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

proc ::tkutils::tkuaction::getEnabled {name} {
    variable actions
    if {![info exists actions($name)]} { return 0 }
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

proc ::tkutils::tkuaction::groupSet {name enabled} {
    variable groups
    if {![info exists groups($name)]} {
        return -code error -errorcode {TKUTILS TKUACTION NOGROUP} \
            "unknown group '$name'"
    }
    foreach action $groups($name) {
        if {[exists $action]} { setEnabled $action $enabled }
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
    array unset actions
    array unset groups
    array set actions {}
    array set groups  {}
    return
}

package provide tkutils::tkuaction 0.1
