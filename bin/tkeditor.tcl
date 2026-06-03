#!/usr/bin/env tclsh
# tkeditor -- small standalone editor app built on tkutils::tkeditor.
# Adds a find/replace bar, a status line (file, modified, line:col) and the
# usual accelerators on top of the editor widget.
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
package require tkutils::tkeditor

wm title . "tkeditor"

set w [::tkutils::tkeditor::widget .ed]
set T $w.t

# ---- status line --------------------------------------------------------
ttk::label .status -anchor w -padding {6 2}
proc refreshStatus {} {
    global w T
    lassign [split [::tkutils::tkeditor::cursor $w] .] ln col
    set f [::tkutils::tkeditor::currentFile $w]
    set name [expr {$f eq "" ? "(unsaved)" : [file tail $f]}]
    set mod [expr {[::tkutils::tkeditor::isModified $w] ? " *" : ""}]
    .status configure -text "$name$mod    Ln [incr ln 0], Col [incr col 1]"
}
bind $T <KeyRelease>    {+refreshStatus}
bind $T <ButtonRelease> {+refreshStatus}

# ---- find / replace bar -------------------------------------------------
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
    ::tkutils::tkeditor::highlightAll $w $n {*}[flags]
    ::tkutils::tkeditor::findNext $w $n {*}[flags]
    focus .ed.t
}
proc replaceCmd {all} {
    global w
    set n [.bar.find get]
    if {$n eq ""} return
    set opt [flags]
    if {$all} { lappend opt -all }
    ::tkutils::tkeditor::replace $w $n [.bar.repl get] {*}$opt
    ::tkutils::tkeditor::highlightAll $w $n {*}[flags]
    refreshStatus
}
proc showBar {} {
    grid .bar -row 0 -column 0 -sticky ew
    focus .bar.find
}
proc hideBar {} {
    global w
    grid remove .bar
    ::tkutils::tkeditor::clearHighlight $w
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
    if {$f ne ""} { ::tkutils::tkeditor::loadFile $w $f; refreshStatus }
}
proc doSave {} {
    global w
    set f [::tkutils::tkeditor::currentFile $w]
    if {$f eq ""} {
        set f [tk_getSaveFile]
        if {$f eq ""} return
    }
    ::tkutils::tkeditor::saveFile $w $f
    refreshStatus
}
bind . <Control-o> doOpen
bind . <Control-s> doSave
bind . <Control-f> showBar
bind . <F3>        findCmd

# ---- layout -------------------------------------------------------------
grid .ed     -row 1 -column 0 -sticky nsew
grid .status -row 2 -column 0 -sticky ew
grid rowconfigure    . 1 -weight 1
grid columnconfigure . 0 -weight 1
grid remove .bar

if {[llength $argv] > 0} { ::tkutils::tkeditor::loadFile $w [lindex $argv 0] }
refreshStatus
focus .ed.t
vwait forever
