#!/usr/bin/env wish
# postgresql-editor.tcl -- launcher for the PostgreSQL variant of the editor
# family. Identical to sqlite-editor.tcl, but loads be-postgres.tcl.
#
# The shared GUI (sqledit-core / sqledit-form / sqledit-sheet) lives in the
# sibling sqlite-editor/ directory and is reused unchanged -- only the backend
# differs. This backend talks to PostgreSQL directly via tdbc::postgres
# (a small SQL editor), which is a different layer than the REST client
# tclutils::tupostgrest used by applications.
#
#   wish postgresql-editor.tcl
#
package require Tcl 8.6-

# --- locate tkutils / tclutils via the shared bootstrap ---
source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]

set ::pgedit_dir  [file dirname [file normalize [info script]]]
# Der geteilte Kern liegt in _lib/sqledit (Trennung vom 2026-09-11).
set ::sqledit_dir [file normalize [file join $::pgedit_dir .. _lib sqledit]]

source [file join $::sqledit_dir sqledit-core.tcl]
# sqledit-conn.tcl (shared connection-profile store) is optional: source it
# only when present, so the editor also starts without it.
set ::_connFile [file join $::sqledit_dir sqledit-conn.tcl]
if {[file exists $::_connFile]} { source $::_connFile }
source [file join $::pgedit_dir  be-postgres.tcl]
source [file join $::sqledit_dir sqledit-form.tcl]
# Zuletzt geoeffnete Datenbanken -- optional wie sqledit-conn.tcl:
# fehlt die Datei, startet der Editor, und das Menue zeigt den Eintrag
# nicht.
set ::_recentFile [file join $::sqledit_dir sqledit-recent.tcl]
if {[file exists $::_recentFile]} { source $::_recentFile }
source [file join $::sqledit_dir sqledit-sheet.tcl]

# --- main --------------------------------------------------------------------
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    ::sqledit::requireDeps
    ::sqledit::buildApp .
    wm geometry . 900x600
    wm title . "PostgreSQL Editor"
}
