# tkutils::tkutodo -- a task-list widget for iCalendar VTODO components, built on
# Description: a task-list widget for iCalendar VTODO components, built on tclutils::tuical (todos / todoInfo / setProperty).
# Category: Tk · widgets
# tclutils::tuical (todos / todoInfo / setProperty). Shows summary, due date,
# priority and percent-complete in a ttk::treeview; in editable mode a task's
# done state can be toggled (Space, double-click, or the Toggle button), which
# rewrites STATUS / PERCENT-COMPLETE / COMPLETED on the underlying component.
#
#   set w [tkutodo::widget .t]
#   pack $w -fill both -expand 1
#   tkutodo::loadText .t $ics            ;# parse + extract all VTODOs
#   tkutodo::toggle .t                   ;# flip the selected task's done state
#   set ics [tuical::toIcs [tkutodo::todos .t]]   ;# write changes back

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuical 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutodo {
    namespace export widget treeWidget setTodos loadText todos count toggle
    variable state
    array set state {}
    variable version 0.1
}

proc ::tkutils::tkutodo::widget {path args} {
    variable state
    array set o {-editable 1 -onchange ""}
    array set o $args
    ttk::frame $path
    set state($path,todos) {}
    set state($path,editable) $o(-editable)
    set state($path,onchange) $o(-onchange)
    set state($path,curTodo) -1
    bind $path <Destroy> [list ::tkutils::tkutodo::_cleanup $path %W]

    set tv $path.tv
    ttk::treeview $tv -columns {status due priority percent} \
        -yscrollcommand [list $path.ys set]
    $tv heading #0 -text "Task"
    $tv heading status   -text "Done"
    $tv heading due      -text "Due"
    $tv heading priority -text "Prio"
    $tv heading percent  -text "%"
    $tv column #0       -width 260 -anchor w
    $tv column status   -width 50  -anchor center
    $tv column due      -width 130 -anchor w
    $tv column priority -width 50  -anchor center
    $tv column percent  -width 50  -anchor e
    $tv tag configure done -foreground "#7a7a7a"
    ttk::scrollbar $path.ys -orient vertical -command [list $tv yview]
    grid $tv      -row 0 -column 0 -sticky nsew
    grid $path.ys -row 0 -column 1 -sticky ns
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    bind $tv <<TreeviewSelect>> [list ::tkutils::tkutodo::_onSelect $path]
    if {$state($path,editable)} {
        bind $tv <Double-1>  [list ::tkutils::tkutodo::_onActivate $path]
        bind $tv <space>     [list ::tkutils::tkutodo::_onActivate $path]
        set bb $path.bb
        ttk::frame $bb
        ttk::button $bb.toggle -text "Toggle done" \
            -command [list ::tkutils::tkutodo::toggle $path]
        pack $bb.toggle -side left -padx 2 -pady 3
        grid $bb - -row 1 -column 0 -columnspan 2 -sticky ew
    }
    return $path
}

proc ::tkutils::tkutodo::treeWidget {path} { return $path.tv }

proc ::tkutils::tkutodo::setTodos {path comps} {
    variable state
    set state($path,todos) $comps
    set state($path,curTodo) -1
    _populate $path
    return [llength $comps]
}

proc ::tkutils::tkutodo::loadText {path ics} {
    return [setTodos $path [::tclutils::tuical::todos [::tclutils::tuical::parse $ics]]]
}

proc ::tkutils::tkutodo::todos {path} {
    variable state
    return $state($path,todos)
}

proc ::tkutils::tkutodo::count {path} {
    variable state
    return [llength $state($path,todos)]
}

proc ::tkutils::tkutodo::_isDone {comp} {
    expr {[string equal -nocase [::tclutils::tuical::property $comp STATUS] COMPLETED]}
}

proc ::tkutils::tkutodo::_populate {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    foreach k [array names state $path,itemOf,*] { unset state($k) }
    set i 0
    foreach comp $state($path,todos) {
        set info [::tclutils::tuical::todoInfo $comp]
        set summary [dict get $info summary]
        if {$summary eq ""} { set summary "(no summary)" }
        set done [_isDone $comp]
        set mark [expr {$done ? "\u2713" : ""}]
        set pct [dict get $info percentComplete]
        set tags [expr {$done ? "done" : ""}]
        set item [$tv insert {} end -text $summary -tags $tags -values [list \
            $mark [dict get $info due] [dict get $info priority] \
            [expr {$pct eq "" ? "" : "$pct%"}]]]
        set state($path,itemOf,$item) $i
        incr i
    }
}

proc ::tkutils::tkutodo::_onSelect {path} {
    variable state
    set item [lindex [$path.tv selection] 0]
    if {$item ne "" && [info exists state($path,itemOf,$item)]} {
        set state($path,curTodo) $state($path,itemOf,$item)
    }
}

proc ::tkutils::tkutodo::_onActivate {path} {
    toggle $path
}

# Flip the done state of the selected task (or the task at $index).
proc ::tkutils::tkutodo::toggle {path {index ""}} {
    variable state
    if {$index eq ""} { set index $state($path,curTodo) }
    if {$index < 0 || $index >= [llength $state($path,todos)]} { return }
    set comp [lindex $state($path,todos) $index]
    _setDone $path $index [expr {![_isDone $comp]}]
}

proc ::tkutils::tkutodo::_setDone {path index done} {
    variable state
    set comp [lindex $state($path,todos) $index]
    if {$done} {
        set comp [::tclutils::tuical::setProperty $comp STATUS COMPLETED]
        set comp [::tclutils::tuical::setProperty $comp PERCENT-COMPLETE 100]
        set comp [::tclutils::tuical::setProperty $comp COMPLETED \
            [clock format [clock seconds] -format %Y%m%dT%H%M%SZ -gmt 1]]
    } else {
        set comp [::tclutils::tuical::setProperty $comp STATUS NEEDS-ACTION]
        set comp [::tclutils::tuical::setProperty $comp PERCENT-COMPLETE 0]
        set comp [::tclutils::tuical::removeProperty $comp COMPLETED]
    }
    lset state($path,todos) $index $comp
    _populate $path
    if {$state($path,onchange) ne ""} {
        uplevel #0 [list {*}$state($path,onchange) $path]
    }
}

proc ::tkutils::tkutodo::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

package provide tkutils::tkutodo 0.1
