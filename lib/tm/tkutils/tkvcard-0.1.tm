# tkutils::tkvcard -- vCard contact viewer
#
# Shows vCard contacts in a tree: each card is a node labelled with its FN, with
# one child row per property (Value + a Type hint from any TYPE parameter).
# Built on the tclutils tuvcard engine (requires tclutils 0.32.0+).
# Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuvcard 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkvcard {
    namespace export widget loadText loadFile setCards cards count treeWidget \
        addCard removeCard addProperty removeProperty setProperty toText save
    variable state
}

proc ::tkutils::tkvcard::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkvcard::widget {path args} {
    variable state
    array set o {-editable 1}
    array set o $args
    ttk::frame $path
    set state($path,cards) {}
    set state($path,editable) $o(-editable)
    set state($path,curCard) -1
    set state($path,curProp) -1
    set state($path,ename) ""
    set state($path,eval) ""
    set state($path,etype) ""
    bind $path <Destroy> [list ::tkutils::tkvcard::_cleanup $path %W]

    set tv $path.tv
    ttk::treeview $tv -columns {value type} -yscrollcommand [list $path.ys set]
    $tv heading #0 -text "Contact / Property"
    $tv heading value -text "Value"
    $tv heading type -text "Type"
    $tv column #0 -width 220 -anchor w
    $tv column value -width 280 -anchor w
    $tv column type -width 90 -anchor w
    $tv tag configure card -foreground "#1a4f8b"
    ttk::scrollbar $path.ys -orient vertical -command [list $tv yview]
    grid $tv $path.ys -sticky nsew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    if {$state($path,editable)} {
        set eb $path.eb
        ttk::frame $eb
        ttk::label $eb.nl -text "Name:"
        ttk::entry $eb.ne -width 12 -textvariable ::tkutils::tkvcard::state($path,ename)
        ttk::label $eb.vl -text "Value:"
        ttk::entry $eb.ve -width 20 -textvariable ::tkutils::tkvcard::state($path,eval)
        ttk::label $eb.tl -text "Type:"
        ttk::entry $eb.te -width 8 -textvariable ::tkutils::tkvcard::state($path,etype)
        ttk::button $eb.set -text "Set"  -command [list ::tkutils::tkvcard::_uiSetProp $path]
        ttk::button $eb.add -text "Add"  -command [list ::tkutils::tkvcard::_uiAddProp $path]
        ttk::button $eb.del -text "Del"  -command [list ::tkutils::tkvcard::_uiDelProp $path]
        ttk::separator $eb.sep -orient vertical
        ttk::button $eb.ac -text "Add Card" -command [list ::tkutils::tkvcard::_uiAddCard $path]
        ttk::button $eb.dc -text "Del Card" -command [list ::tkutils::tkvcard::_uiDelCard $path]
        pack $eb.nl $eb.ne $eb.vl $eb.ve $eb.tl $eb.te $eb.set $eb.add $eb.del \
            $eb.sep $eb.ac $eb.dc -side left -padx 2 -pady 3
        pack $eb.sep -fill y -padx 6
        grid $eb - -sticky ew -row 1 -column 0 -columnspan 2
        bind $tv <<TreeviewSelect>> [list ::tkutils::tkvcard::_onSelect $path]
    }
    return $path
}

proc ::tkutils::tkvcard::treeWidget {path} { return $path.tv }

proc ::tkutils::tkvcard::_typeHint {params} {
    set hints {}
    foreach {k v} $params {
        if {[string equal -nocase $k TYPE]} { lappend hints $v }
    }
    return [join $hints ", "]
}

proc ::tkutils::tkvcard::_populate {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    foreach k [array names state $path,cardOf,*] { unset state($k) }
    foreach k [array names state $path,propOf,*] { unset state($k) }
    set ci 0
    foreach card $state($path,cards) {
        set fn [::tclutils::tuvcard::fullName $card]
        if {$fn eq ""} { set fn "(no name)" }
        set node [$tv insert {} end -text $fn -open 1 -tags card]
        set state($path,cardOf,$node) $ci
        set pi 0
        foreach p $card {
            set item [$tv insert $node end -text [dict get $p name] -values [list \
                [dict get $p value] [_typeHint [dict get $p params]]]]
            set state($path,propOf,$item) [list $ci $pi]
            incr pi
        }
        incr ci
    }
}

# Load vCard text. Returns the number of contacts.
proc ::tkutils::tkvcard::loadText {path vcf} {
    variable state
    set state($path,cards) [::tclutils::tuvcard::parse $vcf]
    _populate $path
    return [llength $state($path,cards)]
}

proc ::tkutils::tkvcard::loadFile {path file} {
    set ch [open $file r]
    set txt [read $ch]
    close $ch
    return [loadText $path $txt]
}

