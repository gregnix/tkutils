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
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
package require tablelist

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
                 -highlightbg #ffe9a8 -highlightfg {}}
    foreach {k v} $args {
        if {![info exists o($k)]} { _err OPTION "unknown option \"$k\"" }
        set o($k) $v
    }
    clear $tbl
    if {$query eq ""} { return 0 }
    set cols $o(-columns)
    if {[llength $cols] == 0} { set cols [_visibleCols $tbl] }

    set hits {}
    set colored {}
    set nrows [$tbl size]
    for {set r 0} {$r < $nrows} {incr r} {
        set rowData [$tbl getformatted $r]
        foreach c $cols {
            set v ""
            if {[llength $rowData] > $c} { set v [lindex $rowData $c] }
            if {[_match $o(-mode) $o(-nocase) $query $v]} {
                lappend hits [list $r $c]
                $tbl cellconfigure $r,$c -background $o(-highlightbg)
                if {$o(-highlightfg) ne ""} {
                    $tbl cellconfigure $r,$c -foreground $o(-highlightfg)
                }
                lappend colored $r,$c
            }
        }
    }
    set state($tbl,hits)    $hits
    set state($tbl,colored) $colored
    set state($tbl,idx)     -1
    set state($tbl,hlfg)    $o(-highlightfg)
    return [llength $hits]
}

proc ::tkutils::tkutlfind::matches {tbl} {
    variable state
    if {[info exists state($tbl,hits)]} { return $state($tbl,hits) }
    return {}
}

proc ::tkutils::tkutlfind::next {tbl} { return [_step $tbl 1] }
proc ::tkutils::tkutlfind::prev {tbl} { return [_step $tbl -1] }

proc ::tkutils::tkutlfind::_step {tbl dir} {
    variable state
    if {![info exists state($tbl,hits)] || [llength $state($tbl,hits)] == 0} {
        return {}
    }
    set n [llength $state($tbl,hits)]
    set i [expr {($state($tbl,idx) + $dir) % $n}]
    if {$i < 0} { incr i $n }
    set state($tbl,idx) $i
    lassign [lindex $state($tbl,hits) $i] r c
    catch {$tbl seecell $r,$c}
    catch {$tbl activate $r}
    return [list $r $c]
}

# Remove all highlights set by the last find.
proc ::tkutils::tkutlfind::clear {tbl} {
    variable state
    if {[info exists state($tbl,colored)]} {
        set fg [expr {[info exists state($tbl,hlfg)] ? $state($tbl,hlfg) : ""}]
        foreach cell $state($tbl,colored) {
            catch {$tbl cellconfigure $cell -background ""}
            if {$fg ne ""} { catch {$tbl cellconfigure $cell -foreground ""} }
        }
    }
    array unset state $tbl,*
    return
}

package provide tkutils::tkutlfind 0.1
