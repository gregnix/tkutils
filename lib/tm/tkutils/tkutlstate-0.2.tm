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
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
package require tablelist

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutlstate {
    namespace export save restore saveToFile restoreFromFile \
                     saveVia restoreVia autosave cancelAutosave
    variable after;   array set after   {}
    variable enabled; array set enabled {}
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

# Persist automatically (debounced) whenever the user resizes or reorders a
# column. Uses "+" so existing bindings on those events are left intact.
proc ::tkutils::tkutlstate::autosave {tbl key setPrefix args} {
    variable enabled
    set delay 400
    foreach {o v} $args {
        switch -- $o {
            -delay  { set delay $v }
            default { _err badoption "unknown option \"$o\"" }
        }
    }
    set enabled($tbl) 1
    foreach ev {<<TablelistColumnResized>> <<TablelistColumnMoved>>} {
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
    unset -nocomplain after($tbl)
    if {![winfo exists $tbl]} return
    catch {saveVia $tbl $key $setPrefix}
}

proc ::tkutils::tkutlstate::_onDestroy {tbl} {
    variable enabled
    variable after
    if {[info exists after($tbl)]} { catch {::after cancel $after($tbl)} }
    unset -nocomplain after($tbl)
    unset -nocomplain enabled($tbl)
}

package provide tkutils::tkutlstate 0.2
