# tkutils::tkutlstate -- save and restore a tablelist's column layout: widths,
# hidden state, display order and the active sort. Lets an application persist
# how the user arranged a table between sessions. Library-neutral.
#
# API:
#   tkutils::tkutlstate::save            tbl                 -> state dict
#   tkutils::tkutlstate::restore         tbl state
#   tkutils::tkutlstate::saveToFile      tbl path
#   tkutils::tkutlstate::restoreFromFile tbl path            -> 1 if applied
#
# The state is a plain Tcl dict (safe to store as text / in JSON / a config).
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
package require tablelist

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutlstate {
    namespace export save restore saveToFile restoreFromFile
}

proc ::tkutils::tkutlstate::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLSTATE $reason] $msg
}

# Capture the current column layout as a dict.
proc ::tkutils::tkutlstate::save {tbl} {
    set n [$tbl columncount]
    set cols {}
    for {set c 0} {$c < $n} {incr c} {
        set w 0; catch {set w [$tbl columncget $c -width]}
        set h 0; catch {set h [$tbl columncget $c -hide]}
        lappend cols [dict create width $w hide $h]
    }
    set d [dict create version 1 ncols $n columns $cols]
    catch {dict set d columnorder [$tbl cget -columnorder]}
    catch {
        set sc [$tbl sortcolumn]
        dict set d sortcolumn $sc
        if {$sc >= 0} { dict set d sortorder [$tbl sortorder] }
    }
    return $d
}

# Apply a previously saved state. Columns beyond the saved/current count are
# left untouched, so it degrades gracefully if the table changed.
proc ::tkutils::tkutlstate::restore {tbl state} {
    if {![dict exists $state ncols] || ![dict exists $state columns]} {
        _err STATE "not a tkutlstate dict"
    }
    set n     [$tbl columncount]
    set saved [dict get $state ncols]
    set cols  [dict get $state columns]
    set lim   [expr {min($n, $saved)}]
    for {set c 0} {$c < $lim} {incr c} {
        set cd [lindex $cols $c]
        catch {$tbl columnconfigure $c -width [dict get $cd width]}
        catch {$tbl columnconfigure $c -hide  [dict get $cd hide]}
    }
    if {[dict exists $state columnorder]} {
        catch {$tbl configure -columnorder [dict get $state columnorder]}
    }
    if {[dict exists $state sortcolumn]} {
        set sc [dict get $state sortcolumn]
        if {$sc >= 0 && $sc < $n} {
            set so increasing
            if {[dict exists $state sortorder]} { set so [dict get $state sortorder] }
            catch {$tbl sortbycolumn $sc -$so}
        }
    }
    return $tbl
}

# Persist the state to a file (the dict as text).
proc ::tkutils::tkutlstate::saveToFile {tbl path} {
    set d [save $tbl]
    set fh [open $path w]
    try {
        fconfigure $fh -encoding utf-8
        puts -nonewline $fh $d
    } finally {
        close $fh
    }
    return $path
}

# Load and apply a state file. Returns 1 if applied, 0 if the file is missing.
proc ::tkutils::tkutlstate::restoreFromFile {tbl path} {
    if {![file exists $path]} { return 0 }
    set fh [open $path r]
    try {
        fconfigure $fh -encoding utf-8
        set d [read $fh]
    } finally {
        close $fh
    }
    restore $tbl [string trim $d]
    return 1
}

package provide tkutils::tkutlstate 0.1
