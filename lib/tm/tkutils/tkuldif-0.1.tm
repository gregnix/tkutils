# tkutils::tkuldif -- LDIF entry viewer/editor
# Description: LDIF entry viewer/editor
# Category: Tk · widgets
#
# Shows LDIF entries in a tree: each entry is a node labelled with its dn, with
# one child row per attribute value (dn included, so it can be edited). With
# -editable 1 (default) an edit bar allows changing values and adding/removing
# attributes and entries. Built on tclutils::tuldif (requires tclutils 0.35.0+
# for the edit helpers). Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuldif 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuldif {
    namespace export widget loadText loadFile setEntries entries count treeWidget \
        addEntry removeEntry addAttr setAttr removeAttr toText save
    variable state
}

proc ::tkutils::tkuldif::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkuldif::widget {path args} {
    variable state
    array set o {-editable 1}
    array set o $args
    ttk::frame $path
    set state($path,entries) {}
    set state($path,editable) $o(-editable)
    set state($path,curEntry) -1
    set state($path,curPair) -1
    set state($path,eattr) ""
    set state($path,eval) ""
    bind $path <Destroy> [list ::tkutils::tkuldif::_cleanup $path %W]

    set tv $path.tv
    ttk::treeview $tv -columns {value} -yscrollcommand [list $path.ys set]
    $tv heading #0 -text "Entry / Attribute"
    $tv heading value -text "Value"
    $tv column #0 -width 280 -anchor w
    $tv column value -width 320 -anchor w
    $tv tag configure entry -foreground "#1a4f8b"
    ttk::scrollbar $path.ys -orient vertical -command [list $tv yview]
    grid $tv $path.ys -sticky nsew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    if {$state($path,editable)} {
        set eb $path.eb
        ttk::frame $eb
        ttk::label $eb.al -text "Attr:"
        ttk::entry $eb.ae -width 14 -textvariable ::tkutils::tkuldif::state($path,eattr)
        ttk::label $eb.vl -text "Value:"
        ttk::entry $eb.ve -width 24 -textvariable ::tkutils::tkuldif::state($path,eval)
        ttk::button $eb.set -text "Set" -command [list ::tkutils::tkuldif::_uiSet $path]
        ttk::button $eb.add -text "Add" -command [list ::tkutils::tkuldif::_uiAdd $path]
        ttk::button $eb.del -text "Del" -command [list ::tkutils::tkuldif::_uiDel $path]
        ttk::separator $eb.sep -orient vertical
        ttk::button $eb.ae2 -text "Add Entry" -command [list ::tkutils::tkuldif::_uiAddEntry $path]
        ttk::button $eb.de2 -text "Del Entry" -command [list ::tkutils::tkuldif::_uiDelEntry $path]
        pack $eb.al $eb.ae $eb.vl $eb.ve $eb.set $eb.add $eb.del \
            $eb.sep $eb.ae2 $eb.de2 -side left -padx 2 -pady 3
        pack $eb.sep -fill y -padx 6
        grid $eb - -sticky ew -row 1 -column 0 -columnspan 2
        bind $tv <<TreeviewSelect>> [list ::tkutils::tkuldif::_onSelect $path]
    }
    return $path
}

proc ::tkutils::tkuldif::treeWidget {path} { return $path.tv }

proc ::tkutils::tkuldif::_populate {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    foreach k [array names state $path,entryOf,*] { unset state($k) }
    foreach k [array names state $path,pairOf,*] { unset state($k) }
    set ei 0
    foreach entry $state($path,entries) {
        set node [$tv insert {} end -text [::tclutils::tuldif::dn $entry] -open 1 -tags entry]
        set state($path,entryOf,$node) $ei
        set pi 0
        foreach pair $entry {
            lassign $pair attr val
            set item [$tv insert $node end -text $attr -values [list $val]]
            set state($path,pairOf,$item) [list $ei $pi]
            incr pi
        }
        incr ei
    }
}

# Load LDIF text. Returns the number of entries.
proc ::tkutils::tkuldif::loadText {path ldif} {
    variable state
    set state($path,entries) [::tclutils::tuldif::parse $ldif]
    _populate $path
    return [llength $state($path,entries)]
}

proc ::tkutils::tkuldif::loadFile {path file} {
    set ch [open $file r]
    set txt [read $ch]
    close $ch
    return [loadText $path $txt]
}

