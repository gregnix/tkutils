#!/usr/bin/env wish
# oracle-editor.tcl -- launcher for the Oracle variant of the editor family.
# Like postgresql-editor.tcl, but loads be-oracle.tcl (Oratcl) and first runs
# the Instant-Client bootstrap.
#
# The shared GUI (sqledit-core / sqledit-form / sqledit-sheet) lives in the
# sibling sqlite-editor/ directory and is reused unchanged -- only the backend
# differs. This backend talks to Oracle directly via Oratcl (the OCI binding),
# following the conventions of the "Oracle und Oratcl" handbook chapter.
#
#   wish  oracle-editor.tcl            # start the editor
#   tclsh oracle-editor.tcl --check    # print Instant-Client / Oratcl diagnostics
#
package require Tcl 8.6-

# --- locate tkutils / tclutils via the shared bootstrap ---
source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]

set ::oraedit_dir [file dirname [file normalize [info script]]]
set ::sqledit_dir [file normalize [file join $::oraedit_dir .. sqlite-editor]]

# --- Oracle Instant-Client bootstrap (must run before Oratcl is loaded) ---
source [file join $::oraedit_dir oratcl-bootstrap.tcl]
::sqledit::oratcl::setupEnv

# --check: diagnostics only, no GUI, no DB connection needed ------------------
if {[lindex $argv 0] eq "--check"} {
    set haveOra [expr {![catch {package require Oratcl} oraVer]}]
    puts "Oracle Editor -- environment check"
    puts "----------------------------------"
    foreach line [::sqledit::oratcl::diagInfo] { puts "  $line" }
    set ic [::sqledit::oratcl::detectInstantClient]
    puts "  detected instant client: [expr {$ic eq "" ? "(none found)" : $ic}]"
    puts "  Oratcl: [expr {$haveOra ? "loaded ($oraVer)" : "NOT loadable -- $oraVer"}]"
    exit [expr {$haveOra ? 0 : 1}]
}

source [file join $::sqledit_dir sqledit-core.tcl]
source [file join $::sqledit_dir sqledit-conn.tcl]
source [file join $::oraedit_dir  be-oracle.tcl]
source [file join $::sqledit_dir sqledit-form.tcl]
source [file join $::sqledit_dir sqledit-sheet.tcl]

# --- main --------------------------------------------------------------------
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    ::sqledit::requireDeps
    ::sqledit::buildApp .
    wm geometry . 900x600
    wm title . "Oracle Editor"
}
