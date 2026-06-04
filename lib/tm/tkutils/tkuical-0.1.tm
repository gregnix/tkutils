# tkutils::tkuical -- iCalendar event viewer/editor
#
# Shows the VEVENTs of an iCalendar document in a table (Summary, Start, End,
# Location). With -editable 1 (default) an edit bar allows changing those four
# fields and adding/removing events. On save the events are written back into
# the calendar (its other properties and non-event components are preserved;
# events are emitted as direct children of the VCALENDAR). Built on
# tclutils::tuical (requires tclutils 0.35.0+). Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuical 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuical {
    namespace export widget loadText loadFile setComponents events count treeWidget \
        addEvent removeEvent setField setEventProperty addEventProperty \
        removeEventProperty toText save
    variable state
}

proc ::tkutils::tkuical::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkuical::widget {path args} {
    variable state
    array set o {-editable 1}
    array set o $args
    ttk::frame $path
    set state($path,events) {}
    set state($path,calProps) {}
    set state($path,calOther) {}
    set state($path,editable) $o(-editable)
    set state($path,curEvent) -1
    foreach f {esum estart eend eloc} { set state($path,$f) "" }
    bind $path <Destroy> [list ::tkutils::tkuical::_cleanup $path %W]

    set tv $path.tv
    ttk::treeview $tv -columns {start end location} \
        -yscrollcommand [list $path.ys set]
    $tv heading #0 -text "Summary"
    $tv heading start -text "Start"
    $tv heading end -text "End"
    $tv heading location -text "Location"
    $tv column #0 -width 220 -anchor w
    $tv column start -width 120 -anchor w
    $tv column end -width 120 -anchor w
    $tv column location -width 150 -anchor w
    ttk::scrollbar $path.ys -orient vertical -command [list $tv yview]
    grid $tv $path.ys -sticky nsew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    if {$state($path,editable)} {
        set eb $path.eb
        ttk::frame $eb
        ttk::label $eb.sl -text "Summary:"
        ttk::entry $eb.se -width 16 -textvariable ::tkutils::tkuical::state($path,esum)
        ttk::label $eb.al -text "Start:"
        ttk::entry $eb.ae -width 12 -textvariable ::tkutils::tkuical::state($path,estart)
        ttk::label $eb.el -text "End:"
        ttk::entry $eb.ee -width 12 -textvariable ::tkutils::tkuical::state($path,eend)
        ttk::label $eb.ll -text "Loc:"
        ttk::entry $eb.le -width 12 -textvariable ::tkutils::tkuical::state($path,eloc)
        ttk::button $eb.set -text "Set"    -command [list ::tkutils::tkuical::_uiSet $path]
        ttk::button $eb.add -text "Add"    -command [list ::tkutils::tkuical::_uiAdd $path]
        ttk::button $eb.del -text "Delete" -command [list ::tkutils::tkuical::_uiDel $path]
        pack $eb.sl $eb.se $eb.al $eb.ae $eb.el $eb.ee $eb.ll $eb.le \
            $eb.set $eb.add $eb.del -side left -padx 2 -pady 3
        grid $eb - -sticky ew -row 1 -column 0 -columnspan 2
        bind $tv <<TreeviewSelect>> [list ::tkutils::tkuical::_onSelect $path]
    }
    return $path
}

proc ::tkutils::tkuical::treeWidget {path} { return $path.tv }

# Split parsed components into the calendar shell (props + non-event
# sub-components) and the editable list of events.
proc ::tkutils::tkuical::_ingest {path comps} {
    variable state
    set cal ""
    foreach c $comps {
        if {[string equal -nocase [dict get $c type] VCALENDAR]} { set cal $c; break }
    }
    if {$cal ne ""} {
        set state($path,calProps) [dict get $cal props]
        set other {}
        set evs {}
        foreach sub [dict get $cal components] {
            if {[string equal -nocase [dict get $sub type] VEVENT]} {
                lappend evs $sub
            } else {
                lappend other $sub
            }
        }
        set state($path,calOther) $other
        set state($path,events) $evs
    } else {
        set state($path,calProps) {}
        set state($path,calOther) {}
        set state($path,events) [::tclutils::tuical::find $comps VEVENT]
    }
    _populate $path
}

proc ::tkutils::tkuical::_calComp {path} {
    variable state
    set comps $state($path,calOther)
    foreach ev $state($path,events) { lappend comps $ev }
    return [dict create type VCALENDAR props $state($path,calProps) components $comps]
}

proc ::tkutils::tkuical::_populate {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    foreach ev $state($path,events) {
        $tv insert {} end \
            -text [::tclutils::tuical::property $ev SUMMARY] \
            -values [list \
                [::tclutils::tuical::property $ev DTSTART] \
                [::tclutils::tuical::property $ev DTEND] \
                [::tclutils::tuical::property $ev LOCATION]]
    }
}

