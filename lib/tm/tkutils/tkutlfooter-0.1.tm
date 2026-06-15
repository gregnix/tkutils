# tkutils::tkutlfooter -- a footer row for a tablelist widget, realised as a
# second single-row tablelist ("header at the bottom" look). Mirrors the main
# table's column widths, order and alignment and keeps horizontal scrolling in
# sync (via scrollutil when present, else a manual bridge). Offers auto-sums.
# Library-neutral, no references to any application.
#
# API:
#   tkutils::tkutlfooter::attach  $tblMain $tblFoot ?-autowire 1?
#   tkutils::tkutlfooter::update  $tblMain $tblFoot
#   tkutils::tkutlfooter::setvals $tblFoot {val0 val1 ...}
#   tkutils::tkutlfooter::autosum $tblMain $tblFoot ?-columns {1 2}? \
#                                  ?-label "SUM:"? ?-format "%.2f"?
#   tkutils::tkutlfooter::detach  $tblMain $tblFoot
#
# Numeric parsing for -autosum uses tclutils::tunum when available, otherwise a
# built-in fallback.
#
# Tcl 8.6-
package require Tcl 8.6-
package require tablelist

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutlfooter {
    namespace export attach update setvals autosum detach
    variable state
    variable gid 0
}

proc ::tkutils::tkutlfooter::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLFOOTER $reason] $msg
}

# -------- Public API --------

proc ::tkutils::tkutlfooter::attach {tbl foot args} {
    variable state
    variable gid
    array set opt {-autowire 1}
    array set opt $args

    $foot configure -showlabels 0 -showseparators 0 -selectmode none \
        -exportselection 0

    _cloneColumns $tbl $foot

    if {[$foot size] == 0} {
        $foot insert end [lrepeat [$tbl columncount] ""]
    }
    $foot rowconfigure 0 -selectable 0 -name footer

    if {$opt(-autowire)} {
        set wired 0
        if {![catch {package require scrollutil}]} {
            incr gid
            set top [winfo toplevel $tbl]
            if {$top eq "."} {
                set ssPath ".tkutlfooterSync$gid"
            } else {
                set ssPath "$top.tkutlfooterSync$gid"
            }
            if {![catch {set ss [scrollutil::scrollsync $ssPath]}]} {
                set state($tbl,ss) $ss
                $ss setwidgets [list $tbl $foot]
                set wired 1
            }
        }
        if {!$wired} {
            set origX [$tbl cget -xscrollcommand]
            set state($tbl,origX) $origX
            $tbl  configure -xscrollcommand [list ::tkutils::tkutlfooter::_xsync $tbl $foot $origX]
            $foot configure -xscrollcommand [list ::tkutils::tkutlfooter::_xsync $tbl $foot ""]
        }
    }

    bind $tbl <<TablelistColumnResized>> [list ::tkutils::tkutlfooter::update $tbl $foot]
    bind $tbl <<TablelistColumnMoved>>   [list ::tkutils::tkutlfooter::update $tbl $foot]
    bind $tbl <Configure>                [list ::tkutils::tkutlfooter::update $tbl $foot]

    after idle [list ::tkutils::tkutlfooter::update $tbl $foot]
    return
}

proc ::tkutils::tkutlfooter::detach {tbl foot} {
    variable state
    bind $tbl <<TablelistColumnResized>> {}
    bind $tbl <<TablelistColumnMoved>>   {}
    bind $tbl <Configure>                {}

    if {[info exists state($tbl,ss)]} {
        catch {destroy $state($tbl,ss)}
        unset state($tbl,ss)
    } elseif {[info exists state($tbl,origX)]} {
        catch {$tbl  configure -xscrollcommand $state($tbl,origX)}
        catch {$foot configure -xscrollcommand ""}
        unset state($tbl,origX)
    }
    return
}

proc ::tkutils::tkutlfooter::setvals {foot values} {
    if {[$foot size] == 0} {
        $foot insert end [lrepeat [$foot columncount] ""]
    }
    set n [$foot columncount]
    for {set c 0} {$c < $n} {incr c} {
        $foot cellconfigure 0,$c -text [lindex $values $c]
    }
    return
}

proc ::tkutils::tkutlfooter::update {tbl foot} {
    if {![catch {set order [$tbl cget -columnorder]}]} {
        catch {$foot configure -columnorder $order}
    }
    set n [$tbl columncount]
    for {set c 0} {$c < $n} {incr c} {
        catch {$foot columnconfigure $c -width       [$tbl columncget $c -width]}
        catch {$foot columnconfigure $c -align       [$tbl columncget $c -align]}
        catch {$foot columnconfigure $c -stretchable [$tbl columncget $c -stretchable]}
    }
    if {[$foot size] == 0} {
        $foot insert end [lrepeat $n ""]
    }
    $foot rowconfigure 0 -selectable 0 -name footer
    return
}

# Display-only auto-sums (no data model). Sums the given columns and writes the
# formatted totals into the footer row; column 0 gets -label.
proc ::tkutils::tkutlfooter::autosum {tbl foot args} {
    array set opt {
        -columns {}
        -label   "SUM:"
        -format  "%.2f"
    }
    array set opt $args

    set n [$tbl columncount]
    if {[llength $opt(-columns)] == 0} {
        for {set c 0} {$c < $n} {incr c} { lappend opt(-columns) $c }
    }

    set out [lrepeat $n ""]
    if {$n > 0} { lset out 0 $opt(-label) }

    foreach c $opt(-columns) {
        if {$c < 0 || $c >= $n} continue
        set vals {}
        for {set r 0} {$r < [$tbl size]} {incr r} {
            lappend vals [$tbl cellcget $r,$c -text]
        }
        set total [_sum $vals]
        if {$total ne ""} { lset out $c [format $opt(-format) $total] }
    }
    setvals $foot $out
    return
}

