#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require Tk
package require tkutils::tkulauncher

# Cross-platform launcher demo. Shows both shapes:
#   * a Start menu (menu mode) -- long menus scroll natively / use submenus
#   * a launcher panel (list mode) with -scroll, so a long list gets a scrollbar
#
# It is driven by a config FILE, so the Settings group (Edit menu.../Open file
# location/Reload) works, and -system 1 adds the environment-aware System tools.
# Clicking an entry really launches it; the status line reports what ran.

wm title . "tkulauncher demo"
wm geometry . 460x560

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

set ::log "Scroll the panel on the right. Try Settings > Edit menu..., then Reload."
proc report {kind argv} { set ::log "launched ($kind): $argv" ; return 1 }

# ---- left: menu mode ----
ttk::frame .left
ttk::label .left.t -text "Start menu\n(menu mode)" -anchor w -justify left
::tkutils::tkulauncher::widget .left.start -mode menu -text Start \
    -file $cfg -settings 1 -system 1 -onlaunch report
pack .left.t -side top -anchor w -padx 6 -pady {6 2}
pack .left.start -side top -anchor w -padx 6

# ---- right: SCROLLABLE list mode ----
# Many entries here (all the environment system tools, plus the config), so the
# column is clearly longer than -height and the scrollbar shows.
ttk::frame .right
ttk::label .right.t -text "Panel (list mode, -columns 2)\nonly a few important entries -> compact 2-column (right-click to edit):" \
    -anchor w -justify left
# build an explicit long spec so the scrollbar is always visible in the demo
# The panel is file-backed too, so edits made through the editor persist. We
# write a starter config once from a spec, then the launcher loads from it and
# "Save to file..." writes back to the same place.
set pcfg [file join $here tkulauncher-panel.json]
if {![file exists $pcfg]} {
    set panelspec {
        {type menu label "Important" items {
            {type system id terminal}    {type system id filemanager}
            {type system id taskmanager} {type system id settings}
            {type system id printers}    {type system id printjobs}
            {type system id systeminfo}  {type system id screenshot}
        }}
        {type separator}
        {type calc}
        {type calendar}
        {type open label "Home" target ~}
        {type open label "This dir" target .}
    }
    ::tkutils::tkulauncher::saveEntries $panelspec $pcfg
}
::tkutils::tkulauncher::widget .right.panel -mode list \
    -file $pcfg -columns 2 -tooltips 1 -editable 1 -onlaunch report
pack .right.t -side top -anchor w -padx 6 -pady {6 2}
pack .right.panel -side top -fill both -expand 1 -padx 6

ttk::separator .sep -orient vertical
ttk::label .cfg -text "config: $cfg" -anchor w -wraplength 440 -foreground "#555555"
ttk::label .status -textvariable ::log -anchor w -wraplength 440 -foreground "#1565c0"

grid .left   -row 0 -column 0 -sticky nw
grid .sep    -row 0 -column 1 -sticky ns -padx 4
grid .right  -row 0 -column 2 -sticky nsew
grid .cfg    -row 1 -column 0 -columnspan 3 -sticky ew -padx 8 -pady {6 0}
grid .status -row 2 -column 0 -columnspan 3 -sticky ew -padx 8 -pady {2 8}
grid columnconfigure . 2 -weight 1
grid rowconfigure . 0 -weight 1