# Load iCalendar text. Returns the number of events shown.
proc ::tkutils::tkuical::loadText {path ics} {
    variable state
    _ingest $path [::tclutils::tuical::parse $ics]
    return [llength $state($path,events)]
}

proc ::tkutils::tkuical::loadFile {path file} {
    set ch [open $file r]
    set txt [read $ch]
    close $ch
    return [loadText $path $txt]
}

# Display already-parsed components.
proc ::tkutils::tkuical::setComponents {path comps} {
    variable state
    _ingest $path $comps
    return [llength $state($path,events)]
}

proc ::tkutils::tkuical::events {path} {
    variable state
    return $state($path,events)
}
proc ::tkutils::tkuical::count {path} {
    variable state
    return [llength $state($path,events)]
}

# --- editing ------------------------------------------------------------------

proc ::tkutils::tkuical::_fieldProp {field} {
    switch -- $field {
        summary  { return SUMMARY }
        start    { return DTSTART }
        end      { return DTEND }
        location { return LOCATION }
        default  { return [string toupper $field] }
    }
}

# Append a new event (optionally with a summary). Returns its index.
proc ::tkutils::tkuical::addEvent {path {summary ""}} {
    variable state
    set ev [dict create type VEVENT props {} components {}]
    if {$summary ne ""} { set ev [::tclutils::tuical::setProperty $ev SUMMARY $summary] }
    lappend state($path,events) $ev
    _populate $path
    return [expr {[llength $state($path,events)] - 1}]
}
proc ::tkutils::tkuical::removeEvent {path index} {
    variable state
    set state($path,events) [lreplace $state($path,events) $index $index]
    _populate $path
}
# Set one of the displayed fields (summary/start/end/location) of an event.
proc ::tkutils::tkuical::setField {path index field value} {
    variable state
    set ev [lindex $state($path,events) $index]
    set ev [::tclutils::tuical::setProperty $ev [_fieldProp $field] $value]
    lset state($path,events) $index $ev
    _populate $path
}
proc ::tkutils::tkuical::setEventProperty {path index name value {params {}}} {
    variable state
    set ev [lindex $state($path,events) $index]
    set ev [::tclutils::tuical::setProperty $ev $name $value $params]
    lset state($path,events) $index $ev
    _populate $path
}
proc ::tkutils::tkuical::addEventProperty {path index name value {params {}}} {
    variable state
    set ev [lindex $state($path,events) $index]
    set ev [::tclutils::tuical::addProperty $ev $name $value $params]
    lset state($path,events) $index $ev
    _populate $path
}
proc ::tkutils::tkuical::removeEventProperty {path index name} {
    variable state
    set ev [lindex $state($path,events) $index]
    set ev [::tclutils::tuical::removeProperty $ev $name]
    lset state($path,events) $index $ev
    _populate $path
}
# Current calendar as iCalendar text.
proc ::tkutils::tkuical::toText {path} {
    return [::tclutils::tuical::toIcs [_calComp $path]]
}
proc ::tkutils::tkuical::save {path file} {
    set ch [open $file w]
    fconfigure $ch -translation crlf
    puts -nonewline $ch [toText $path]
    close $ch
    return $file
}

# --- selection + edit-bar handlers -------------------------------------------

proc ::tkutils::tkuical::_onSelect {path} {
    variable state
    set tv $path.tv
    set item [lindex [$tv selection] 0]
    if {$item eq ""} return
    set idx [lsearch -exact [$tv children {}] $item]
    if {$idx < 0} return
    set state($path,curEvent) $idx
    set ev [lindex $state($path,events) $idx]
    set state($path,esum)   [::tclutils::tuical::property $ev SUMMARY]
    set state($path,estart) [::tclutils::tuical::property $ev DTSTART]
    set state($path,eend)   [::tclutils::tuical::property $ev DTEND]
    set state($path,eloc)   [::tclutils::tuical::property $ev LOCATION]
}
proc ::tkutils::tkuical::_uiSet {path} {
    variable state
    set i $state($path,curEvent)
    if {$i < 0} return
    setField $path $i summary  $state($path,esum)
    setField $path $i start    $state($path,estart)
    setField $path $i end      $state($path,eend)
    setField $path $i location $state($path,eloc)
}
proc ::tkutils::tkuical::_uiAdd {path} {
    variable state
    set i [addEvent $path $state($path,esum)]
    setField $path $i start    $state($path,estart)
    setField $path $i end      $state($path,eend)
    setField $path $i location $state($path,eloc)
    set state($path,curEvent) $i
}
proc ::tkutils::tkuical::_uiDel {path} {
    variable state
    if {$state($path,curEvent) >= 0} {
        removeEvent $path $state($path,curEvent)
        set state($path,curEvent) -1
    }
}

package provide tkutils::tkuical 0.1
