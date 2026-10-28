# tkutils::tkutldrag -- let the user reorder tablelist rows with the mouse.
# Description: drag-and-drop row reordering for a tablelist, with a callback.
# Category: Tk · tablelist
# Wraps tablelist's -movablerows: sets a select mode that supports it,
# optionally limits moves to the same parent, and calls back after a move
# with the row's id (row -name) or key. order returns the current order of
# ids, e.g. to store a user-defined order. Library-neutral.
#
# API:
#   tkutils::tkutldrag::enable  tbl ?options?
#   tkutils::tkutldrag::disable tbl
#   tkutils::tkutldrag::order   tbl ?parent?    -> ids (or keys) of the children
#
# Options:
#   -command cmd     after a move: {*}cmd tbl id parent position
#                    (id = row -name, or the key when the row has no name)
#   -samelevel 0|1   only reorder among siblings, no new parent (default 1)
#   -acceptchild cmd / -acceptdrop cmd   own tablelist accept commands
#                    (override -samelevel)
#
# Select mode: -movablerows works with single or multiple only; browse
# becomes single, extended becomes multiple.
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
# Accept either Tablelist variant (tablelist_tile is the tkutils default);
# Tablelist forbids loading both in one process.
if {[catch {package present tablelist}] && [catch {package present tablelist_tile}]} {
    package require tablelist_tile
}


namespace eval ::tkutils {}
namespace eval ::tkutils::tkutldrag {
    namespace export enable disable order
    variable cmd
}

proc ::tkutils::tkutldrag::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLDRAG $reason] $msg
}

proc ::tkutils::tkutldrag::enable {tbl args} {
    variable cmd
    array set o {-command {} -samelevel 1 -acceptchild {} -acceptdrop {}}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            _err OPTION "unknown option \"$k\": must be -command, -samelevel, -acceptchild or -acceptdrop"
        }
        set o($k) $v
    }
    switch -- [$tbl cget -selectmode] {
        browse   { $tbl configure -selectmode single }
        extended { $tbl configure -selectmode multiple }
    }
    set ac $o(-acceptchild)
    set ad $o(-acceptdrop)
    if {$o(-samelevel)} {
        if {$ac eq ""} { set ac ::tkutils::tkutldrag::_noChild }
        if {$ad eq ""} { set ad ::tkutils::tkutldrag::_sibling }
    }
    $tbl configure -movablerows 1 -acceptchildcommand $ac -acceptdropcommand $ad
    set cmd($tbl) $o(-command)
    bind $tbl <<TablelistRowMoved>> [list ::tkutils::tkutldrag::_moved $tbl %d]
    bind $tbl <Destroy> +[list array unset ::tkutils::tkutldrag::cmd $tbl]
    return [$tbl cget -selectmode]
}

proc ::tkutils::tkutldrag::disable {tbl} {
    variable cmd
    $tbl configure -movablerows 0 -acceptchildcommand {} -acceptdropcommand {}
    bind $tbl <<TablelistRowMoved>> {}
    unset -nocomplain cmd($tbl)
    return
}

# No row becomes the child of another one.
proc ::tkutils::tkutldrag::_noChild {tbl parent row} { return 0 }

# A row may only be dropped before a sibling (or at the end of its parent).
proc ::tkutils::tkutldrag::_sibling {tbl target row} {
    set p [$tbl parentkey $row]
    if {$target >= [$tbl size]} { return [expr {$p eq "root"}] }
    return [expr {[$tbl parentkey $target] eq $p}]
}

proc ::tkutils::tkutldrag::_moved {tbl data} {
    variable cmd
    if {![info exists cmd($tbl)] || $cmd($tbl) eq ""} return
    lassign $data key parent pos
    set id [$tbl rowcget $key -name]
    if {$id eq ""} { set id $key }
    uplevel #0 [list {*}$cmd($tbl) $tbl $id $parent $pos]
}

# Children of parent (default root) in display order: their ids, or keys
# for rows without a -name.
proc ::tkutils::tkutldrag::order {tbl {parent root}} {
    lmap k [$tbl childkeys $parent] {
        set id [$tbl rowcget $k -name]
        expr {$id ne "" ? $id : $k}
    }
}

package provide tkutils::tkutldrag 0.1
