# tkutils::tkutree -- a thin ttk::treeview wrapper for hierarchical data.
# Description: a thin ttk::treeview wrapper for hierarchical data.
# Category: Tk · widgets
# Build a tree (with optional data columns and a scrollbar), insert nodes, load
# a nested structure in one call, and read selection/text/values back.
# Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutree {
    namespace export widget insert loadTree clear selection itemText \
        itemValues children treeview
    variable state
}

proc ::tkutils::tkutree::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the tree under $path.
# Options: -columns {id ...} data columns (besides the tree column),
# -headings {treeHeading colHeading ...}, -show (default "tree headings" when
# there are columns, else "tree"), -height n, -command cmd (called with the
# selection list on <<TreeviewSelect>>).
proc ::tkutils::tkutree::widget {path args} {
    variable state
    array set opts {-columns {} -headings {} -show "" -height 12 -command ""}
    array set opts $args

    ttk::frame $path
    set state($path,cmd) $opts(-command)
    set state($path,seq) 0
    bind $path <Destroy> [list ::tkutils::tkutree::_cleanup $path %W]

    set show $opts(-show)
    if {$show eq ""} {
        set show [expr {[llength $opts(-columns)] ? {tree headings} : {tree}}]
    }
    ttk::treeview $path.t -columns $opts(-columns) -show $show \
        -height $opts(-height) -selectmode browse
    ttk::scrollbar $path.ys -orient vertical -command [list $path.t yview]
    $path.t configure -yscrollcommand [list $path.ys set]
    grid $path.t $path.ys -sticky nsew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    # headings: first applies to the tree column (#0), the rest to -columns
    if {[llength $opts(-headings)]} {
        $path.t heading #0 -text [lindex $opts(-headings) 0]
        set i 1
        foreach col $opts(-columns) {
            $path.t heading $col -text [lindex $opts(-headings) $i]
            incr i
        }
    }
    bind $path.t <<TreeviewSelect>> [list ::tkutils::tkutree::_select $path]
    return $path
}

# --- public API ----------------------------------------------------------

# Insert a node under $parent ("" = root). Options: -values list, -open bool,
# -id id (auto-generated if omitted). Returns the item id.
proc ::tkutils::tkutree::insert {path parent text args} {
    variable state
    array set o {-values {} -open 0 -id ""}
    array set o $args
    set id $o(-id)
    if {$id eq ""} { set id "n[incr state($path,seq)]" }
    return [$path.t insert $parent end -id $id -text $text \
        -values $o(-values) -open $o(-open)]
}

# Load a nested structure: a list of node dicts. Recognised keys per node:
# text (required), values (list), open (bool), children (list of nodes).
proc ::tkutils::tkutree::loadTree {path nodes {parent ""}} {
    foreach node $nodes {
        set text [dict get $node text]
        set vals {}
        if {[dict exists $node values]} { set vals [dict get $node values] }
        set open 0
        if {[dict exists $node open]} { set open [dict get $node open] }
        set iid ""
        if {[dict exists $node id]} { set iid [dict get $node id] }
        set id [insert $path $parent $text -values $vals -open $open -id $iid]
        if {[dict exists $node children]} {
            loadTree $path [dict get $node children] $id
        }
    }
    return
}

proc ::tkutils::tkutree::clear {path} {
    $path.t delete [$path.t children ""]
    return
}

proc ::tkutils::tkutree::selection {path} {
    return [$path.t selection]
}

proc ::tkutils::tkutree::itemText {path id} {
    return [$path.t item $id -text]
}

proc ::tkutils::tkutree::itemValues {path id} {
    return [$path.t item $id -values]
}

proc ::tkutils::tkutree::children {path {id ""}} {
    return [$path.t children $id]
}

proc ::tkutils::tkutree::treeview {path} {
    return $path.t
}

# --- internals -----------------------------------------------------------

proc ::tkutils::tkutree::_select {path} {
    variable state
    if {$state($path,cmd) ne ""} {
        uplevel #0 [linsert $state($path,cmd) end [$path.t selection]]
    }
}

package provide tkutils::tkutree 0.1
