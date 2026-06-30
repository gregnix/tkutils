# tkutils::tkutlfmt -- per-column display formatting for a tablelist widget via
# Description: per-column display formatting for a tablelist widget via tablelist's -formatcommand.
# Category: Tk · tablelist
# tablelist's -formatcommand. The underlying cell value stays unchanged (so
# sorting/filtering still see the raw number); only the displayed text is
# formatted. Pairs with tkutils::tkutlsort. Library-neutral.
#
# API:
#   tkutils::tkutlfmt::column  tbl col type ?options?
#   tkutils::tkutlfmt::columns tbl {col type ?{options}? ...}
#
# type: integer | number | currency | percent | date
#   integer  -> grouped integer            (1.234.567)
#   number   -> grouped, -decimals places  (1.234,56)
#   currency -> number + -symbol           (1.234,56 €)
#   percent  -> value*100 + "%"            (12,5 %)
#   date     -> clock reformat             (-informat/-outformat)
#
# Numeric options:  -decimals N  -group SEP  -decimal SEP  -symbol S
#   -symbolpos pre|post  -locale eu|us  -align right|left|center|{}
# Date options:     -informat FMT  -outformat FMT  (clock format strings)
#
# -locale eu (default) => group "." decimal ",";  us => group "," decimal "."
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
package require tablelist

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutlfmt {
    namespace export column columns
}

proc ::tkutils::tkutlfmt::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLFMT $reason] $msg
}

# Configure one column's display format. Sets -formatcommand and, for numeric
# types, -align right (unless -align is given explicitly).
proc ::tkutils::tkutlfmt::column {tbl col type args} {
    array set o {
        -decimals {} -group {} -decimal {} -symbol "\u20AC" -symbolpos post
        -locale eu -align {} -informat {} -outformat {%Y-%m-%d}
    }
    array set o $args
    foreach {k v} $args {
        if {![info exists o($k)]} { _err OPTION "unknown option \"$k\"" }
    }
    # locale defaults for group/decimal
    if {$o(-group) eq "" || $o(-decimal) eq ""} {
        switch -- $o(-locale) {
            eu { set g "."; set d "," }
            us { set g ","; set d "." }
            default { _err LOCALE "locale must be eu or us" }
        }
        if {$o(-group)   eq ""} { set o(-group)   $g }
        if {$o(-decimal) eq ""} { set o(-decimal) $d }
    }
    # default decimals per type
    if {$o(-decimals) eq ""} {
        set o(-decimals) [dict get {integer 0 number 2 currency 2 percent 1 date 0} \
                              [expr {$type in {integer number currency percent date} ? $type : "number"}]]
    }

    set align $o(-align)
    switch -- $type {
        integer  { set cmd [list ::tkutils::tkutlfmt::_num 0 $o(-group) $o(-decimal) "" pre 1] }
        number   { set cmd [list ::tkutils::tkutlfmt::_num $o(-decimals) $o(-group) $o(-decimal) "" pre 1] }
        currency { set cmd [list ::tkutils::tkutlfmt::_num $o(-decimals) $o(-group) $o(-decimal) $o(-symbol) $o(-symbolpos) 1] }
        percent  { set cmd [list ::tkutils::tkutlfmt::_num $o(-decimals) $o(-group) $o(-decimal) "%" post 100] }
        date     { set cmd [list ::tkutils::tkutlfmt::_date $o(-informat) $o(-outformat)] }
        default  { _err TYPE "unknown format type \"$type\"" }
    }
    $tbl columnconfigure $col -formatcommand $cmd
    if {$align eq "" && $type in {integer number currency percent}} {
        set align right
    }
    if {$align ne ""} { $tbl columnconfigure $col -align $align }
    return $col
}

# Configure several columns: {col type ?{options}? col type ?{options}? ...}
# Each entry is "col type" optionally followed by a brace-grouped option list.
proc ::tkutils::tkutlfmt::columns {tbl spec} {
    set i 0
    set n [llength $spec]
    while {$i < $n} {
        set col  [lindex $spec $i]
        set type [lindex $spec [expr {$i+1}]]
        set opts {}
        set nxt [lindex $spec [expr {$i+2}]]
        # an options group is a list with an even number of dash-led elements
        if {$nxt ne "" && [llength $nxt] >= 2 && [string match -* [lindex $nxt 0]]} {
            set opts $nxt
            incr i 3
        } else {
            incr i 2
        }
        column $tbl $col $type {*}$opts
    }
    return
}

# Numeric formatter (bound as -formatcommand; tablelist appends the cell value).
proc ::tkutils::tkutlfmt::_num {decimals group decimal symbol sympos scale value} {
    set num [_parse $value]
    if {$num eq ""} { return $value }
    set num [expr {$num * $scale}]
    set neg [expr {$num < 0}]
    set num [expr {abs($num)}]
    set s [format "%.${decimals}f" $num]
    set ip $s; set fp ""
    if {[string first . $s] >= 0} { lassign [split $s .] ip fp }
    set ip [_group $ip $group]
    set res $ip
    if {$decimals > 0} { append res $decimal $fp }
    if {$neg} { set res "-$res" }
    if {$symbol ne ""} {
        if {$sympos eq "pre"} { set res "$symbol$res" } else { set res "$res $symbol" }
    }
    return $res
}

# Insert the group separator every three digits from the right.
proc ::tkutils::tkutlfmt::_group {digits sep} {
    if {$sep eq ""} { return $digits }
    set out ""
    set cnt 0
    for {set i [expr {[string length $digits]-1}]} {$i >= 0} {incr i -1} {
        append out [string index $digits $i]
        incr cnt
        if {$cnt % 3 == 0 && $i > 0} { append out $sep }
    }
    return [string reverse $out]
}

# Robust value -> number (prefers tclutils::tunum, else a local parser).
proc ::tkutils::tkutlfmt::_parse {value} {
    if {[string is double -strict $value]} { return $value }
    if {![catch {package require tclutils::tunum}]} {
        return [::tclutils::tunum::parse $value -default ""]
    }
    set t [string trim $value]
    set t [string map [list "\u20AC" "" " " "" "\t" ""] $t]
    if {[regexp {^[+-]?\d{1,3}(\.\d{3})+,\d+$} $t] || [regexp {^[+-]?\d+,\d+$} $t]} {
        set t [string map {"." "" "," "."} $t]
    } else {
        set t [string map {"," ""} $t]
    }
    return [expr {[string is double -strict $t] ? $t+0.0 : ""}]
}

# Date formatter: parse (clock scan with -informat, or accept an epoch) and
# reformat with -outformat. Non-dates are returned unchanged.
proc ::tkutils::tkutlfmt::_date {informat outformat value} {
    if {[string trim $value] eq ""} { return $value }
    set epoch ""
    if {[string is integer -strict $value]} {
        set epoch $value
    } elseif {$informat ne ""} {
        catch {set epoch [clock scan $value -format $informat]}
    } else {
        catch {set epoch [clock scan $value]}
    }
    if {$epoch eq ""} { return $value }
    return [clock format $epoch -format $outformat]
}

package provide tkutils::tkutlfmt 0.1
