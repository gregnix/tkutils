# tkutils::tkucontextmenu -- generic right-click context menu (from uitoolkit)
#
# Build context menus declaratively, attach them to widgets, and show them on
# the platform context button. Supports command/check/radio items, cascades,
# accelerators, icons, dynamic update handlers and a spec-driven builder.
# Pure Tk. Tcl/Tk 8.6+ / 9.x.
#
# Error codes: {TKUTILS TKUCONTEXTMENU <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkucontextmenu {
    namespace export create attach detach show \
        addItem addSeparator addSubmenu \
        addCheckItem addRadioItem \
        enable disable setCallback \
        setUpdateHandler destroyMenu \
        createStandardEdit createFromSpec
    variable instances
    variable submenuCounter 0
}

# ------------------------------------------------------------
# create - Kontextmenue erstellen
# ------------------------------------------------------------
# Optionen:
#   -tearoff    0|1 (Default: 0)
#   -items      Liste von Menu-Items (optional)
#   -dynamic    0|1 - Vor jedem Anzeigen aktualisieren (Default: 0)
#
# Items-Format:
#   {label command ?accelerator? ?state?}
#   oder "-" fuer Separator
#
proc ::tkutils::tkucontextmenu::create {path args} {
    variable instances
    
    # Defaults
    array set opts {
        -tearoff  0
        -items    {}
        -dynamic  0
    }
    array set opts $args
    
    # Menu erstellen
    menu $path -tearoff $opts(-tearoff)
    
    # State speichern
    set instances($path) [dict create \
        tearoff       $opts(-tearoff) \
        dynamic       $opts(-dynamic) \
        items         {} \
        widgets       {} \
        updateHandler "" \
    ]

    # Auto-clean instance state when the menu is destroyed by any means.
    bind $path <Destroy> [list ::tkutils::tkucontextmenu::_cleanup $path %W]

    # Initiale Items hinzufuegen
    foreach item $opts(-items) {
        if {$item eq "-"} {
            addSeparator $path
        } elseif {[llength $item] >= 2} {
            set label [lindex $item 0]
            set cmd [lindex $item 1]
            set accel [lindex $item 2]
            set state [lindex $item 3]
            if {$state eq ""} {set state normal}
            addItem $path $label -command $cmd -accelerator $accel -state $state
        }
    }
    
    return $path
}

# ------------------------------------------------------------
# addItem - Menue-Eintrag hinzufuegen
# ------------------------------------------------------------
# Optionen:
#   -command     Callback (Pflicht)
#   -accelerator Shortcut-Anzeige (optional)
#   -state       normal|disabled (Default: normal)
#   -icon        Icon-Image (optional)
#
proc ::tkutils::tkucontextmenu::addItem {menu label args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        return -code error -errorcode {TKUTILS TKUCONTEXTMENU NOMENU} "unknown context menu '$menu'"
    }
    
    # Defaults
    array set opts {
        -command     {}
        -accelerator ""
        -state       normal
        -icon        ""
    }
    array set opts $args
    
    # Menu-Eintrag hinzufuegen
    set cmdArgs [list -label $label -command $opts(-command) -state $opts(-state)]
    
    if {$opts(-accelerator) ne ""} {
        lappend cmdArgs -accelerator $opts(-accelerator)
    }
    if {$opts(-icon) ne ""} {
        lappend cmdArgs -image $opts(-icon) -compound left
    }
    
    $menu add command {*}$cmdArgs
    
    # Item registrieren
    set idx [$menu index end]
    set items [dict get $instances($menu) items]
    dict set items $label [dict create \
        index       $idx \
        command     $opts(-command) \
        accelerator $opts(-accelerator) \
        state       $opts(-state) \
        type        command \
    ]
    dict set instances($menu) items $items
    
    return $idx
}

# ------------------------------------------------------------
# addSeparator - Separator hinzufuegen
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::addSeparator {menu} {
    variable instances
    
    if {![info exists instances($menu)]} {
        return -code error -errorcode {TKUTILS TKUCONTEXTMENU NOMENU} "unknown context menu '$menu'"
    }
    
    $menu add separator
    return [$menu index end]
}

# ------------------------------------------------------------
# addSubmenu - Untermenue hinzufuegen
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::addSubmenu {menu label submenu} {
    variable instances
    
    if {![info exists instances($menu)]} {
        return -code error -errorcode {TKUTILS TKUCONTEXTMENU NOMENU} "unknown context menu '$menu'"
    }
    
    $menu add cascade -label $label -menu $submenu
    
    # Item registrieren
    set idx [$menu index end]
    set items [dict get $instances($menu) items]
    dict set items $label [dict create \
        index   $idx \
        submenu $submenu \
        type    cascade \
    ]
    dict set instances($menu) items $items
    
    return $idx
}

