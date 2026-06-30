# tkutils::tkubind -- platform key/context bindings (from uitoolkit uibindings)
# Description: platform key/context bindings (from uitoolkit uibindings)
# Category: Tk · widgets
#
# A thin layer over `bind` that abstracts the platform modifier (Control on
# X11/Win, Command on macOS) and stays out of the way while the user is typing:
#   - "Mod-s" translates to <Control-s> / <Command-s>
#   - accelerator strings for menus ("Ctrl+S" / "@S")
#   - key/unbind, named binding groups, isEditing guard, context/doubleClick
# The action-registry coupling of the original is intentionally omitted here;
# it returns if/when a tkuaction module is adopted.  Pure Tk. 8.6+ / 9.x.
#
# Error codes: {TKUTILS TKUBIND <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkubind {
    namespace export key unbind accelerator context doubleClick \
        group isEditing platform getInfo clear

    variable version 0.1
    
    # Plattform-Info
    variable platformInfo
    array set platformInfo {
        isMac 0
        modKey "Control"
        modSymbol "Ctrl"
    }
    
    # Registrierte Bindings
    variable bindings
    array set bindings {}
    
    # Gruppen
    variable groups
    array set groups {}
    
    # Widget-Klassen die eigene Key-Bindings haben
    variable editClasses {Entry Text TEntry TCombobox Spinbox TSpinbox}
    variable tableClasses {Tablelist Treeview}
    variable skipClasses {}
}

# ============================================================
# Initialisierung
# ============================================================

proc ::tkutils::tkubind::_init {} {
    variable platformInfo
    
    # Plattform erkennen (mit Fallback)
    if {[catch {tk windowingsystem} ws]} {
        # Tk nicht verfügbar - Default-Werte behalten
        return
    }
    
    if {$ws eq "aqua"} {
        set platformInfo(isMac) 1
        set platformInfo(modKey) "Command"
        set platformInfo(modSymbol) "⌘"
    } else {
        set platformInfo(isMac) 0
        set platformInfo(modKey) "Control"
        set platformInfo(modSymbol) "Ctrl"
    }
}

# ============================================================
# platform - Plattform-Info abrufen
# ============================================================

proc ::tkutils::tkubind::platform {{key ""}} {
    variable platformInfo
    
    if {$key eq ""} {
        return [array get platformInfo]
    }
    
    if {[info exists platformInfo($key)]} {
        return $platformInfo($key)
    }
    
    # Fallback-Werte
    switch -- $key {
        isMac     { return 0 }
        modKey    { return "Control" }
        modSymbol { return "Ctrl" }
        default   { return "" }
    }
}

# ============================================================
# _translateKey - Key-Spec in Tk-Binding umwandeln
# ============================================================
# "Mod-s" → "<Control-s>" oder "<Command-s>"
# "Mod-Shift-s" → "<Control-Shift-s>"
# "F1" → "<F1>"

proc ::tkutils::tkubind::_translateKey {spec} {
    variable platformInfo
    
    # Mod durch plattformspezifischen Modifier ersetzen
    set spec [string map [list "Mod" $platformInfo(modKey)] $spec]
    
    # Bereits in <> Format?
    if {[string match "<*>" $spec]} {
        return $spec
    }
    
    return "<$spec>"
}

# ============================================================
# accelerator - Lesbarer String für Menüs
# ============================================================
# "Mod-s" → "Ctrl+S" (Win/Linux) oder "⌘S" (macOS)

proc ::tkutils::tkubind::accelerator {spec} {
    variable platformInfo
    
    if {$platformInfo(isMac)} {
        # macOS: Symbole
        set map {
            "Mod" "⌘"
            "Shift" "⇧"
            "Alt" "⌥"
            "Option" "⌥"
            "Control" "⌃"
            "Ctrl" "⌃"
        }
        set sep ""
    } else {
        # Windows/Linux: Text
        set map {
            "Mod" "Ctrl"
            "Shift" "Shift"
            "Alt" "Alt"
            "Option" "Alt"
            "Control" "Ctrl"
            "Ctrl" "Ctrl"
        }
        set sep "+"
    }
    
    set parts [split $spec "-"]
    set result {}
    
    foreach part $parts {
        if {[dict exists $map $part]} {
            lappend result [dict get $map $part]
        } else {
            # Letzter Teil (der eigentliche Key) - uppercase
            lappend result [string toupper $part]
        }
    }
    
    return [join $result $sep]
}

