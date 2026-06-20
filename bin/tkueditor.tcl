#!/usr/bin/env tclsh
# tkeditor -- small standalone editor app built on tkutils::tkueditor.
# The editor widget provides the toolbar (Open/Save/Undo/Redo/Cut/Copy/Find)
# and the status bar (modified, encoding, line endings, Ln/Col). This launcher
# adds a find/replace bar (replace is not on the toolbar) and the usual
# keyboard accelerators.
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
package require tkutils::tkueditor

wm title . "tkeditor"

set w [::tkutils::tkueditor::widget .ed]
set T $w.t

# ---- find / replace bar -------------------------------------------------
# The widget's toolbar has a quick-find box; this bar adds replace.
ttk::frame .bar -padding 4
ttk::label .bar.lf -text "Find"
ttk::entry .bar.find -width 24
ttk::label .bar.lr -text "Replace"
ttk::entry .bar.repl -width 24
set ::nocase 0
ttk::checkbutton .bar.case -text "Aa" -variable ::nocase
ttk::button .bar.next -text "Next"        -command findCmd
ttk::button .bar.one  -text "Replace"     -command {replaceCmd 0}
ttk::button .bar.all  -text "Replace All" -command {replaceCmd 1}
ttk::button .bar.x    -text "Close"       -command hideBar
grid .bar.lf .bar.find .bar.lr .bar.repl .bar.case .bar.next .bar.one .bar.all .bar.x \
    -sticky w -padx 2

proc flags {} { return [expr {$::nocase ? {-nocase} : {}}] }
proc findCmd {} {
    global w
    set n [.bar.find get]
    if {$n eq ""} return
    set hits [::tkutils::tkueditor::highlightAll $w $n {*}[flags]]
    ::tkutils::tkueditor::findNext $w $n {*}[flags]
    ::tkutils::tkueditor::setStatus $w "$hits match[expr {$hits == 1 ? {} : {es}}]"
    focus .ed.t
}
proc replaceCmd {all} {
    global w
    set n [.bar.find get]
    if {$n eq ""} return
    set opt [flags]
    if {$all} { lappend opt -all }
    set k [::tkutils::tkueditor::replace $w $n [.bar.repl get] {*}$opt]
    ::tkutils::tkueditor::highlightAll $w $n {*}[flags]
    ::tkutils::tkueditor::setStatus $w "$k replaced"
}
proc showBar {} {
    grid .bar -row 0 -column 0 -sticky ew
    focus .bar.find
}
proc hideBar {} {
    global w
    grid remove .bar
    ::tkutils::tkueditor::clearHighlight $w
    focus .ed.t
}
bind .bar.find <Return> findCmd
bind .bar.repl <Return> {replaceCmd 0}
bind .bar <Escape> hideBar
bind .ed.t <Escape> hideBar

# ---- file accelerators --------------------------------------------------
proc doOpen {} {
    global w
    set f [tk_getOpenFile]
    if {$f ne ""} { ::tkutils::tkueditor::loadFile $w $f }
}
proc doSave {} {
    global w
    set f [::tkutils::tkueditor::currentFile $w]
    if {$f eq ""} {
        set f [tk_getSaveFile]
        if {$f eq ""} return
    }
    ::tkutils::tkueditor::saveFile $w $f
}
bind . <Control-o> doOpen
bind . <Control-s> doSave
bind . <Control-f> showBar
bind . <F3>        findCmd

# ---- layout -------------------------------------------------------------
# Row 0 holds the (hidden) find/replace bar; row 1 the editor widget, which
# carries its own toolbar at the top and status bar at the bottom.
grid .ed -row 1 -column 0 -sticky nsew
grid rowconfigure    . 1 -weight 1
grid columnconfigure . 0 -weight 1
grid remove .bar

if {[llength $argv] > 0} { ::tkutils::tkueditor::loadFile $w [lindex $argv 0] }
focus .ed.t
vwait forever