# ------------------------------------------------------------
# addCheckItem - Checkbutton-Eintrag hinzufuegen
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::addCheckItem {menu label args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        return -code error -errorcode {TKUTILS TKUCONTEXTMENU NOMENU} "unknown context menu '$menu'"
    }
    
    # Defaults
    array set opts {
        -variable    ""
        -command     {}
        -accelerator ""
        -onvalue     1
        -offvalue    0
    }
    array set opts $args
    
    # Variable automatisch erstellen wenn nicht angegeben
    if {$opts(-variable) eq ""} {
        set safeName [string map {. _ " " _} $label]
        set opts(-variable) "::tkutils::tkucontextmenu::check_${menu}_${safeName}"
        set $opts(-variable) $opts(-offvalue)
    }
    
    set cmdArgs [list -label $label \
        -variable $opts(-variable) \
        -onvalue $opts(-onvalue) \
        -offvalue $opts(-offvalue)]
    
    if {$opts(-command) ne {}} {
        lappend cmdArgs -command $opts(-command)
    }
    if {$opts(-accelerator) ne ""} {
        lappend cmdArgs -accelerator $opts(-accelerator)
    }
    
    $menu add checkbutton {*}$cmdArgs
    
    # Item registrieren
    set idx [$menu index end]
    set items [dict get $instances($menu) items]
    dict set items $label [dict create \
        index    $idx \
        variable $opts(-variable) \
        command  $opts(-command) \
        type     checkbutton \
    ]
    dict set instances($menu) items $items
    
    return $idx
}

# ------------------------------------------------------------
# addRadioItem - Radiobutton-Eintrag hinzufuegen
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::addRadioItem {menu label args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        return -code error -errorcode {TKUTILS TKUCONTEXTMENU NOMENU} "unknown context menu '$menu'"
    }
    
    # Defaults
    array set opts {
        -variable    ""
        -value       ""
        -command     {}
        -accelerator ""
    }
    array set opts $args
    
    if {$opts(-value) eq ""} {
        set opts(-value) $label
    }
    
    set cmdArgs [list -label $label -variable $opts(-variable) -value $opts(-value)]
    
    if {$opts(-command) ne {}} {
        lappend cmdArgs -command $opts(-command)
    }
    if {$opts(-accelerator) ne ""} {
        lappend cmdArgs -accelerator $opts(-accelerator)
    }
    
    $menu add radiobutton {*}$cmdArgs
    
    # Item registrieren
    set idx [$menu index end]
    set items [dict get $instances($menu) items]
    dict set items $label [dict create \
        index    $idx \
        variable $opts(-variable) \
        value    $opts(-value) \
        command  $opts(-command) \
        type     radiobutton \
    ]
    dict set instances($menu) items $items
    
    return $idx
}

# ------------------------------------------------------------
# attach - Menu an Widget binden
# ------------------------------------------------------------
# Optionen:
#   -button  2|3 (Default: plattformabhaengig)
#
proc ::tkutils::tkucontextmenu::attach {menu widget args} {
    variable instances
    
    if {![info exists instances($menu)]} {
        return -code error -errorcode {TKUTILS TKUCONTEXTMENU NOMENU} "unknown context menu '$menu'"
    }
    
    # Defaults
    array set opts {
        -button ""
    }
    array set opts $args
    
    # Plattformabhaengige Button-Bestimmung
    if {$opts(-button) eq ""} {
        if {[tk windowingsystem] eq "aqua"} {
            set opts(-button) 2
        } else {
            set opts(-button) 3
        }
    }
    
    # Bindings erstellen
    if {[tk windowingsystem] eq "aqua"} {
        bind $widget <Button-$opts(-button)> [list ::tkutils::tkucontextmenu::show $menu %X %Y]
        bind $widget <Control-Button-1> [list ::tkutils::tkucontextmenu::show $menu %X %Y]
    } else {
        bind $widget <Button-$opts(-button)> [list ::tkutils::tkucontextmenu::show $menu %X %Y]
    }
    
    # Widget registrieren
    set widgets [dict get $instances($menu) widgets]
    lappend widgets $widget
    dict set instances($menu) widgets $widgets
}

# ------------------------------------------------------------
# detach - Menu von Widget loesen
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::detach {menu widget} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    # Bindings entfernen
    if {[tk windowingsystem] eq "aqua"} {
        bind $widget <Button-2> {}
        bind $widget <Control-Button-1> {}
    } else {
        bind $widget <Button-3> {}
    }
    
    # Widget deregistrieren
    set widgets [dict get $instances($menu) widgets]
    set idx [lsearch -exact $widgets $widget]
    if {$idx >= 0} {
        set widgets [lreplace $widgets $idx $idx]
        dict set instances($menu) widgets $widgets
    }
}

# ------------------------------------------------------------
# show - Menu anzeigen
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::show {menu x y} {
    variable instances
    
    if {![info exists instances($menu)]} return
    if {![winfo exists $menu]} return
    
    # Update-Handler aufrufen wenn dynamisch
    if {[dict get $instances($menu) dynamic]} {
        set handler [dict get $instances($menu) updateHandler]
        if {$handler ne ""} {
            uplevel #0 $handler
        }
    }
    
    tk_popup $menu $x $y
}

# ------------------------------------------------------------
# enable / disable - Menue-Eintrag aktivieren/deaktivieren
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::enable {menu label} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    set items [dict get $instances($menu) items]
    if {![dict exists $items $label]} return
    
    set idx [dict get $items $label index]
    $menu entryconfigure $idx -state normal
}

