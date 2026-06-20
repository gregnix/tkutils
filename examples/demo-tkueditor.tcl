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
package require tkutils::tkueditor

wm title . "tkueditor demo"

# The editor builds its toolbar (Open/Save/Undo/Redo/Cut/Copy/Find) and status
# bar (modified, encoding, line-ending, position) by default.
set w [::tkutils::tkueditor::widget .w -width 80 -height 22]
pack $w -fill both -expand 1

# A menu bar that drives the editor's file, encoding and line-ending API.
set enc [::tkutils::tkueditor::encoding $w]
set eol [::tkutils::tkueditor::eol $w]

proc doOpen {} {
    set fn [tk_getOpenFile]
    if {$fn eq ""} return
    ::tkutils::tkueditor::loadFile .w $fn
    # reflect the file's detected encoding / line endings in the menus
    set ::enc [::tkutils::tkueditor::encoding .w]
    set ::eol [::tkutils::tkueditor::eol .w]
}
proc doSave {{saveAs 0}} {
    set fn [::tkutils::tkueditor::currentFile .w]
    if {$saveAs || $fn eq ""} { set fn [tk_getSaveFile] }
    if {$fn ne ""} { ::tkutils::tkueditor::saveFile .w $fn }
}
proc setEnc {} { ::tkutils::tkueditor::encoding .w $::enc; ::tkutils::tkueditor::refreshStatus .w }
proc setEol {} { ::tkutils::tkueditor::eol .w $::eol;      ::tkutils::tkueditor::refreshStatus .w }

menu .m -tearoff 0
. configure -menu .m

menu .m.file -tearoff 0
.m add cascade -label "File" -menu .m.file
.m.file add command -label "Open..."    -command doOpen
.m.file add command -label "Save"       -command {doSave 0}
.m.file add command -label "Save As..." -command {doSave 1}
.m.file add separator
.m.file add command -label "Quit"       -command {exit}

menu .m.enc -tearoff 0
.m add cascade -label "Encoding" -menu .m.enc
foreach e {utf-8 iso8859-1 cp1252} {
    .m.enc add radiobutton -label $e -variable enc -value $e -command setEnc
}

menu .m.eol -tearoff 0
.m add cascade -label "Line endings" -menu .m.eol
.m.eol add radiobutton -label "LF (Unix)"    -variable eol -value lf   -command setEol
.m.eol add radiobutton -label "CRLF (Windows)" -variable eol -value crlf -command setEol

# A custom context-menu entry, to show the menu is extensible.
::tkutils::tkueditor::addMenuSeparator $w
::tkutils::tkueditor::addMenuItem $w "Upper-case selection" {
    catch {
        set s [.w.t get sel.first sel.last]
        .w.t delete sel.first sel.last
        .w.t insert insert [string toupper $s]
    }
}

::tkutils::tkueditor::setText $w \
"# tkueditor demo\n\nToolbar above, status bar below.\n\nTry it:\n  - Open/Save and the Find box live in the toolbar.\n  - The status bar shows modified, encoding, line endings and Ln/Col.\n  - The Encoding and \"Line endings\" menus drive encoding/eol.\n  - Right-click for the edit menu (plus \"Upper-case selection\").\n  - Umlauts round-trip as utf-8: Gr\u00f6\u00dfe, Tsch\u00fc\u00df.\n"
::tkutils::tkueditor::setStatus $w "Ready"

vwait forever
