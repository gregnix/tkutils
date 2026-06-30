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
#   tkutils::tkutltree::fromData tbl data -fields {f ...} ?-childrenkey children? ?-parent root?
#   tkutils::tkutltree::toData   tbl       -fields {f ...} ?-childrenkey children? ?-node root?
#   tkutils::tkutltree::clear    tbl ?-node root?
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
package require tablelist

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutltree {
    namespace export fromData toData clear
}

proc ::tkutils::tkutltree::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLTREE $reason] $msg
}

proc ::tkutils::tkutltree::_parseOpts {argsVar} {
    upvar 1 $argsVar args
    array set o {-fields {} -childrenkey children -parent root -node root}
    foreach {k v} $args {
        if {![info exists o($k)]} { _err OPTION "unknown option \"$k\"" }
        set o($k) $v
    }
    if {[llength $o(-fields)] == 0} { _err FIELDS "-fields is required" }
    return [array get o]
}

# Build the tablelist tree from nested node data.
proc ::tkutils::tkutltree::fromData {tbl data args} {
    array set o [_parseOpts args]
    _insert $tbl $o(-parent) $data $o(-fields) $o(-childrenkey)
    return $tbl
}

proc ::tkutils::tkutltree::_insert {tbl parent nodes fields childrenkey} {
    foreach node $nodes {
        set row {}
        foreach f $fields {
            lappend row [expr {[dict exists $node $f] ? [dict get $node $f] : ""}]
        }
        $tbl insertchild $parent end $row
        set newKey [lindex [$tbl childkeys $parent] end]
        if {[dict exists $node $childrenkey]} {
            set kids [dict get $node $childrenkey]
            if {[llength $kids]} {
                _insert $tbl $newKey $kids $fields $childrenkey
            }
        }
    }
    return
}

# Read the tablelist tree back into nested node data.
proc ::tkutils::tkutltree::toData {tbl args} {
    array set o [_parseOpts args]
    return [_read $tbl $o(-node) $o(-fields) $o(-childrenkey)]
}

proc ::tkutils::tkutltree::_read {tbl node fields childrenkey} {
    set result {}
    foreach childKey [$tbl childkeys $node] {
        set row [$tbl get $childKey]
        set d {}
        set i 0
        foreach f $fields {
            dict set d $f [lindex $row $i]
            incr i
        }
        set kids [_read $tbl $childKey $fields $childrenkey]
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

package provide tkutils::tkutltree 0.1