# Display already-parsed entries.
proc ::tkutils::tkuldif::setEntries {path entries} {
    variable state
    set state($path,entries) $entries
    _populate $path
    return [llength $entries]
}

proc ::tkutils::tkuldif::entries {path} {
    variable state
    return $state($path,entries)
}
proc ::tkutils::tkuldif::count {path} {
    variable state
    return [llength $state($path,entries)]
}

# --- editing ------------------------------------------------------------------

# Append a new entry with the given dn. Returns its index.
proc ::tkutils::tkuldif::addEntry {path {dn "cn=New"}} {
    variable state
    lappend state($path,entries) [list [list dn $dn]]
    _populate $path
    return [expr {[llength $state($path,entries)] - 1}]
}
proc ::tkutils::tkuldif::removeEntry {path index} {
    variable state
    set state($path,entries) [lreplace $state($path,entries) $index $index]
    _populate $path
}
proc ::tkutils::tkuldif::addAttr {path entryIndex attr value} {
    variable state
    set e [lindex $state($path,entries) $entryIndex]
    set e [::tclutils::tuldif::addAttr $e $attr $value]
    lset state($path,entries) $entryIndex $e
    _populate $path
}
proc ::tkutils::tkuldif::setAttr {path entryIndex pairIndex attr value} {
    variable state
    set e [lindex $state($path,entries) $entryIndex]
    set e [::tclutils::tuldif::setAttr $e $pairIndex $attr $value]
    lset state($path,entries) $entryIndex $e
    _populate $path
}
proc ::tkutils::tkuldif::removeAttr {path entryIndex pairIndex} {
    variable state
    set e [lindex $state($path,entries) $entryIndex]
    set e [::tclutils::tuldif::removeAttr $e $pairIndex]
    lset state($path,entries) $entryIndex $e
    _populate $path
}
# Current entries as LDIF text.
proc ::tkutils::tkuldif::toText {path} {
    variable state
    return [::tclutils::tuldif::toLdif $state($path,entries)]
}
proc ::tkutils::tkuldif::save {path file} {
    set ch [open $file w]
    fconfigure $ch -translation lf
    puts $ch [toText $path]
    close $ch
    return $file
}

# --- selection + edit-bar handlers -------------------------------------------

proc ::tkutils::tkuldif::_onSelect {path} {
    variable state
    set tv $path.tv
    set item [lindex [$tv selection] 0]
    if {$item eq ""} return
    if {[info exists state($path,pairOf,$item)]} {
        lassign $state($path,pairOf,$item) ei pi
        set state($path,curEntry) $ei
        set state($path,curPair) $pi
        set pair [lindex [lindex $state($path,entries) $ei] $pi]
        set state($path,eattr) [lindex $pair 0]
        set state($path,eval)  [lindex $pair 1]
    } elseif {[info exists state($path,entryOf,$item)]} {
        set state($path,curEntry) $state($path,entryOf,$item)
        set state($path,curPair) -1
    }
}
proc ::tkutils::tkuldif::_uiSet {path} {
    variable state
    if {$state($path,curEntry) >= 0 && $state($path,curPair) >= 0} {
        setAttr $path $state($path,curEntry) $state($path,curPair) \
            $state($path,eattr) $state($path,eval)
    }
}
proc ::tkutils::tkuldif::_uiAdd {path} {
    variable state
    if {$state($path,curEntry) >= 0 && $state($path,eattr) ne ""} {
        addAttr $path $state($path,curEntry) $state($path,eattr) $state($path,eval)
    }
}
proc ::tkutils::tkuldif::_uiDel {path} {
    variable state
    if {$state($path,curEntry) >= 0 && $state($path,curPair) >= 0} {
        removeAttr $path $state($path,curEntry) $state($path,curPair)
        set state($path,curPair) -1
    }
}
proc ::tkutils::tkuldif::_uiAddEntry {path} {
    variable state
    set dn [expr {$state($path,eval) ne "" ? $state($path,eval) : "cn=New"}]
    addEntry $path $dn
}
proc ::tkutils::tkuldif::_uiDelEntry {path} {
    variable state
    if {$state($path,curEntry) >= 0} {
        removeEntry $path $state($path,curEntry)
        set state($path,curEntry) -1
        set state($path,curPair) -1
    }
}

package provide tkutils::tkuldif 0.1