# -------- Internals --------

proc ::tkutils::tkutlfooter::_cloneColumns {tbl foot} {
    set n [$tbl columncount]
    for {set c 0} {$c < $n} {incr c} {
        set w   [$tbl columncget $c -width]
        set ttl [$tbl columncget $c -title]
        set al  [$tbl columncget $c -align]
        if {$c >= [$foot columncount]} {
            $foot insertcolumns end 1 [list $w $ttl $al]
        } else {
            $foot columnconfigure $c -width $w -title $ttl -align $al
        }
    }
    return
}

# Manual x-scroll bridge (fallback without scrollutil).
proc ::tkutils::tkutlfooter::_xsync {tbl foot orig first last} {
    catch {$tbl  xview moveto $first}
    catch {$foot xview moveto $first}
    if {$orig ne ""} {
        uplevel #0 [list {*}$orig $first $last]
    }
    return
}

# Sum a column's string values. Prefers tclutils::tunum; falls back to a local
# parser when tunum is not on the path. Returns "" when nothing was numeric.
proc ::tkutils::tkutlfooter::_sum {vals} {
    if {![catch {package require tclutils::tunum}]} {
        return [::tclutils::tunum::sum $vals -default ""]
    }
    set acc 0.0
    set any 0
    foreach v $vals {
        set x [_parseNumber $v]
        if {$x ne ""} { set acc [expr {$acc + $x}]; set any 1 }
    }
    return [expr {$any ? $acc : ""}]
}

# Fallback number parser (EU 1.234,56 / US 1,234.56 / plain / currency).
proc ::tkutils::tkutlfooter::_parseNumber {s} {
    set t [string trim $s]
    set t [string map [list "\u20AC" "" " " "" "\t" ""] $t]
    if {[regexp {^[+-]?\d{1,3}(\.\d{3})+,\d+$} $t] || [regexp {^[+-]?\d+,\d+$} $t]} {
        set t [string map {"." "" "," "."} $t]
    } else {
        set t [string map {"," ""} $t]
    }
    return [expr {[string is double -strict $t] ? $t+0.0 : ""}]
}

# Per-column aggregations into the footer. -columns is a {col func col func ...}
# list; func is one of: sum avg min max count countnum. Numeric results use
# -format; count/countnum are integers. Column 0 receives -label.
#   ::tkutils::tkutlfooter::autoagg .t .f -columns {1 sum 2 avg 3 max} -label "Σ"
proc ::tkutils::tkutlfooter::autoagg {tbl foot args} {
    array set opt {-columns {} -label "" -format "%.2f"}
    array set opt $args
    if {[llength $opt(-columns)] % 2 != 0} {
        _err SPEC "-columns must be a {col func col func ...} list"
    }
    set n [$tbl columncount]
    set out [lrepeat $n ""]
    if {$n > 0 && $opt(-label) ne ""} { lset out 0 $opt(-label) }

    foreach {col func} $opt(-columns) {
        if {$col < 0 || $col >= $n} continue
        set vals {}
        for {set r 0} {$r < [$tbl size]} {incr r} {
            lappend vals [$tbl cellcget $r,$col -text]
        }
        set res [_agg $func $vals]
        if {$res eq ""} continue
        if {$func in {count countnum}} {
            lset out $col $res
        } else {
            lset out $col [format $opt(-format) $res]
        }
    }
    setvals $foot $out
    return
}

# Apply one aggregate to a list of string values. Returns "" when undefined.
proc ::tkutils::tkutlfooter::_agg {func vals} {
    switch -- $func {
        count    { return [llength $vals] }
        countnum {
            set c 0
            foreach v $vals { if {[_num $v] ne ""} { incr c } }
            return $c
        }
        sum { return [_sum $vals] }
        avg {
            set nums [_nums $vals]
            if {![llength $nums]} { return "" }
            set s 0.0
            foreach x $nums { set s [expr {$s + $x}] }
            return [expr {$s / [llength $nums]}]
        }
        min {
            set nums [_nums $vals]
            if {![llength $nums]} { return "" }
            set r [lindex $nums 0]
            foreach x $nums { if {$x < $r} { set r $x } }
            return $r
        }
        max {
            set nums [_nums $vals]
            if {![llength $nums]} { return "" }
            set r [lindex $nums 0]
            foreach x $nums { if {$x > $r} { set r $x } }
            return $r
        }
        default { _err FUNC "unknown aggregate \"$func\"" }
    }
}

# Parse one value to a number ("" if not numeric). Prefers tclutils::tunum.
proc ::tkutils::tkutlfooter::_num {v} {
    if {![catch {package require tclutils::tunum}]} {
        return [::tclutils::tunum::parse $v -default ""]
    }
    return [_parseNumber $v]
}

# All numeric values from a list (unparsable entries dropped).
proc ::tkutils::tkutlfooter::_nums {vals} {
    set out {}
    foreach v $vals {
        set x [_num $v]
        if {$x ne ""} { lappend out $x }
    }
    return $out
}

package provide tkutils::tkutlfooter 0.1
