# tkuload 0.1 -- instantiate a tkudesigner ".tkd" layout as a live Tk widget
# Description: instantiate a tkudesigner `.tkd` layout as a live Tk widget tree (no code export)
# Category: Tk · widgets
# tree inside a host application (e.g. lieferschein), without code export.
#
# It does NOT reimplement rendering: it evaluates tkudesigner.tcl's body
# (the procs + widget catalogue, WITHOUT launching the editor) and drives the
# very same deserialize / renderChildren used by the live preview. One engine,
# no drift.
#
# Usage:
#   package require tkuload
#   set ui [::tkuload::buildFromFile $someFrame path/to/design.tkd]
#   # $ui is a dict: root <parent> byId {id w ...} byType {type {w ...} ...}
#   set firstEntry [lindex [dict get $ui byType entry] 0]
#
# Notes:
#   * A menubar in the design attaches to [winfo toplevel $parent].
#   * Build each design into its own (empty) parent; widget names derive from
#     node ids, so loading twice into the same parent collides.
#   * tkutils widgets need tclutils/tkutils on the module path (as for the
#     editor); missing packages fall back to a small placeholder, never crash.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkuload {
    variable engineLoaded 0
    variable designerPath ""
    variable hostSeq 0
    # our own directory, captured at source time (info script is unreliable
    # later -- it would reflect whichever script is calling us)
    variable selfDir [file dirname [file normalize [info script]]]
    namespace export build buildFromFile
}

# Load the shared render engine once: the package tkutils::tkurender (procs +
# catalogue only, no editor UI). No more reading/stripping tkudesigner.tcl.
proc ::tkuload::_ensureEngine {} {
    variable engineLoaded
    variable selfDir
    if {$engineLoaded} return
    _addTmPaths
    package require tkutils::tkurender
    set engineLoaded 1
}
# make tkutils/tclutils requirable from TCLUTILS_TM / TKUTILS_TM (if set).
# A real add failure is reported, not swallowed; a missing var is fine here --
# the engine's pkgAvail will warn loudly if a widget actually needs the package.
proc ::tkuload::_addTmPaths {} {
    foreach v {TCLUTILS_TM TKUTILS_TM} {
        if {[info exists ::env($v)]} {
            if {[catch {::tcl::tm::path add $::env($v)} err]} {
                puts stderr "tkuload: $v='$::env($v)' nicht als tm-Pfad nutzbar: $err"
            }
        }
    }
}

# Build the layout described by $spec (a .tkd dict) into $parent.
# Returns: dict {root <parent> byId {id w ...} byType {type {w ...} ...}}
proc ::tkuload::build {parent spec} {
    _ensureEngine
    if {![winfo exists $parent]} {
        return -code error -errorcode {TKULOAD PARENT} "no such parent widget: $parent"
    }
    # child widget names cannot hang directly off the root "." -- wrap it
    if {$parent eq "."} {
        variable hostSeq
        set parent .tkuloadHost[incr hostSeq]
        ttk::frame $parent
        pack $parent -fill both -expand 1
    }
    ::tkurender::deserialize $spec
    # embedded mode: the render engine must not attach editor-only bindings
    set ::tkurender::D(embedded) 1
    # load optional packages (tkutils / advanced widgets) -- the editor does this
    # while building its palette; without a palette we must trigger it ourselves
    foreach _id [dict keys $::tkurender::D(nodes)] {
        catch {::tkurender::pkgAvail [::tkurender::nodeType $_id]}
    }
    array unset ::tkurender::D wpath,*
    set pv [winfo toplevel $parent]
    ::tkurender::renderChildren $::tkurender::D(root) $parent $pv
    return [_collect $parent]
}

proc ::tkuload::buildFromFile {parent path} {
    set ch [open $path r]; set spec [read $ch]; close $ch
    return [build $parent $spec]
}

# snapshot id->widget and type->widgets from the freshly rendered tree
proc ::tkuload::_collect {parent} {
    set byId   [dict create]
    set byType [dict create]
    set byName [dict create]
    foreach id [dict keys $::tkurender::D(nodes)] {
        if {![info exists ::tkurender::D(wpath,$id)]} continue
        set w $::tkurender::D(wpath,$id)
        if {![winfo exists $w]} continue
        dict set byId $id $w
        dict lappend byType [::tkurender::nodeType $id] $w
        set nm [::tkurender::nodeName $id]
        if {$nm ne ""} { dict set byName $nm $w }
    }
    return [dict create root $parent byId $byId byType $byType byName $byName]
}

package provide tkutils::tkuload 0.1

