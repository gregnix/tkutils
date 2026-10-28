# tkutils::tkutltree -- convert between nested data and a tablelist tree, with
# Description: convert between nested data and a tablelist tree, with free column mapping.
# Category: Tk · tablelist
# free column mapping. A node is a dict of named fields plus an optional list of
# child nodes under -childrenkey; -fields maps field names to columns in order.
# Library-neutral.
#
# Data model:
#   set data {
#       {name Root  size 0  {children {
#           {name sub1 size 100}
#           {name file size  50}
#       }}}
#   }
#   (each node: <field> <val> ... ?<childrenkey> {<list of nodes>}?)
#
# API:
#   tkutils::tkutltree::fromData tbl data -fields {f ...} ?options?   -> top keys
#   tkutils::tkutltree::toData   tbl       -fields {f ...} ?-childrenkey children?
#                                          ?-node root? ?-idfield f?
#   tkutils::tkutltree::clear    tbl ?-node root?
#   tkutils::tkutltree::lazy     tbl loadCmd -fields {f ...} ?options?
#   tkutils::tkutltree::reveal   tbl index      -> row index (ancestors expanded)
#   tkutils::tkutltree::findId   tbl id         -> row index or -1
#
# fromData options:
#   -childrenkey children   key of the child list in a node
#   -parent root            node to insert under
#   -idfield f              field whose value becomes the row -name (stable id)
#   -lazykey f              node field that marks "has children, load later"
#   -expand none|all|N      collapse all, expand all, or show N levels
#                           (default: as tablelist inserts, i.e. expanded)
#
# lazy: loadCmd is called as {*}loadCmd tbl key when a lazy node is expanded
# (or searched with searchcolumn -descend) and returns a list of nodes. The
# module sets -expandcommand and -populatecommand of the tablelist.
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
# tablelist_tile is the Tablelist variant of tkutils (as in tkutablelist).
# Tablelist forbids loading tablelist and tablelist_tile in one process; both
# provide the same ::tablelist:: commands, so an application that already has
# the classic one keeps it. Up to 2026-10-20 this module required the classic
# "tablelist", and tkutils followed by this module failed with
# "usingTile ... not supported".
if {[catch {package present tablelist}] && [catch {package present tablelist_tile}]} {
    package require tablelist_tile
}

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutltree {
    namespace export fromData toData clear lazy reveal findId
    variable lazyCfg   ;# tbl -> option dict of lazy
}

proc ::tkutils::tkutltree::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLTREE $reason] $msg
}

proc ::tkutils::tkutltree::_parseOpts {argsVar} {
    upvar 1 $argsVar args
    array set o {-fields {} -childrenkey children -parent root -node root
                 -idfield {} -lazykey {} -expand {}}
    foreach {k v} $args {
        if {![info exists o($k)]} { _err OPTION "unknown option \"$k\"" }
        set o($k) $v
    }
    if {[llength $o(-fields)] == 0} { _err FIELDS "-fields is required" }
    if {$o(-expand) ni {{} none all} && ![string is integer -strict $o(-expand)]} {
        _err EXPAND "bad -expand \"$o(-expand)\": must be none, all or a level count"
    }
    return [array get o]
}

# Build the tablelist tree from nested node data. Returns the full keys of
# the inserted top-level nodes.
proc ::tkutils::tkutltree::fromData {tbl data args} {
    array set o [_parseOpts args]
    set keys [_insert $tbl $o(-parent) $data [array get o]]
    switch -- $o(-expand) {
        ""      {}
        none    { foreach k $keys { $tbl collapse $k -fully } }
        all     { foreach k $keys { $tbl expand $k -fully } }
        default {
            foreach k $keys {
                $tbl collapse $k -fully
                _expandLevels $tbl $k $o(-expand)
            }
        }
    }
    return $keys
}