# Display already-parsed cards.
proc ::tkutils::tkvcard::setCards {path cards} {
    variable state
    set state($path,cards) $cards
    _populate $path
    return [llength $cards]
}

proc ::tkutils::tkvcard::cards {path} {
    variable state
    return $state($path,cards)
}
proc ::tkutils::tkvcard::count {path} {
    variable state
    return [llength $state($path,cards)]
}

# --- editing ------------------------------------------------------------------

proc ::tkutils::tkvcard::_typeParams {type} {
    return [expr {$type eq "" ? {} : [list TYPE $type]}]
}

# Append a new card (with an FN) and return its index.
proc ::tkutils::tkvcard::addCard {path {fn "New Contact"}} {
    variable state
    lappend state($path,cards) [list [dict create name FN value $fn params {}]]
    _populate $path
    return [expr {[llength $state($path,cards)] - 1}]
}
# Remove the card at index.
proc ::tkutils::tkvcard::removeCard {path index} {
    variable state
    set state($path,cards) [lreplace $state($path,cards) $index $index]
    _populate $path
}
# Append a property to a card.
proc ::tkutils::tkvcard::addProperty {path cardIndex name value {type ""}} {
    variable state
    set card [lindex $state($path,cards) $cardIndex]
    set card [::tclutils::tuvcard::addProperty $card $name $value [_typeParams $type]]
    lset state($path,cards) $cardIndex $card
    _populate $path
}
# Remove the property at propIndex of a card.
proc ::tkutils::tkvcard::removeProperty {path cardIndex propIndex} {
    variable state
    set card [lindex $state($path,cards) $cardIndex]
    set card [::tclutils::tuvcard::removeProperty $card $propIndex]
    lset state($path,cards) $cardIndex $card
    _populate $path
}
# Replace the property at propIndex of a card.
proc ::tkutils::tkvcard::setProperty {path cardIndex propIndex name value {type ""}} {
    variable state
    set card [lindex $state($path,cards) $cardIndex]
    set card [::tclutils::tuvcard::setProperty $card $propIndex $name $value [_typeParams $type]]
    lset state($path,cards) $cardIndex $card
    _populate $path
}
# Current contacts as vCard text.
proc ::tkutils::tkvcard::toText {path} {
    variable state
    return [::tclutils::tuvcard::toVcf $state($path,cards)]
}
proc ::tkutils::tkvcard::save {path file} {
    set ch [open $file w]
    fconfigure $ch -translation crlf
    puts -nonewline $ch [toText $path]
    close $ch
    return $file
}

# --- selection + edit-bar handlers -------------------------------------------

proc ::tkutils::tkvcard::_onSelect {path} {
    variable state
    set tv $path.tv
    set item [lindex [$tv selection] 0]
    if {$item eq ""} return
    if {[info exists state($path,propOf,$item)]} {
        lassign $state($path,propOf,$item) ci pi
        set state($path,curCard) $ci
        set state($path,curProp) $pi
        set p [lindex [lindex $state($path,cards) $ci] $pi]
        set state($path,ename) [dict get $p name]
        set state($path,eval)  [dict get $p value]
        set state($path,etype) [_typeHint [dict get $p params]]
    } elseif {[info exists state($path,cardOf,$item)]} {
        set state($path,curCard) $state($path,cardOf,$item)
        set state($path,curProp) -1
    }
}
proc ::tkutils::tkvcard::_uiSetProp {path} {
    variable state
    if {$state($path,curCard) >= 0 && $state($path,curProp) >= 0} {
        setProperty $path $state($path,curCard) $state($path,curProp) \
            $state($path,ename) $state($path,eval) $state($path,etype)
    }
}
proc ::tkutils::tkvcard::_uiAddProp {path} {
    variable state
    if {$state($path,curCard) >= 0 && $state($path,ename) ne ""} {
        addProperty $path $state($path,curCard) \
            $state($path,ename) $state($path,eval) $state($path,etype)
    }
}
proc ::tkutils::tkvcard::_uiDelProp {path} {
    variable state
    if {$state($path,curCard) >= 0 && $state($path,curProp) >= 0} {
        removeProperty $path $state($path,curCard) $state($path,curProp)
        set state($path,curProp) -1
    }
}
proc ::tkutils::tkvcard::_uiAddCard {path} {
    variable state
    set fn [expr {$state($path,ename) ne "" ? $state($path,ename) : "New Contact"}]
    addCard $path $fn
}
proc ::tkutils::tkvcard::_uiDelCard {path} {
    variable state
    if {$state($path,curCard) >= 0} {
        removeCard $path $state($path,curCard)
        set state($path,curCard) -1
        set state($path,curProp) -1
    }
}

package provide tkutils::tkvcard 0.1
