#!/usr/bin/env wish
# sqlite-editor.tcl -- launcher for the SQLite variant of the editor family.
#
# Thin entry point: locate tclutils/tkutils, load the shared core and the
# SQLite backend, then build the GUI. The PostgreSQL and Oracle editors are
# identical launchers that source be-postgres.tcl / be-oracle.tcl instead.
#
#   wish sqlite-editor.tcl ?database-file?

package require Tcl 8.6-

# --- locate tkutils / tclutils via the shared bootstrap ---
source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]

set ::sqledit_dir [file dirname [file normalize [info script]]]
source [file join $::sqledit_dir sqledit-core.tcl]
source [file join $::sqledit_dir be-sqlite.tcl]
source [file join $::sqledit_dir sqledit-form.tcl]
source [file join $::sqledit_dir sqledit-sheet.tcl]

# --- main --------------------------------------------------------------------
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    ::sqledit::requireDeps
    ::sqledit::buildApp .
    wm geometry . 900x600
    if {[llength $argv]} { ::sqledit::_connectTo [lindex $argv 0] }
}