# ---------------------------------------------------------------------------
# Value binding helpers -- wire a loaded design to host data by widget name.
# Dispatch on the actual value widget: tkutils megawidgets (tkunumentry,
# tkudateentry, ...) are TFrame wrappers, so we drill into the inner entry.
# ---------------------------------------------------------------------------
proc ::tkuload::_descendants {w} {
    set r {}
    foreach c [winfo children $w] { lappend r $c; lappend r {*}[_descendants $c] }
    return $r
}
# the widget that actually holds the value (drill into megawidget wrappers)
# the widget that actually holds the value (drill into megawidget wrappers).
# Uses class hints first, then duck-typing: any descendant that supports
# "index" is entry-like (ttk/tk entry, spinbox, ...).
proc ::tkuload::_valueWidget {w} {
    if {[winfo class $w] in {TEntry Entry TCombobox TSpinbox Spinbox Text
                             Listbox Tablelist TCheckbutton Checkbutton}} {
        return $w
    }
    foreach d [_descendants $w] {
        if {[winfo class $d] in {TEntry Entry TCombobox TSpinbox Spinbox}} {
            return $d
        }
    }
    # duck-type: first descendant that behaves like an entry (has "index")
    foreach d [_descendants $w] {
        if {![catch {$d index 0}]} { return $d }
    }
    return $w
}
proc ::tkuload::widgetByName {ui name} {
    set bn [dict get $ui byName]
    if {![dict exists $bn $name]} {
        return -code error -errorcode {TKULOAD NONAME} "no widget named '$name'"
    }
    return [dict get $bn $name]
}
# write into an entry-like widget, neutralising -state/-validate that would
# otherwise block a programmatic insert (readonly/disabled, key validation)
proc ::tkuload::_setEntryLike {w value} {
    set ov ""; catch {set ov [$w cget -validate]}
    set os ""; catch {set os [$w cget -state]}
    catch {$w configure -validate none}
    catch {$w configure -state normal}
    catch {$w delete 0 end}
    catch {$w insert 0 $value}
    if {$ov ne ""} { catch {$w configure -validate $ov} }
    if {$os ne ""} { catch {$w configure -state $os} }
}
proc ::tkuload::setValue {ui name value} {
    set bn [dict get $ui byName]
    if {![dict exists $bn $name]} { return 0 }
    set wn [dict get $bn $name]
    set w  [_valueWidget $wn]
    switch -- [winfo class $w] {
        TCombobox             { $w set $value; return 1 }
        Text                  { $w delete 1.0 end; $w insert 1.0 $value; return 1 }
        Listbox               { $w delete 0 end; foreach it $value { $w insert end $it }; return 1 }
        Tablelist             { $w delete 0 end; $w insertlist end $value; return 1 }
        TCheckbutton - Checkbutton {
            if {[string is true -strict $value] || $value eq "1"} {
                $w state selected
            } else { $w state !selected }
            return 1
        }
    }
    # entry-like (TEntry/Entry/TSpinbox/Spinbox or duck-typed) -> safe insert
    if {![catch {$w index 0}]} { _setEntryLike $w $value; return 1 }
    # last resort: the megawidget's own public setter
    foreach m {set setvalue} { if {![catch {$wn $m $value}]} { return 1 } }
    if {![catch {$wn configure -value $value}]} { return 1 }
    catch {$wn configure -text $value}
    return 1
}
proc ::tkuload::getValue {ui name} {
    set bn [dict get $ui byName]
    if {![dict exists $bn $name]} { return "" }
    set wn [dict get $bn $name]
    set w  [_valueWidget $wn]
    switch -- [winfo class $w] {
        TCombobox        { return [$w get] }
        Text             { return [string trimright [$w get 1.0 end] "\n"] }
        Tablelist        { return [$w get 0 end] }
        TCheckbutton - Checkbutton { return [expr {[$w instate selected] ? 1 : 0}] }
    }
    if {![catch {$w index 0}]} { return [$w get] }   ;# entry-like
    foreach m {get getvalue} { if {![catch {$wn $m} v]} { return $v } }
    if {![catch {$wn cget -value} v]} { return $v }
    return ""
}
# fill many fields from a {name value name value ...} dict (unknown names skipped)
proc ::tkuload::fill {ui data} {
    dict for {k v} $data { setValue $ui $k $v }
}
# read named fields back into a dict (default: every named widget)
proc ::tkuload::collect {ui {names ""}} {
    if {$names eq ""} { set names [dict keys [dict get $ui byName]] }
    set out [dict create]
    foreach n $names { dict set out $n [getValue $ui $n] }
    return $out
}
