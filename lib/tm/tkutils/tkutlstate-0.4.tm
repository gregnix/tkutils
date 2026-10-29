# tkutils::tkutlstate -- save and restore a tablelist's column layout: widths,
# Description: save and restore a tablelist's column layout: widths, hidden state, display order and the active sort.
# Category: Tk · tablelist
# hidden state, display order and the active sort. Lets an application persist
# how the user arranged a table between sessions. Library-neutral.
#
# API:
#   tkutils::tkutlstate::save            tbl                 -> state dict
#   tkutils::tkutlstate::restore         tbl state
#   tkutils::tkutlstate::saveToFile      tbl path
#   tkutils::tkutlstate::restoreFromFile tbl path            -> 1 if applied
#   tkutils::tkutlstate::saveVia    tbl key setPrefix        ;# {*}$setPrefix key dict
#   tkutils::tkutlstate::restoreVia tbl key getPrefix        -> 1 if applied
#   tkutils::tkutlstate::autosave   tbl key setPrefix ?-delay ms?
#   tkutils::tkutlstate::cancelAutosave tbl
#
# saveVia/restoreVia are storage-neutral: the caller injects get/set command
# prefixes, so the same module works against a DB settings table, a file, an
# array, etc. E.g. with  settingSet db key value  /  settingGet db key :
#   tkutlstate::autosave   $tbl ov [list ::app::store::settingSet $db]
#   tkutlstate::restoreVia $tbl ov [list ::app::store::settingGet $db]
# autosave persists (debounced) whenever the user resizes or reorders columns.
#
# The state is a plain Tcl dict (safe to store as text / in JSON / a config).
#
# Columns are identified by their -name (or "#" + title when unnamed), so a
# state still fits after columns were moved: restore puts them back into the
# saved order with movecolumn and applies width/hide to the right column. The
# sort is saved as the full sortcolumnlist/sortorderlist (multi-column sorts).
# States written by tkutlstate 0.3 (version 1, index based) are still read.
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
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
namespace eval ::tkutils::tkutlstate {
    namespace export save restore saveToFile restoreFromFile \
                     saveVia restoreVia autosave cancelAutosave lastError
    variable after;   array set after   {}
    variable enabled; array set enabled {}
    variable onerror;   array set onerror   {}
    variable lastError; array set lastError {}
}

proc ::tkutils::tkutlstate::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLSTATE $reason] $msg
}

# Column identifier: -name, else "#title".
proc ::tkutils::tkutlstate::_colId {tbl c} {
    set n ""; catch {set n [$tbl columncget $c -name]}
    if {$n ne ""} { return $n }
    set t ""; catch {set t [$tbl columncget $c -title]}
    return "#$t"
}

# Current column index for an identifier, or -1.
proc ::tkutils::tkutlstate::_findCol {tbl id} {
    for {set c 0} {$c < [$tbl columncount]} {incr c} {
        if {[_colId $tbl $c] eq $id} { return $c }
    }
    return -1
}

# Capture the current column layout as a dict.
proc ::tkutils::tkutlstate::save {tbl} {
    set n [$tbl columncount]
    set cols {}
    for {set c 0} {$c < $n} {incr c} {
        set w 0; catch {set w [$tbl columncget $c -width]}
        set h 0; catch {set h [$tbl columncget $c -hide]}
        lappend cols [dict create id [_colId $tbl $c] width $w hide $h]
    }
    set d [dict create version 2 ncols $n columns $cols]
    set ids {}
    foreach c [$tbl sortcolumnlist] { lappend ids [_colId $tbl $c] }
    dict set d sort [dict create columns $ids orders [$tbl sortorderlist]]
    return $d
}

# Apply a previously saved state. Columns that no longer exist are skipped,
# new columns are left untouched, so it degrades gracefully if the table
# changed.
proc ::tkutils::tkutlstate::restore {tbl state} {
    if {[catch {dict exists $state ncols}] || ![dict exists $state ncols]
            || ![dict exists $state columns]} {
        _err STATE "not a tkutlstate dict"
    }
    set version 1
    if {[dict exists $state version]} { set version [dict get $state version] }
    if {$version < 2} { return [_restoreV1 $tbl $state] }

    # 1. order: bring each saved column to its saved position
    set pos 0
    foreach cd [dict get $state columns] {
        set c [_findCol $tbl [dict get $cd id]]
        if {$c < 0} continue
        if {$c != $pos} { $tbl movecolumn $c $pos }
        incr pos
    }
    # 2. width and hidden state, by identifier
    foreach cd [dict get $state columns] {
        set c [_findCol $tbl [dict get $cd id]]
        if {$c < 0} continue
        catch {$tbl columnconfigure $c -width [dict get $cd width]}
        catch {$tbl columnconfigure $c -hide  [dict get $cd hide]}
    }
    # 3. sort (possibly by several columns)
    if {[dict exists $state sort columns]} {
        set cols {}; set orders {}
        foreach id [dict get $state sort columns] o [dict get $state sort orders] {
            set c [_findCol $tbl $id]
            if {$c < 0} break
            lappend cols $c; lappend orders $o
        }
        if {[llength $cols]} { catch {$tbl sortbycolumnlist $cols $orders} }
    }
    return $tbl
}

