#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
# locate the tclutils dependency for in-tree/dev use
# (installed systems already have tclutils on the module path)
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
package require Tk
package require tkutils::tkupdfinspect

# Inspect the PDF given on the command line, or a tiny built-in sample so the
# demo shows something out of the box.
proc samplePdf {} {
    set f [file join [file dirname [file normalize [info nameofexecutable]]] sample.pdf]
    set f [file join [pwd] tkupdfinspect-sample.pdf]
    set body "%PDF-1.5\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids \[3 0 R\] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox \[0 0 612 792\] >>\nendobj\n4 0 obj\n<< /Title (Sample PDF) /Author (tkutils) >>\nendobj\ntrailer\n<< /Root 1 0 R /Info 4 0 R >>\n%%EOF\n"
    set ch [open $f wb]; fconfigure $ch -translation binary; puts -nonewline $ch $body; close $ch
    return $f
}

wm title . "tkupdfinspect demo"
set w [::tkutils::tkupdfinspect::widget .w -width 72 -height 26]
pack $w -fill both -expand 1

set pdf [expr {[llength $argv] > 0 ? [lindex $argv 0] : [samplePdf]}]
::tkutils::tkupdfinspect::loadFile $w $pdf

vwait forever