proc ::tkutils::tkucontextmenu::disable {menu label} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    set items [dict get $instances($menu) items]
    if {![dict exists $items $label]} return
    
    set idx [dict get $items $label index]
    $menu entryconfigure $idx -state disabled
}

# ------------------------------------------------------------
# setCallback - Callback nachtraeglich aendern
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::setCallback {menu label command} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    set items [dict get $instances($menu) items]
    if {![dict exists $items $label]} return
    
    set idx [dict get $items $label index]
    $menu entryconfigure $idx -command $command
}

# ------------------------------------------------------------
# setUpdateHandler - Handler fuer dynamische Menus
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::setUpdateHandler {menu handler} {
    variable instances
    
    if {![info exists instances($menu)]} return
    
    dict set instances($menu) updateHandler $handler
}

# ------------------------------------------------------------
# destroy - Menu entfernen
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::destroyMenu {menu} {
    variable instances
    if {![info exists instances($menu)]} return
    # The <Destroy> binding runs _cleanup (detach + state removal).
    ::destroy $menu
}

# Internal: release bindings and drop instance state. Fired on <Destroy>.
proc ::tkutils::tkucontextmenu::_cleanup {menu w} {
    variable instances
    if {$w ne $menu} return
    if {![info exists instances($menu)]} return
    foreach widget [dict get $instances($menu) widgets] {
        if {[winfo exists $widget]} { detach $menu $widget }
    }
    unset instances($menu)
}

# ============================================================
# Convenience-Procs fuer haeufige Anwendungsfaelle
# ============================================================

# ------------------------------------------------------------
# createStandardEdit - Standard Edit-Kontextmenue
# ------------------------------------------------------------
proc ::tkutils::tkucontextmenu::createStandardEdit {path args} {
    array set opts {
        -cutcmd     {}
        -copycmd    {}
        -pastecmd   {}
        -selectall  {}
        -undo       {}
        -redo       {}
    }
    array set opts $args
    
    set menu [create $path]
    
    if {$opts(-undo) ne {}} {
        addItem $menu "Undo" -command $opts(-undo) -accelerator "Ctrl+Z"
    }
    if {$opts(-redo) ne {}} {
        addItem $menu "Redo" -command $opts(-redo) -accelerator "Ctrl+Y"
    }
    if {$opts(-undo) ne {} || $opts(-redo) ne {}} {
        addSeparator $menu
    }
    
    if {$opts(-cutcmd) ne {}} {
        addItem $menu "Cut" -command $opts(-cutcmd) -accelerator "Ctrl+X"
    }
    if {$opts(-copycmd) ne {}} {
        addItem $menu "Copy" -command $opts(-copycmd) -accelerator "Ctrl+C"
    }
    if {$opts(-pastecmd) ne {}} {
        addItem $menu "Paste" -command $opts(-pastecmd) -accelerator "Ctrl+V"
    }
    if {$opts(-selectall) ne {}} {
        addSeparator $menu
        addItem $menu "Select All" -command $opts(-selectall) -accelerator "Ctrl+A"
    }
    
    return $menu
}

# ------------------------------------------------------------
# createFromSpec - Menu aus Spezifikation erstellen
# ------------------------------------------------------------
# Spec format (each list item):
#   {label command ?-accelerator acc? ?-state state? ?-icon icon?}
#   -                                            separator
#   {check label ?-variable var? ?-command cmd?}
#   {radio label -variable var -value val ?-command cmd?}
#   {submenu label {nested-spec}}                cascade
#
# Note: submenus use the explicit `submenu` keyword (like check/radio). The
# original uitoolkit form {label {nested-spec}} was ambiguous -- a multi-word
# command script was indistinguishable from a one-item submenu -- and is gone.
proc ::tkutils::tkucontextmenu::createFromSpec {path spec} {
    set menu [create $path]
    _buildFromSpec $menu $spec
    return $menu
}

proc ::tkutils::tkucontextmenu::_buildFromSpec {menu spec} {
    variable submenuCounter
    foreach item $spec {
        if {$item eq "-"} {
            addSeparator $menu
            continue
        }
        switch -- [lindex $item 0] {
            check {
                addCheckItem $menu [lindex $item 1] {*}[lrange $item 2 end]
            }
            radio {
                addRadioItem $menu [lindex $item 1] {*}[lrange $item 2 end]
            }
            submenu {
                # {submenu label {nested-spec}} -- explicit, unambiguous.
                # Child path uses a counter so upper-case/spaced labels are safe.
                set label [lindex $item 1]
                set nested [lindex $item 2]
                set sub [create $menu.sm[incr submenuCounter]]
                _buildFromSpec $sub $nested
                addSubmenu $menu $label $sub
            }
            default {
                # {label command ?-accelerator a? ?-state s? ?-icon i?}
                set label [lindex $item 0]
                set rest [lrange $item 1 end]
                if {[llength $rest] >= 1} {
                    addItem $menu $label -command [lindex $rest 0] \
                        {*}[lrange $rest 1 end]
                }
            }
        }
    }
}

package provide tkutils::tkucontextmenu 0.1