# ============================================================
# _shouldHandle - Prüfen ob Binding ausgelöst werden soll
# ============================================================

proc ::tkutils::tkubind::_shouldHandle {w keySpec skipClasses} {
    variable editClasses
    variable tableClasses
    
    # Fokus-Widget ermitteln
    set focused [focus]
    if {$focused eq ""} {
        return 1
    }
    
    # Widget-Klasse
    set class [winfo class $focused]
    
    # Explizit übersprungene Klassen
    if {$class in $skipClasses} {
        return 0
    }
    
    # Hat der Key einen Modifier (Ctrl/Cmd)?
    set hasModifier [expr {[string match "*Control*" $keySpec] || 
                           [string match "*Command*" $keySpec] ||
                           [string match "*Alt*" $keySpec]}]
    
    # Edit-Klassen: Nur Modifier-Keys durchlassen
    if {$class in $editClasses} {
        # Ctrl+S etc. durchlassen, aber nicht Delete, F2, etc.
        if {!$hasModifier} {
            return 0
        }
        # Ctrl+C/V/X in Entry/Text → NICHT durchlassen (native Funktion)
        if {[string match "*-c>" $keySpec] || 
            [string match "*-v>" $keySpec] || 
            [string match "*-x>" $keySpec] ||
            [string match "*-a>" $keySpec]} {
            return 0
        }
    }
    
    # Tablelist: Ähnlich, aber mehr Keys reserviert
    if {$class in $tableClasses || [_isInsideTablelist $focused]} {
        if {!$hasModifier} {
            # Einfache Keys (Delete, F2, Arrows) → tablelist entscheidet
            return 0
        }
        # Ctrl+C/V/X → tablelist hat eigene Implementierung
        if {[string match "*-c>" $keySpec] || 
            [string match "*-v>" $keySpec] || 
            [string match "*-x>" $keySpec]} {
            return 0
        }
    }
    
    return 1
}

# ============================================================
# _isInsideTablelist - Prüfen ob Widget in Tablelist ist
# ============================================================

proc ::tkutils::tkubind::_isInsideTablelist {w} {
    while {$w ne "" && $w ne "."} {
        if {[winfo class $w] eq "Tablelist"} {
            return 1
        }
        set w [winfo parent $w]
    }
    return 0
}

# ============================================================
# isEditing - Prüfen ob Fokus auf Edit-Widget
# ============================================================

proc ::tkutils::tkubind::isEditing {} {
    variable editClasses
    variable tableClasses
    
    set focused [focus]
    if {$focused eq ""} {
        return 0
    }
    
    set class [winfo class $focused]
    
    if {$class in $editClasses} {
        return 1
    }
    
    if {$class in $tableClasses || [_isInsideTablelist $focused]} {
        return 1
    }
    
    return 0
}

# ============================================================
# key - Tastatur-Binding registrieren
# ============================================================
# tkubind::key "Mod-s" {saveFile}
# tkubind::key "Mod-s" {saveFile} -toplevel .editor
# tkubind::key "Delete" {deleteItem} -skipClasses {Tablelist Entry}

proc ::tkutils::tkubind::key {spec script args} {
    variable bindings
    
    # Optionen
    array set opts {
        -toplevel "."
        -skipClasses {}
        -id ""
    }
    array set opts $args
    
    # Key übersetzen
    set tkKey [_translateKey $spec]
    
    # ID generieren falls nicht angegeben
    if {$opts(-id) eq ""} {
        set opts(-id) "key_[string map {< "" > "" - _} $tkKey]"
    }
    
    # skipClasses für Closure merken
    set skipClasses $opts(-skipClasses)
    
    # Binding erstellen
    bind $opts(-toplevel) $tkKey [list apply {{script skipClasses tkKey W} {
        if {[::tkutils::tkubind::_shouldHandle $W $tkKey $skipClasses]} {
            uplevel #0 $script
        }
    }} $script $skipClasses $tkKey %W]
    
    # Registrieren
    set bindings($opts(-id)) [dict create \
        spec $spec \
        tkKey $tkKey \
        script $script \
        toplevel $opts(-toplevel) \
        skipClasses $opts(-skipClasses) \
    ]
    
    return $opts(-id)
}

# ============================================================
# unbind - Binding entfernen
# ============================================================

proc ::tkutils::tkubind::unbind {id} {
    variable bindings
    
    if {![info exists bindings($id)]} {
        return 0
    }
    
    set info $bindings($id)
    set toplevel [dict get $info toplevel]
    set tkKey [dict get $info tkKey]
    
    bind $toplevel $tkKey {}
    unset bindings($id)
    
    return 1
}

