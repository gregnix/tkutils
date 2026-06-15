# tkutils::tkutlsort -- type-aware column sorting for a tablelist widget.
# tablelist sorts dictionary/ascii by default, which mis-orders numeric and
# currency columns ("1.234,56 €", "9,90 €", "10,00 €"). This module sets the
# right -sortmode per column, including a "num" mode that parses human-formatted
# numbers via tclutils::tunum. Library-neutral.
#
# API:
#   tkutils::tkutlsort::column  tbl col type ?cmd?
#   tkutils::tkutlsort::columns tbl {col type col type ...}
#
# type: string | nocase | integer | real | num | command
#   string  -> dictionary       (default tablelist behaviour, case-insensitive-ish)
#   nocase  -> asciinocase
#   integer -> integer
#   real    -> real             (plain Tcl doubles only, e.g. "12.5")
#   num     -> command, comparing via tclutils::tunum (EU/US grouping, currency)
#   command -> command, using the supplied 2-argument comparison proc (?cmd?)
#
# Tcl 8.6-
package require Tcl 8.6-
package require tablelist

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutlsort {
    namespace export column columns
}

proc ::tkutils::tkutlsort::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLSORT $reason] $msg
}

# Configure one column's sort behaviour.
proc ::tkutils::tkutlsort::column {tbl col type {cmd ""}} {
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
proc ::tkutils::tkutlsort::columns {tbl spec} {
    if {[llength $spec] % 2 != 0} {
        _err SPEC "column spec must have an even number of elements"
    }
    foreach {col type} $spec {
        column $tbl $col $type
    }
    return
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

package provide tkutils::tkutlsort 0.1
