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
set ::sqledit_dir [file normalize [file join $::pgedit_dir .. sqlite-editor]]

source [file join $::sqledit_dir sqledit-core.tcl]
source [file join $::pgedit_dir  be-postgres.tcl]
source [file join $::sqledit_dir sqledit-form.tcl]
source [file join $::sqledit_dir sqledit-sheet.tcl]

# --- main --------------------------------------------------------------------
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    ::sqledit::requireDeps
    ::sqledit::buildApp .
    wm geometry . 900x600
    wm title . "PostgreSQL Editor"
}