# ============================================================
# context - Kontextmenü-Binding (plattformübergreifend)
# ============================================================
# tkubind::context $widget {showMenu %X %Y}

proc ::tkutils::tkubind::context {widget script} {
    variable platformInfo
    
    if {$platformInfo(isMac)} {
        # macOS: Button-2 oder Control-Button-1
        bind $widget <Button-2> $script
        bind $widget <Control-Button-1> $script
    } else {
        # Windows/Linux: Button-3
        bind $widget <Button-3> $script
    }
}

# ============================================================
# doubleClick - Doppelklick-Binding
# ============================================================
# tkubind::doubleClick $widget {onOpen %W}

proc ::tkutils::tkubind::doubleClick {widget script} {
    bind $widget <Double-Button-1> $script
}

# ============================================================
# group - Binding-Gruppen verwalten
# ============================================================

proc ::tkutils::tkubind::group {cmd args} {
    variable groups
    variable bindings
    
    switch $cmd {
        define {
            # tkubind::group define editorKeys {{Mod-b bold} {Mod-i italic}}
            lassign $args name keyList
            
            set groups($name) [dict create \
                keys $keyList \
                enabled 0 \
                bindingIds {} \
            ]
            return $name
        }
        
        enable {
            lassign $args name
            set opts(-toplevel) "."
            array set opts [lrange $args 1 end]
            
            if {![info exists groups($name)]} {
                return -code error -errorcode {TKUTILS TKUBIND GROUP} "undefined group '$name'"
            }
            
            if {[dict get $groups($name) enabled]} {
                return ;# Bereits aktiv
            }
            
            set ids {}
            foreach keyDef [dict get $groups($name) keys] {
                lassign $keyDef spec script
                set id [key $spec $script -toplevel $opts(-toplevel) -id "group_${name}_[llength $ids]"]
                lappend ids $id
            }
            
            dict set groups($name) bindingIds $ids
            dict set groups($name) enabled 1
        }
        
        disable {
            lassign $args name
            
            if {![info exists groups($name)]} {
                return -code error -errorcode {TKUTILS TKUBIND GROUP} "undefined group '$name'"
            }
            
            if {![dict get $groups($name) enabled]} {
                return ;# Bereits deaktiviert
            }
            
            foreach id [dict get $groups($name) bindingIds] {
                unbind $id
            }
            
            dict set groups($name) bindingIds {}
            dict set groups($name) enabled 0
        }
        
        toggle {
            lassign $args name
            if {[dict get $groups($name) enabled]} {
                group disable $name
            } else {
                group enable $name {*}[lrange $args 1 end]
            }
        }
        
        enabled {
            lassign $args name
            if {![info exists groups($name)]} {
                return 0
            }
            return [dict get $groups($name) enabled]
        }
        
        list {
            return [array names groups]
        }
        
        default {
            return -code error -errorcode {TKUTILS TKUBIND CMD} "unknown group command '$cmd': use define|enable|disable|toggle|enabled|list"
        }
    }
}

# ============================================================
# getInfo - Binding-Info abrufen
# ============================================================

proc ::tkutils::tkubind::getInfo {args} {
    variable bindings
    variable groups
    
    if {[llength $args] == 0} {
        return [list \
            bindings [array names bindings] \
            groups [array names groups] \
        ]
    }
    
    set what [lindex $args 0]
    
    switch $what {
        bindings {
            return [array get bindings]
        }
        groups {
            return [array get groups]
        }
        binding {
            set id [lindex $args 1]
            if {[::info exists bindings($id)]} {
                return $bindings($id)
            }
            return {}
        }
        default {
            return {}
        }
    }
}

# ============================================================
# clear - Alle Bindings entfernen
# ============================================================

proc ::tkutils::tkubind::clear {} {
    variable bindings
    variable groups
    
    # Alle Bindings entfernen
    foreach id [array names bindings] {
        unbind $id
    }
    
    # Alle Gruppen deaktivieren
    foreach name [array names groups] {
        if {[dict get $groups($name) enabled]} {
            group disable $name
        }
    }
    
    array unset groups
}

# ============================================================
# Initialisierung beim Laden
# ============================================================

::tkutils::tkubind::_init

# ============================================================
# Package bereitstellen
# ============================================================

package provide tkutils::tkubind $::tkutils::tkubind::version
