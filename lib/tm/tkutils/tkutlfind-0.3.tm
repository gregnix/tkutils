# tkutils::tkutlfind -- incremental find with match highlighting for a tablelist
# Description: incremental find with match highlighting for a tablelist widget.
# Category: Tk · tablelist
# widget. Unlike a filter (which hides non-matching rows), this highlights the
# matching cells and lets you step through them. Library-neutral.
#
# API:
#   tkutils::tkutlfind::find  tbl query ?options?   -> number of matches
#   tkutils::tkutlfind::next  tbl                   -> {row col} | {}
#   tkutils::tkutlfind::prev  tbl                   -> {row col} | {}
#   tkutils::tkutlfind::matches tbl                 -> list of {row col}
#   tkutils::tkutlfind::clear tbl
#
# Options (find):
#   -columns {c ...}  columns to search (default: all visible)
#   -mode    substring|exact|glob|regexp   (default substring)
#   -nocase  0|1      (default 1)
#   -highlightbg COLOR (default #ffe9a8)   -highlightfg COLOR (default {})
#   -hidden  0|1      also search hidden rows (default 0)
#
# Matches are kept as row keys, so next/prev/matches stay right after the
# user sorts. Rows are given as current indices. A match inside a collapsed
# tree node is revealed (ancestors expanded) when next/prev reaches it.
# clear restores the cell colours that were set before find.
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
# Accept either Tablelist variant: an application may already use tablelist_tile
# (the themed build), and Tablelist forbids loading both tablelist and
# tablelist_tile in one process. Both provide the same ::tablelist:: commands
# this module needs, so use whichever is present; only load the classic one if
# neither is -- since 2026-10-20 the themed tablelist_tile, as everywhere
# in tkutils (was the classic tablelist).
if {[catch {package present tablelist}] && [catch {package present tablelist_tile}]} {
    package require tablelist_tile
}

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutlfind {
    namespace export find next prev matches clear
    variable state
}

proc ::tkutils::tkutlfind::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLFIND $reason] $msg
}

proc ::tkutils::tkutlfind::_visibleCols {tbl} {
    set cols {}
    set n [$tbl columncount]
    for {set c 0} {$c < $n} {incr c} {
        set hide 0; catch {set hide [$tbl columncget $c -hide]}
        if {!$hide} { lappend cols $c }
    }
    return $cols
}

proc ::tkutils::tkutlfind::_match {mode nocase needle hay} {
    switch -- $mode {
        substring {
            if {$nocase} { set hay [string tolower $hay]; set needle [string tolower $needle] }
            return [expr {[string first $needle $hay] >= 0}]
        }
        exact {
            if {$nocase} { return [expr {[string equal -nocase $needle $hay]}] }
            return [expr {$needle eq $hay}]
        }
        glob {
            if {$nocase} { return [string match -nocase $needle $hay] }
            return [string match $needle $hay]
        }
        regexp {
            if {$nocase} { return [regexp -nocase -- $needle $hay] }
            return [regexp -- $needle $hay]
        }
        default { _err MODE "unknown mode \"$mode\"" }
    }
}

# Find and highlight all matching cells. Returns the match count.
proc ::tkutils::tkutlfind::find {tbl query args} {
    variable state
    array set o {-columns {} -mode substring -nocase 1 \
                 -highlightbg #ffe9a8 -highlightfg {} -hidden 0}
    foreach {k v} $args {
        if {![info exists o($k)]} { _err OPTION "unknown option \"$k\"" }
        set o($k) $v
    }
    if {$o(-mode) ni {substring exact glob regexp}} {
        _err MODE "unknown mode \"$o(-mode)\""
    }
    clear $tbl
    # forget the state when the widget goes (a new widget may reuse the path)
    if {![string match *tkutlfind* [bind $tbl <Destroy>]]} {
        bind $tbl <Destroy> +[list array unset ::tkutils::tkutlfind::state $tbl,*]
    }
    if {$query eq ""} { return 0 }
    set cols $o(-columns)
    if {[llength $cols] == 0} { set cols [_visibleCols $tbl] }

    set hits {}
    set saved {}
    foreach key [$tbl getfullkeys 0 end] {
        if {!$o(-hidden) && [$tbl rowcget $key -hide]} continue
        set rowData [$tbl getformatted $key]
        foreach c $cols {
            set v ""
            if {[llength $rowData] > $c} { set v [lindex $rowData $c] }
            if {[_match $o(-mode) $o(-nocase) $query $v]} {
                lappend hits [list $key $c]
                lappend saved [list $key $c \
                    [$tbl cellcget $key,$c -background] \
                    [$tbl cellcget $key,$c -foreground]]
                $tbl cellconfigure $key,$c -background $o(-highlightbg)
                if {$o(-highlightfg) ne ""} {
                    $tbl cellconfigure $key,$c -foreground $o(-highlightfg)
                }
            }
        }
    }
    set state($tbl,hits)  $hits
    set state($tbl,saved) $saved
    set state($tbl,idx)   -1
    return [llength $hits]
}

# Current {row col} of every match, in the order of the last find.
proc ::tkutils::tkutlfind::matches {tbl} {
    variable state
    if {![info exists state($tbl,hits)]} { return {} }
    set out {}
    foreach h $state($tbl,hits) {
        lassign $h key c
        set r [_row $tbl $key]
        if {$r < 0} continue   ;# row deleted meanwhile
        lappend out [list $r $c]
    }
    return $out
}

proc ::tkutils::tkutlfind::next {tbl} { return [_step $tbl 1] }
proc ::tkutils::tkutlfind::prev {tbl} { return [_step $tbl -1] }

proc ::tkutils::tkutlfind::_step {tbl dir} {
    variable state
    if {![info exists state($tbl,hits)] || [llength $state($tbl,hits)] == 0} {
        return {}
    }
    set n [llength $state($tbl,hits)]
    set i $state($tbl,idx)
    for {set tries 0} {$tries < $n} {incr tries} {
        set i [expr {($i + $dir) % $n}]
        if {$i < 0} { incr i $n }
        lassign [lindex $state($tbl,hits) $i] key c
        if {[_row $tbl $key] < 0} continue
        set state($tbl,idx) $i
        _reveal $tbl $key
        set r [$tbl index $key]
        catch {$tbl seecell $r,$c}
        catch {$tbl activate $r}
        return [list $r $c]
    }
    return {}
}

# Current index of a row key, -1 once the row is gone.
proc ::tkutils::tkutlfind::_row {tbl key} {
    if {[catch {$tbl index $key} r] || $r < 0 || $r >= [$tbl size]} { return -1 }
    return $r
}

# Expand the collapsed ancestors of a tree row (no-op in a flat table).
proc ::tkutils::tkutlfind::_reveal {tbl key} {
    if {[catch {$tbl parentkey $key} p]} return
    set chain {}
    while {$p ne "root" && $p ne ""} {
        set chain [linsert $chain 0 $p]
        set p [$tbl parentkey $p]
    }
    foreach a $chain {
        if {![$tbl isexpanded $a]} { $tbl expand $a -partly }
    }
}

# Remove all highlights set by the last find; earlier cell colours return.
proc ::tkutils::tkutlfind::clear {tbl} {
    variable state
    if {[info exists state($tbl,saved)]} {
        foreach s $state($tbl,saved) {
            lassign $s key c bg fg
            catch {$tbl cellconfigure $key,$c -background $bg -foreground $fg}
        }
    }
    array unset state $tbl,*
    return
}

package provide tkutils::tkutlfind 0.3
