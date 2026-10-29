# tkutils::tkutlgroup -- group flat rows into a tablelist tree with sums.
# Description: group flat rows under one parent row per key, with column sums.
# Category: Tk · tablelist
# Each distinct value of the key column becomes a parent row; the original
# rows become its children. The parent row carries the key, optional sums and
# an optional member count. Sorting keeps the groups: tablelist sorts the
# parents by their own cells and the children inside each parent.
# Library-neutral.
#
# API:
#   tkutils::tkutlgroup::group   tbl rows keyCol ?options?  -> parent keys
#   tkutils::tkutlgroup::ungroup tbl                        -> flat rows
#
# Options:
#   -sum {c ...}    columns to total in the parent row
#   -count c        column that gets the number of members
#   -blank 0|1      leave the key column empty in child rows (default 1)
#   -format fmt     Tcl format for non-integer sums (default %.2f)
#   -font font      font of the parent rows (default: bold TkDefaultFont)
#   -expand 0|1     show the children (default 1)
#   -replace 0|1    remove all rows of tbl first (default 1); 0 adds the
#                   groups below the rows already there
#
# Numbers in -sum columns may be human formatted ("1.234,56"); they are read
# with tclutils::tunum when it is on the path. Cells that are no number count
# as 0.
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
namespace eval ::tkutils::tkutlgroup {
    namespace export group ungroup
}

proc ::tkutils::tkutlgroup::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLGROUP $reason] $msg
}

proc ::tkutils::tkutlgroup::_num {s} {
    if {[string is double -strict $s]} { return $s }
    if {![catch {package require tclutils::tunum}]} {
        set v [::tclutils::tunum::parse $s -default ""]
        if {$v ne ""} { return $v }
    }
    return ""
}

proc ::tkutils::tkutlgroup::group {tbl rows keyCol args} {
    array set o {-sum {} -count {} -blank 1 -format %.2f -font {} -expand 1 -replace 1}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            _err OPTION "unknown option \"$k\": must be -sum, -count, -blank, -format, -font, -expand or -replace"
        }
        set o($k) $v
    }
    set ncols [$tbl columncount]
    foreach c [list $keyCol {*}$o(-sum) {*}$o(-count)] {
        if {![string is integer -strict $c] || $c < 0 || $c >= $ncols} {
            _err COLUMN "bad column \"$c\": must be 0..[expr {$ncols - 1}]"
        }
    }
    if {$o(-font) eq ""} {
        set o(-font) [font actual TkDefaultFont]
        dict set o(-font) -weight bold
    }
    # a second group call replaced nothing and stacked the groups
    if {$o(-replace)} { $tbl delete 0 end }
    set groups [dict create]
    foreach row $rows { dict lappend groups [lindex $row $keyCol] $row }

    set parents {}
    dict for {key members} $groups {
        set head [lrepeat $ncols {}]
        lset head $keyCol $key
        foreach c $o(-sum) {
            set s 0; set allInt 1
            foreach m $members {
                set v [_num [lindex $m $c]]
                if {$v eq ""} continue
                if {![string is entier -strict $v]} { set allInt 0 }
                set s [expr {$s + $v}]
            }
            # if, not expr ?: -- expr would turn "260.50" back into 260.5
            if {!$allInt} { set s [format $o(-format) $s] }
            lset head $c $s
        }
        if {$o(-count) ne ""} { lset head $o(-count) [llength $members] }
        set pk [$tbl insertchild root end $head]
        $tbl rowconfigure $pk -font $o(-font)
        $tbl rowattrib $pk tkutlgroup-key $key
        $tbl rowattrib $pk tkutlgroup-col $keyCol
        set kids $members
        if {$o(-blank)} { set kids [lmap m $members {lreplace $m $keyCol $keyCol {}}] }
        $tbl insertchildlist $pk end $kids
        if {!$o(-expand)} { $tbl collapse $pk }
        lappend parents $pk
    }
    return $parents
}

# The member rows of all groups, key column filled in again, in the
# current display order.
proc ::tkutils::tkutlgroup::ungroup {tbl} {
    set out {}
    foreach pk [$tbl childkeys root] {
        if {![$tbl hasrowattrib $pk tkutlgroup-key]} continue
        set key [$tbl rowattrib $pk tkutlgroup-key]
        set col [$tbl rowattrib $pk tkutlgroup-col]
        foreach ck [$tbl childkeys $pk] {
            set r [$tbl get $ck]
            lset r $col $key
            lappend out $r
        }
    }
    return $out
}

package provide tkutils::tkutlgroup 0.1
