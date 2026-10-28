# tkutils::tkutlfilter -- filter a tablelist by hiding rows that do not match.
# Description: filter a tablelist by hiding non-matching rows.
# Category: Tk · tablelist
# Rows stay in the widget (ids, attributes, embedded windows are kept); the
# filter only sets -hide. Rows hidden by the application before are left
# alone. In a tree a parent stays visible while a descendant matches.
# Library-neutral.
#
# API:
#   tkutils::tkutlfilter::filter tbl query ?options?   -> number of matching rows
#   tkutils::tkutlfilter::later tbl ms query ?options? -> debounced filter
#   tkutils::tkutlfilter::clear tbl                   -> shows the filtered rows
#   tkutils::tkutlfilter::query tbl                   -> current query or ""
#
# Options:
#   -columns {c ...}  columns to test (default: all visible)
#   -mode    substring|exact|glob|regexp   (default substring)
#   -nocase  0|1      (default 1)
#   -where {col text ...}  per-column conditions, all must match (AND);
#                     col is an index, a column -name or a title. Fits the
#                     dict that tkutils::tkufilterbar reports.
#   -command cmd      own test: {*}cmd tbl key row -> 0|1
#
# A row is shown when it matches the query (in any of -columns), every
# -where condition and the -command. An empty query and no -where or
# -command clears the filter.
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
namespace eval ::tkutils::tkutlfilter {
    namespace export filter later clear query
    variable state
}

proc ::tkutils::tkutlfilter::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLFILTER $reason] $msg
}

proc ::tkutils::tkutlfilter::_match {mode nocase needle hay} {
    switch -- $mode {
        substring {
            if {$nocase} { return [expr {[string first [string tolower $needle] [string tolower $hay]] >= 0}] }
            return [expr {[string first $needle $hay] >= 0}]
        }
        exact  { return [expr {$nocase ? [string equal -nocase $needle $hay] : $needle eq $hay}] }
        glob   { return [expr {$nocase ? [string match -nocase $needle $hay] : [string match $needle $hay]}] }
        regexp { return [expr {$nocase ? [regexp -nocase -- $needle $hay] : [regexp -- $needle $hay]}] }
    }
}

proc ::tkutils::tkutlfilter::filter {tbl query args} {
    variable state
    array set o {-columns {} -mode substring -nocase 1 -command {} -where {}}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            _err OPTION "unknown option \"$k\": must be -columns, -mode, -nocase, -where or -command"
        }
        set o($k) $v
    }
    if {$o(-mode) ni {substring exact glob regexp}} {
        _err MODE "bad mode \"$o(-mode)\": must be substring, exact, glob or regexp"
    }
    if {[llength $o(-where)] % 2} { _err WHERE "-where needs column/text pairs" }
    if {$o(-mode) eq "regexp"} {
        foreach re [list $query {*}[dict values $o(-where)]] {
            if {[catch {regexp -- $re ""} msg]} { _err REGEXP "bad regular expression: $msg" }
        }
    }
    set where {}
    foreach {c text} $o(-where) {
        if {$text ne ""} { lappend where [_column $tbl $c] $text }
    }
    clear $tbl
    if {$query eq "" && ![llength $where] && $o(-command) eq ""} {
        return [llength [lmap k [$tbl getfullkeys 0 end] {
            if {[$tbl rowcget $k -hide]} continue; set k }]]
    }
    set cols $o(-columns)
    if {![llength $cols]} {
        for {set c 0} {$c < [$tbl columncount]} {incr c} {
            if {![$tbl columncget $c -hide]} { lappend cols $c }
        }
    }
    # Rows hidden before the filter are not ours to show or count.
    set keys {}
    foreach k [$tbl getfullkeys 0 end] {
        if {![$tbl rowcget $k -hide]} { lappend keys $k }
    }
    set keep [dict create]
    set n 0
    foreach k $keys {
        set row [$tbl getformatted $k]
        set hit 1
        if {$query ne ""} {
            set hit 0
            foreach c $cols {
                if {[_match $o(-mode) $o(-nocase) $query [lindex $row $c]]} { set hit 1; break }
            }
        }
        foreach {c text} $where {
            if {!$hit} break
            set hit [_match $o(-mode) $o(-nocase) $text [lindex $row $c]]
        }
        if {$hit && $o(-command) ne ""} {
            set hit [uplevel #0 [list {*}$o(-command) $tbl $k [$tbl get $k]]]
        }
        if {$hit} {
            incr n
            dict set keep $k 1
            # ancestors of a match stay visible
            set p [$tbl parentkey $k]
            while {$p ne "root" && ![dict exists $keep $p]} {
                dict set keep $p 1
                set p [$tbl parentkey $p]
            }
        }
    }
    set hide {}
    foreach k $keys {
        if {![dict exists $keep $k]} { lappend hide $k -hide 1 }
    }
    if {[llength $hide]} { $tbl configrowlist $hide }
    set state($tbl,hidden) [lmap {k - -} $hide {set k}]
    set state($tbl,query)  $query
    if {![string match *tkutlfilter* [bind $tbl <Destroy>]]} {
        bind $tbl <Destroy> +[list ::tkutils::tkutlfilter::_forget $tbl]
    }
    return $n
}

# Column index from an index, a column -name or a title.
proc ::tkutils::tkutlfilter::_column {tbl c} {
    if {[string is integer -strict $c] && $c >= 0 && $c < [$tbl columncount]} { return $c }
    if {![catch {$tbl columnindex $c} i] && $i >= 0 && $i < [$tbl columncount]} { return $i }
    for {set i 0} {$i < [$tbl columncount]} {incr i} {
        if {[$tbl columncget $i -title] eq $c} { return $i }
    }
    _err COLUMN "unknown column \"$c\""
}

proc ::tkutils::tkutlfilter::_forget {tbl} {
    variable state
    array unset state $tbl,*
    after cancel [list ::tkutils::tkutlfilter::_fire $tbl]
}

# Show again every row the filter hid (rows deleted meanwhile are skipped).
proc ::tkutils::tkutlfilter::clear {tbl} {
    variable state
    if {[info exists state($tbl,hidden)]} {
        set show {}
        foreach k $state($tbl,hidden) {
            set i -1
            catch {set i [$tbl index $k]}
            if {$i >= 0 && $i < [$tbl size]} { lappend show $k -hide 0 }
        }
        if {[llength $show]} { $tbl configrowlist $show }
    }
    array unset state $tbl,hidden
    array unset state $tbl,query
    return
}

proc ::tkutils::tkutlfilter::query {tbl} {
    variable state
    if {[info exists state($tbl,query)]} { return $state($tbl,query) }
    return ""
}

# Filter after ms milliseconds of quiet (for <KeyRelease> on an entry);
# sends <<TkutlFilterApplied>> to tbl afterwards.
proc ::tkutils::tkutlfilter::later {tbl ms query args} {
    variable state
    if {[info exists state($tbl,job)]} { after cancel $state($tbl,job) }
    set state($tbl,job) [after $ms [list ::tkutils::tkutlfilter::_fire $tbl $query {*}$args]]
    return
}

proc ::tkutils::tkutlfilter::_fire {tbl query args} {
    variable state
    unset -nocomplain state($tbl,job)
    if {![winfo exists $tbl]} return
    filter $tbl $query {*}$args
    event generate $tbl <<TkutlFilterApplied>>
}

package provide tkutils::tkutlfilter 0.1
