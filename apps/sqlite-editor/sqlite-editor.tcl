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

# DER GETEILTE KERN LIEGT IN _lib/sqledit, NICHT HIER.
#
# Bis 2026-09-11 lag er in diesem Verzeichnis, und die drei anderen
# Editoren holten ihn ueber "[file join .. sqlite-editor]". Damit war
# eine Anwendung zugleich die Bibliothek der anderen: wer sie umbenannte
# oder verschob, brach drei Editoren -- mit der Meldung "couldn't read
# file" und ohne Hinweis auf den Grund.
#
# Jetzt holt ihn jeder von derselben Stelle, und dieses Verzeichnis
# enthaelt nur noch, was zu SQLite gehoert.
set ::appdir      [file dirname [file normalize [info script]]]
set ::sqledit_dir [file normalize [file join $::appdir .. _lib sqledit]]
source [file join $::sqledit_dir sqledit-core.tcl]
# Das Backend gehoert zur ANWENDUNG, nicht zum Kern -- also aus
# $::appdir, nicht aus $::sqledit_dir. Die anderen drei Editoren halten
# es seit jeher so.
source [file join $::appdir be-sqlite.tcl]
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
    if {[llength $argv]} { ::sqledit::_connectTo [lindex $argv 0] }
}
