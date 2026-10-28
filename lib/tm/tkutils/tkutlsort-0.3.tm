# tkutils::tkutlsort -- type-aware column sorting for a tablelist widget.
# Description: type-aware column sorting for a tablelist widget.
# Category: Tk · tablelist
# tablelist sorts dictionary/ascii by default, which mis-orders numeric and
# currency columns ("1.234,56 €", "9,90 €", "10,00 €"). This module sets the
# right -sortmode per column, including a "num" mode that parses human-formatted
# numbers via tclutils::tunum. Library-neutral.
#
# API:
#   tkutils::tkutlsort::column  tbl col type ?cmd? ?-empty first|last?
#   tkutils::tkutlsort::columns tbl {col type col type ...} ?-empty first|last?
#
# type: string | nocase | integer | real | num | command
#   string  -> dictionary       (default tablelist behaviour, case-insensitive-ish)
#   nocase  -> asciinocase
#   integer -> integer
#   real    -> real             (plain Tcl doubles only, e.g. "12.5")
#   num     -> command, comparing via tclutils::tunum (EU/US grouping, currency)
#   command -> command, using the supplied 2-argument comparison proc (?cmd?)
#
# -empty first|last (integer, real, num): where empty and unparsable cells go,
# in both sort directions. Without it integer/real keep tablelist's own mode
# (which fails on empty cells) and num puts them last when ascending.
#
# Tcl 8.6-
package require Tcl 8.6-
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
namespace eval ::tkutils::tkutlsort {
    namespace export column columns
    variable seq 0
}

proc ::tkutils::tkutlsort::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLSORT $reason] $msg
}

# Configure one column's sort behaviour.
proc ::tkutils::tkutlsort::column {tbl col type args} {
    set cmd ""
    if {[llength $args] % 2} { set args [lassign $args cmd] }
    set empty ""
    foreach {k v} $args {
        if {$k ne "-empty"} { _err OPTION "unknown option \"$k\": must be -empty" }
        if {$v ni {first last}} { _err EMPTY "bad -empty \"$v\": must be first or last" }
        set empty $v
    }
    if {$empty ne "" && $type in {integer real num}} {
        variable seq
        set sc [list ::tkutils::tkutlsort::_cmpEmpty $tbl $type $empty [incr seq]]
        $tbl columnconfigure $col -sortmode command -sortcommand $sc
        return $col
    }
    switch -- $type {
        string  { $tbl columnconfigure $col -sortmode dictionary }
        nocase  { $tbl columnconfigure $col -sortmode asciinocase }
        integer { $tbl columnconfigure $col -sortmode integer }
        real    { $tbl columnconfigure $col -sortmode real }
        num {
            $tbl columnconfigure $col -sortmode command \
                -sortcommand ::tkutils::tkutlsort::_cmpNum
        }
        command {
            if {$cmd eq ""} {
                _err CMD "sort type \"command\" requires a comparison proc"
            }
            $tbl columnconfigure $col -sortmode command -sortcommand $cmd
        }
        default { _err TYPE "unknown sort type \"$type\"" }
    }
    return $col
}

# Configure several columns at once from a {col type col type ...} list.
proc ::tkutils::tkutlsort::columns {tbl spec args} {
    if {[llength $spec] % 2 != 0} {
        _err SPEC "column spec must have an even number of elements"
    }
    foreach {col type} $spec {
        if {$type in {integer real num}} {
            column $tbl $col $type {*}$args
        } else {
            column $tbl $col $type
        }
    }
    return
}

# Comparison with a fixed place for empty cells. Tablelist reverses the
# result for a decreasing sort, so the proc looks up its column's current
# order (by the token in its -sortcommand) and compensates.
proc ::tkutils::tkutlsort::_cmpEmpty {tbl type empty token a b} {
    set x [_value $type $a]
    set y [_value $type $b]
    if {$x eq "" || $y eq ""} {
        if {$x eq "" && $y eq ""} { return 0 }
        set r [expr {$x eq "" ? 1 : -1}]
        if {$empty eq "first"} { set r [expr {-$r}] }
        if {[_order $tbl $token] eq "decreasing"} { set r [expr {-$r}] }
        return $r
    }
    return [expr {$x < $y ? -1 : ($x > $y ? 1 : 0)}]
}

proc ::tkutils::tkutlsort::_value {type s} {
    switch -- $type {
        integer { return [expr {[string is entier -strict [string trim $s]] ? [string trim $s] : ""}] }
        real    { return [expr {[string is double -strict [string trim $s]] ? [string trim $s] : ""}] }
        default {
            if {![catch {package require tclutils::tunum}]} {
                return [::tclutils::tunum::parse $s -default ""]
            }
            return [_fallbackParse $s]
        }
    }
}

proc ::tkutils::tkutlsort::_order {tbl token} {
    foreach c [$tbl sortcolumnlist] o [$tbl sortorderlist] {
        if {[lindex [$tbl columncget $c -sortcommand] 4] eq $token} { return $o }
    }
    return increasing
}

# Numeric comparison of two human-formatted cell strings. Unparsable values
# (empty cells, text) sort after all numbers.
proc ::tkutils::tkutlsort::_cmpNum {a b} {
    set x ""; set y ""
    if {![catch {package require tclutils::tunum}]} {
        set x [::tclutils::tunum::parse $a -default ""]
        set y [::tclutils::tunum::parse $b -default ""]
    } else {
        set x [_fallbackParse $a]
        set y [_fallbackParse $b]
    }
    if {$x eq "" && $y eq ""} { return 0 }
    if {$x eq ""} { return 1 }
    if {$y eq ""} { return -1 }
    return [expr {$x < $y ? -1 : ($x > $y ? 1 : 0)}]
}

# Minimal local parser used only when tclutils::tunum is not on the path.
proc ::tkutils::tkutlsort::_fallbackParse {s} {
    set t [string trim $s]
    set t [string map [list "\u20AC" "" " " "" "\t" ""] $t]
    if {[regexp {^[+-]?\d{1,3}(\.\d{3})+,\d+$} $t] || [regexp {^[+-]?\d+,\d+$} $t]} {
        set t [string map {"." "" "," "."} $t]
    } else {
        set t [string map {"," ""} $t]
    }
    return [expr {[string is double -strict $t] ? $t+0.0 : ""}]
}

package provide tkutils::tkutlsort 0.3
