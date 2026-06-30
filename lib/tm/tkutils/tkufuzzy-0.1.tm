# tkutils::tkufuzzy -- incremental fuzzy filter
# Description: incremental fuzzy filter
# Category: Tk · widgets
#
# Tk front-end on top of the tclutils fuzzy engine (tufuzzy). An entry field
# filters a list of items as you type: items are kept when the pattern is a
# subsequence of them, and ranked by similarity. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tufuzzy 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkufuzzy {
    namespace export widget setItems filter getMatches getSelection
    variable state
}

proc ::tkutils::tkufuzzy::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the filter widget under $path. Option: -height N (visible rows).
proc ::tkutils::tkufuzzy::widget {path args} {
    variable state
    array set opts {-height 12}
    array set opts $args

    ttk::frame $path
    set state($path,items) {}
    set state($path,matches) {}
    bind $path <Destroy> [list ::tkutils::tkufuzzy::_cleanup $path %W]

    ttk::entry $path.e
    listbox $path.lb -height $opts(-height) -activestyle dotbox \
        -yscrollcommand [list $path.ys set]
    ttk::scrollbar $path.ys -orient vertical -command [list $path.lb yview]
    grid $path.e  -      -sticky ew -padx 2 -pady 2
    grid $path.lb $path.ys -sticky nsew
    grid rowconfigure $path 1 -weight 1
    grid columnconfigure $path 0 -weight 1

    bind $path.e <KeyRelease> [list ::tkutils::tkufuzzy::_onType $path]
    return $path
}

proc ::tkutils::tkufuzzy::_onType {path} {
    filter $path [$path.e get]
}

# Set the list of items. Re-applies the current filter.
proc ::tkutils::tkufuzzy::setItems {path items} {
    variable state
    set state($path,items) $items
    filter $path [$path.e get]
    return [llength $items]
}

# Filter by $pattern. Returns the ranked list of matches and updates the list.
# An empty pattern shows all items in their original order.
proc ::tkutils::tkufuzzy::filter {path pattern} {
    variable state
    set items $state($path,items)
    if {$pattern eq ""} {
        set ranked $items
    } else {
        set scored {}
        set i 0
        foreach it $items {
            if {[::tclutils::tufuzzy::subsequence $pattern $it]} {
                lappend scored [list $it [::tclutils::tufuzzy::similarity $pattern $it] $i]
            }
            incr i
        }
        set ranked {}
        foreach pair [lsort -command ::tkutils::tkufuzzy::_cmp $scored] {
            lappend ranked [lindex $pair 0]
        }
    }
    set state($path,matches) $ranked
    $path.lb delete 0 end
    foreach it $ranked { $path.lb insert end $it }
    return $ranked
}

# sort by score descending, then original index ascending (stable, deterministic)
proc ::tkutils::tkufuzzy::_cmp {a b} {
    set sa [lindex $a 1]
    set sb [lindex $b 1]
    if {$sa > $sb} { return -1 }
    if {$sa < $sb} { return 1 }
    return [expr {[lindex $a 2] - [lindex $b 2]}]
}

# Return the current list of matches.
proc ::tkutils::tkufuzzy::getMatches {path} {
    variable state
    return $state($path,matches)
}

# Return the selected item, or "".
proc ::tkutils::tkufuzzy::getSelection {path} {
    set sel [$path.lb curselection]
    if {$sel eq ""} { return "" }
    return [$path.lb get [lindex $sel 0]]
}

package provide tkutils::tkufuzzy 0.1
