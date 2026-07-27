#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require Tk
package require tkutils::tkulauncher

# A cross-platform launcher demo, driven by a real config FILE so the built-in
# Settings group is shown and works:
#
#   Edit menu...        opens the config file in your editor
#   Open file location  opens the folder it lives in
#   Reload              re-reads the file and rebuilds -- no restart
#
# Edit the file, then click Reload to see the menu change. Clicking an entry
# really launches it (a URL opens your browser, a folder opens your file
# manager, an app runs). The status line reports what was launched.

wm title . "tkulauncher demo"
wm geometry . 420x500

# Write a sample config next to this script on first run (so there is something
# to edit). Delete it to get a fresh one.
set cfg [file join $here tkulauncher-demo.json]
if {![file exists $cfg]} {
    set ch [open $cfg w] ; fconfigure $ch -encoding utf-8
    puts $ch {{
  "items": [
    { "type": "menu", "label": "Internet", "items": [
        { "type": "url", "label": "Tcl/Tk 9 Manual", "target": "https://www.tcl.tk/man/tcl9.0/" },
        { "type": "url", "label": "Tcl Wiki", "target": "https://wiki.tcl-lang.org/" }
    ]},
    { "type": "menu", "label": "Programs", "items": [
        { "type": "app", "label": "Firefox", "cmd": ["firefox"] },
        { "type": "app", "label": "Terminal", "cmd": ["xterm"] }
    ]},
    { "type": "separator" },
    { "type": "open", "label": "Home folder", "target": "~" }
  ]
}}
    close $ch
}

set ::log "Try Start > Settings > Edit menu..., change it, then Reload."
proc report {kind argv} {
    set ::log "launched ($kind): $argv"
    return 1   ;# allow the real launch (return 0 would suppress it)
}

# -file + -settings 1  ->  the Settings group (Edit menu.../Open location/Reload)
# is appended automatically, in BOTH modes.

ttk::label .top -text "Start menu (menu mode) -- open it, see System + Settings at the bottom:" \
    -anchor w -wraplength 400
::tkutils::tkulauncher::widget .start -mode menu -text Start \
    -file $cfg -settings 1 -system 1 -onlaunch report

ttk::separator .s1 -orient horizontal
ttk::label .mid -text "Launcher panel (list mode) -- System + Settings sections:" \
    -anchor w -wraplength 400
::tkutils::tkulauncher::widget .panel -mode list \
    -file $cfg -settings 1 -system 1 -onlaunch report

ttk::separator .s2 -orient horizontal
ttk::label .cfg -text "config: $cfg" -anchor w -wraplength 400 -foreground "#555555"
ttk::label .status -textvariable ::log -anchor w -wraplength 400 -foreground "#1565c0"

grid .top    -sticky ew  -padx 8 -pady {8 2}
grid .start  -sticky w   -padx 8
grid .s1     -sticky ew  -padx 8 -pady 8
grid .mid    -sticky ew  -padx 8
grid .panel  -sticky ew  -padx 8 -pady 2
grid .s2     -sticky ew  -padx 8 -pady 8
grid .cfg    -sticky ew  -padx 8
grid .status -sticky ew  -padx 8 -pady {2 8}
grid columnconfigure . 0 -weight 1
grid rowconfigure . 4 -weight 1