# One insertchildlist per level; ids and lazy marks set on the returned keys.
proc ::tkutils::tkutltree::_insert {tbl parent nodes optList} {
    if {![llength $nodes]} { return {} }
    set fields [dict get $optList -fields]
    set ck     [dict get $optList -childrenkey]
    set idf    [dict get $optList -idfield]
    set lk     [dict get $optList -lazykey]
    set rows {}
    foreach node $nodes {
        lappend rows [lmap f $fields {
            expr {[dict exists $node $f] ? [dict get $node $f] : ""}
        }]
    }
    set keys [$tbl insertchildlist $parent end $rows]
    foreach node $nodes key $keys {
        if {$idf ne "" && [dict exists $node $idf]} {
            $tbl rowconfigure $key -name [dict get $node $idf]
        }
        if {[dict exists $node $ck] && [llength [dict get $node $ck]]} {
            _insert $tbl $key [dict get $node $ck] $optList
        } elseif {$lk ne "" && [dict exists $node $lk] && [dict get $node $lk]} {
            $tbl rowattrib $key tkutltree-lazy 1
            $tbl collapse $key    ;# shows the expand arrow on an empty node
        }
    }
    return $keys
}

proc ::tkutils::tkutltree::_expandLevels {tbl key levels} {
    if {$levels == 0} return
    if {[$tbl childcount $key] == 0} return
    $tbl expand $key -partly
    foreach c [$tbl childkeys $key] { _expandLevels $tbl $c [expr {$levels - 1}] }
}

# Read the tablelist tree back into nested node data.
proc ::tkutils::tkutltree::toData {tbl args} {
    array set o [_parseOpts args]
    return [_read $tbl $o(-node) $o(-fields) $o(-childrenkey) $o(-idfield)]
}

proc ::tkutils::tkutltree::_read {tbl node fields childrenkey idfield} {
    set result {}
    foreach childKey [$tbl childkeys $node] {
        set row [$tbl get $childKey]
        set d {}
        set i 0
        foreach f $fields {
            dict set d $f [lindex $row $i]
            incr i
        }
        if {$idfield ne ""} {
            set id [$tbl rowcget $childKey -name]
            if {$id ne ""} { dict set d $idfield $id }
        }
        set kids [_read $tbl $childKey $fields $childrenkey $idfield]
        if {[llength $kids]} { dict set d $childrenkey $kids }
        lappend result $d
    }
    return $result
}

# Remove all children of a node (default: the whole tree).
proc ::tkutils::tkutltree::clear {tbl args} {
    array set o {-node root}
    foreach {k v} $args {
        if {$k ne "-node"} { _err OPTION "unknown option \"$k\"" }
        set o($k) $v
    }
    if {$o(-node) eq "root"} {
        $tbl delete 0 end
    } else {
        foreach childKey [$tbl childkeys $o(-node)] {
            $tbl delete $childKey
        }
    }
    return
}

# Load children on demand. Nodes inserted with -lazykey get an expand arrow;
# the first expand (or searchcolumn -descend) calls loadCmd once.
proc ::tkutils::tkutltree::lazy {tbl loadCmd args} {
    variable lazyCfg
    array set o [_parseOpts args]
    if {$o(-lazykey) eq ""} { set o(-lazykey) lazy }
    set lazyCfg($tbl) [list cmd $loadCmd opts [array get o]]
    $tbl configure \
        -expandcommand   [list ::tkutils::tkutltree::_load $tbl] \
        -populatecommand [list ::tkutils::tkutltree::_load $tbl]
    bind $tbl <Destroy> +[list array unset ::tkutils::tkutltree::lazyCfg $tbl]
    return $tbl
}

# -expandcommand / -populatecommand: tablelist appends tbl and row.
proc ::tkutils::tkutltree::_load {tbl w row} {
    variable lazyCfg
    if {![info exists lazyCfg($tbl)]} return
    set key [$tbl getfullkeys $row]
    if {![$tbl hasrowattrib $key tkutltree-lazy]} return
    $tbl unsetrowattrib $key tkutltree-lazy
    set nodes [uplevel #0 [list {*}[dict get $lazyCfg($tbl) cmd] $tbl $key]]
    _insert $tbl $key $nodes [dict get $lazyCfg($tbl) opts]
}

# Expand all ancestors of a row so it becomes viewable; scroll to it.
proc ::tkutils::tkutltree::reveal {tbl index} {
    set key [$tbl getfullkeys $index]
    set chain {}
    set p [$tbl parentkey $key]
    while {$p ne "root"} {
        set chain [linsert $chain 0 $p]
        set p [$tbl parentkey $p]
    }
    foreach a $chain { $tbl expand $a -partly }
    set i [$tbl index $key]
    $tbl see $i
    return $i
}

# Row index of an id (row -name) anywhere in the tree, or -1.
proc ::tkutils::tkutltree::findId {tbl id} {
    return [$tbl findrowname $id -descend]
}

package provide tkutils::tkutltree 0.3