# Version 1 states (tkutlstate 0.3): plain column indices, single sort column.
proc ::tkutils::tkutlstate::_restoreV1 {tbl state} {
    set n     [$tbl columncount]
    set saved [dict get $state ncols]
    set cols  [dict get $state columns]
    set lim   [expr {min($n, $saved)}]
    for {set c 0} {$c < $lim} {incr c} {
        set cd [lindex $cols $c]
        catch {$tbl columnconfigure $c -width [dict get $cd width]}
        catch {$tbl columnconfigure $c -hide  [dict get $cd hide]}
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

# -------- storage-neutral save/restore via injected command prefixes --------

# Capture and hand the state dict to the caller's setter: {*}$setPrefix key dict.
proc ::tkutils::tkutlstate::saveVia {tbl key setPrefix} {
    set d [save $tbl]
    uplevel #0 [list {*}$setPrefix $key $d]
    return $d
}

# Fetch a state via {*}$getPrefix key and apply it. Missing/empty/garbage -> 0.
proc ::tkutils::tkutlstate::restoreVia {tbl key getPrefix} {
    set d ""
    catch {set d [uplevel #0 [list {*}$getPrefix $key]]}
    if {[string trim $d] eq ""} { return 0 }
    if {[catch {restore $tbl [string trim $d]}]} { return 0 }
    return 1
}

# -------- debounced autosave --------

# Persist automatically (debounced) whenever the user resizes, moves, hides or
# sorts columns. Uses "+" so existing bindings on those events are left intact.
# A failed save is not silent: the table gets <<TkutlStateSaveFailed>>
# (event data: the message), -onerror CMD is called with the table and the
# message, and lastError returns it until the next good save.
proc ::tkutils::tkutlstate::autosave {tbl key setPrefix args} {
    variable enabled
    variable onerror
    set delay 400
    set onerror($tbl) ""
    foreach {o v} $args {
        switch -- $o {
            -delay   { set delay $v }
            -onerror { set onerror($tbl) $v }
            default { _err badoption "unknown option \"$o\"" }
        }
    }
    set enabled($tbl) 1
    foreach ev {<<TablelistColumnResized>> <<TablelistColumnMoved>>
                <<TablelistColHiddenStateChanged>> <<TablelistColumnSorted>>
                <<TablelistColumnsSorted>>} {
        bind $tbl $ev \
            +[list ::tkutils::tkutlstate::_schedule $tbl $key $setPrefix $delay]
    }
    bind $tbl <Destroy> +[list ::tkutils::tkutlstate::_onDestroy $tbl]
    return
}

# Stop autosaving for a widget without disturbing other bindings.
proc ::tkutils::tkutlstate::cancelAutosave {tbl} {
    variable enabled
    variable after
    set enabled($tbl) 0
    if {[info exists after($tbl)]} { catch {::after cancel $after($tbl)}; unset after($tbl) }
    return
}

proc ::tkutils::tkutlstate::_schedule {tbl key setPrefix delay} {
    variable enabled
    variable after
    if {![info exists enabled($tbl)] || !$enabled($tbl)} return
    if {[info exists after($tbl)]} { catch {::after cancel $after($tbl)} }
    set after($tbl) [::after $delay \
        [list ::tkutils::tkutlstate::_fire $tbl $key $setPrefix]]
}

proc ::tkutils::tkutlstate::_fire {tbl key setPrefix} {
    variable after
    variable onerror
    variable lastError
    unset -nocomplain after($tbl)
    if {![winfo exists $tbl]} return
    if {[catch {saveVia $tbl $key $setPrefix} msg]} {
        set lastError($tbl) $msg
        catch {event generate $tbl <<TkutlStateSaveFailed>> -data $msg}
        if {[info exists onerror($tbl)] && $onerror($tbl) ne ""} {
            if {[catch {uplevel #0 [list {*}$onerror($tbl) $tbl $msg]} m2]} {
                bgerror $m2
            }
        }
        return
    }
    set lastError($tbl) ""
}

# The message of the last failed autosave of tbl, "" after a good one.
proc ::tkutils::tkutlstate::lastError {tbl} {
    variable lastError
    if {[info exists lastError($tbl)]} { return $lastError($tbl) }
    return ""
}

proc ::tkutils::tkutlstate::_onDestroy {tbl} {
    variable enabled
    variable after
    if {[info exists after($tbl)]} { catch {::after cancel $after($tbl)} }
    unset -nocomplain after($tbl)
    unset -nocomplain enabled($tbl)
    variable onerror
    variable lastError
    unset -nocomplain onerror($tbl) lastError($tbl)
}

package provide tkutils::tkutlstate 0.4
