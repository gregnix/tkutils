#!/usr/bin/env wish
# launcher.tcl -- a standalone start menu / launcher panel.
#
# A small but complete application built on the tkutils tkulauncher widget: a
# "Start" menu button plus a two-column launcher panel, both loaded from a JSON
# config file and editable in place. A menu bar (File / Edit) gives direct
# access to editing and to the suggestion catalogue, so a first-time user who is
# not sure what to put in a menu can just pick from a list. Built-in calendar,
# calculator, system and Tcl-script entries are available too, so it runs
# without external helper programs.
#
# Running:
#     wish launcher.tcl ?config.json?
#
# With no argument it uses (and creates on first run) a per-user config at
#     $XDG_CONFIG_HOME/tkulauncher/menu.json    (Unix)
#     %APPDATA%/tkulauncher/menu.json           (Windows)
#
# The command procs are separated from the GUI so a headless smoke test can
# exercise the app logic; the window is only built when this is the main script.
# When packed into a zipfs image main.tcl sources this file.

package require Tcl 8.6-

# --- locate tkutils / tclutils ---------------------------------------------
set _boot [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]
if {[file exists $_boot]} { source $_boot }

# When packaged as a standalone image, external pkgIndex packages (scrollutil,
# Tablelist, tical) may be bundled next to the app; add them to the auto_path.
namespace eval ::launcherapp {}
proc ::launcherapp::addBundledPkgs {} {
    set here [file dirname [file normalize [info script]]]
    set roots {}
    foreach up {. .. ../.. ../../.. ../../../..} {
        lappend roots [file join $here $up pkgs]
    }
    if {![catch {zipfs root} zr]} {
        lappend roots [file join $zr pkgs]
        if {[string match "${zr}*" $here]} {
            set rest [string range $here [string length $zr] end]
            set mnt [lindex [file split $rest] 0]
            if {$mnt ne ""} { lappend roots [file join $zr $mnt pkgs] }
        }
    }
    foreach cand $roots {
        if {[file isdirectory $cand]} {
            foreach d [glob -nocomplain -directory $cand *] {
                if {[file isdirectory $d] && [lsearch -exact $::auto_path $d] < 0} {
                    lappend ::auto_path $d
                }
            }
        }
    }
}
::launcherapp::addBundledPkgs

namespace eval ::launcherapp {
    variable S
    array set S {config "" win "" start "" status ""}
}

# ---- config location -------------------------------------------------------
proc ::launcherapp::defaultConfig {} {
    if {$::tcl_platform(platform) eq "windows" && [info exists ::env(APPDATA)]} {
        set base [file join $::env(APPDATA) tkulauncher]
    } elseif {[info exists ::env(XDG_CONFIG_HOME)] && $::env(XDG_CONFIG_HOME) ne ""} {
        set base [file join $::env(XDG_CONFIG_HOME) tkulauncher]
    } elseif {[info exists ::env(HOME)]} {
        set base [file join $::env(HOME) .config tkulauncher]
    } else {
        set base [file join [pwd] .tkulauncher]
    }
    return [file join $base menu.json]
}

# ---- the other tkutils apps -----------------------------------------------
# The apps next to this one (tkutils/apps/<folder>/<script>), started with the
# wish of the running interpreter (interpreter "current"). Only those whose
# script exists are offered -- inside a packaged launcher there are none.
# build-app (tclutils) is not here: it is a command-line tool without a window.
namespace eval ::launcherapp {
    variable appCatalog {
        "Address book"        adressbuch          adressbuch.tcl
        "CSV editor"          csv-editor          csv_editor.tcl
        "Knowledge base"      knowledge           knowledge-base.tcl
        "Notes"               notes-app           notes_app.tcl
        "SQLite editor"       sqlite-editor       sqlite-editor.tcl
        "SQLite editor (TDBC)" tdbc-sqlite-editor tdbc-sqlite-editor.tcl
        "PostgreSQL editor"   postgresql-editor   postgresql-editor.tcl
        "Oracle editor"       oracle-editor       oracle-editor.tcl
        "Search and replace"  search-replace-tool search_replace_tool.tcl
        "Developer toolbox"   tkdevtools          tkdevtools.tcl
        "GUI designer"        tkudesigner         tkudesigner.tcl
    }
}

# The apps folder: the parent of this app's folder.
proc ::launcherapp::appsDir {} {
    return [file dirname [file dirname [file normalize [info script]]]]
}
# remember it while sourcing: [info script] is empty later
set ::launcherapp::appsDirAtLoad [::launcherapp::appsDir]

# Entries for the apps that exist, as a spec list.
proc ::launcherapp::appEntries {{dir ""}} {
    variable appCatalog
    if {$dir eq ""} { set dir $::launcherapp::appsDirAtLoad }
    set out {}
    foreach {label folder script} $appCatalog {
        set f [file join $dir $folder $script]
        if {[file isfile $f]} {
            lappend out [dict create type tcl label $label target $f interp current]
        }
    }
    return $out
}

# Put the apps into the menu as the submenu "Apps": replace it when there is
# one, else add it before the first separator (or at the end). Returns the
# number of apps. Without an apps list it looks for them (appEntries).
proc ::launcherapp::withApps {items args} {
    set apps [expr {[llength $args] ? [lindex $args 0] : [appEntries]}]
    if {![llength $apps]} { return [list $items 0] }
    set menu [dict create type menu label Apps items $apps]
    set i 0
    foreach e $items {
        if {[dict get $e type] eq "menu" && [dict exists $e label] && [dict get $e label] eq "Apps"} {
            return [list [lreplace $items $i $i $menu] [llength $apps]]
        }
        incr i
    }
    set at [lsearch -exact [lmap e $items {dict get $e type}] separator]
    if {$at < 0} { set at end }
    return [list [linsert $items $at $menu] [llength $apps]]
}

# Edit > Add tkutils apps: into the config file, then reload.
proc ::launcherapp::doAddApps {} {
    variable S
    set items [::tkutils::tkulauncher::load $S(config)]
    lassign [withApps $items] items n
    if {$n == 0} {
        _status "No tkutils apps found next to the launcher"
        return 0
    }
    ::tkutils::tkulauncher::saveEntries $items $S(config)
    doReload
    _status "Submenu \"Apps\" with $n app(s) -- they start with [file tail [::tkutils::tkulauncher::currentWish]]"
    return $n
}

# The starter menu written on first run. Uses platform-neutral system entries
# and a Tcl-script example instead of hard-coded xterm/xdg-open commands, and a
# separate "System" submenu built from the launcher's own system catalogue.
proc ::launcherapp::starterSpec {} {
    return {
        {type menu label "Programs" items {
            {type system id terminal}
            {type system id filemanager}
            {type system id editor}
        }}
        {type menu label "System" items {
            {type system id settings}
            {type system id taskmanager}
            {type system id systeminfo}
        }}
        {type menu label "Internet" items {
            {type url label "Tcl/Tk Manual" target "https://www.tcl.tk/man/tcl9.0/"}
            {type url label "Tcl Wiki"      target "https://wiki.tcl-lang.org/"}
        }}
        {type separator}
        {type calendar}
        {type calc}
        {type open label "Home" target "~"}
    }
}

# The starter menu plus the apps found next to the launcher (0.5).
proc ::launcherapp::starterWithApps {} {
    return [lindex [withApps [starterSpec]] 0]
}

# Make sure the config file exists; create it from the starter spec if not.
# Returns 1 if it created a fresh config (so the app can show a first-run hint).
proc ::launcherapp::ensureConfig {path} {
    variable S
    package require tkutils::tkulauncher 0.5
    set fresh 0
    if {![file exists $path]} {
        file mkdir [file dirname $path]
        ::tkutils::tkulauncher::saveEntries [starterWithApps] $path
        set fresh 1
    }
    return $fresh
}

# ---- build -----------------------------------------------------------------
proc ::launcherapp::buildApp {toplevel config} {
    variable S
    package require Tk 8.6-
    package require tkutils::tkulauncher 0.5

    set S(config) $config
    set fresh [ensureConfig $config]

    set top [expr {$toplevel eq "." ? "." : $toplevel}]
    if {$top eq "."} {
        wm title . "Launcher"
        wm geometry . 380x520
    }
    set P [expr {$toplevel eq "." ? "" : $toplevel}]

    # window / taskbar icon from the bundled icon.png
    _setIcon [winfo toplevel $top]

    # menu bar (only for a real toplevel window)
    if {[winfo toplevel $top] eq $top} {
        _buildMenuBar $top
    }

    # top bar: the Start menu button (menu mode)
    ttk::frame $P.top
    ::tkutils::tkulauncher::widget $P.top.start -mode menu -text "Start" \
        -file $S(config) -settings 1 -system 1 -editable 1
    ttk::label $P.top.info -text "right-click to edit" \
        -anchor e -foreground "#777777"
    pack $P.top.start -side left -padx 4 -pady 4
    pack $P.top.info  -side right -fill x -expand 1 -padx 6
    pack $P.top -side top -fill x
    set S(start) $P.top.start

    ttk::separator $P.sep -orient horizontal
    pack $P.sep -side top -fill x -pady 2

    # main area: the same config as a two-column launcher panel (list mode),
    # editable in place. Scrolling needs scrollutil; degrade gracefully if not.
    set scroll [expr {[canScroll] ? 1 : 0}]
    ::tkutils::tkulauncher::widget $P.panel -mode list \
        -file $S(config) -columns 2 -tooltips 1 -scroll $scroll -height 360 \
        -editable 1
    pack $P.panel -side top -fill both -expand 1 -padx 4 -pady 4
    set S(win) $P.panel

    # status bar
    ttk::separator $P.ssep -orient horizontal
    pack $P.ssep -side bottom -fill x
    ttk::label $P.status -anchor w -foreground "#555555" -padding {6 2}
    pack $P.status -side bottom -fill x
    set S(status) $P.status
    _status "Loaded [file tail $S(config)]"

    # first run: nudge the user toward the suggestion catalogue
    if {$fresh} {
        _status "New menu created -- use Edit > Add suggestions... to fill it"
    }
    return $P.panel
}

proc ::launcherapp::_buildMenuBar {top} {
    # menu child path: "." needs ".menubar", others need "$top.menubar"
    set pfx [expr {$top eq "." ? "" : $top}]
    set mb $pfx.menubar
    if {[winfo exists $mb]} { destroy $mb }
    menu $mb -tearoff 0
    $top configure -menu $mb

    set mfile $mb.file
    menu $mfile -tearoff 0
    $mb add cascade -label "File" -menu $mfile
    $mfile add command -label "Reload"              -command ::launcherapp::doReload
    $mfile add command -label "Open config folder"  -command ::launcherapp::openConfigFolder
    $mfile add separator
    $mfile add command -label "Quit" -command ::launcherapp::doQuit

    set medit $mb.edit
    menu $medit -tearoff 0
    $mb add cascade -label "Edit" -menu $medit
    $medit add command -label "Edit menu..."       -command ::launcherapp::doEdit
    $medit add command -label "Add suggestions..." -command ::launcherapp::doSuggest
    $medit add command -label "Quick add defaults" -command ::launcherapp::doQuickAdd
    $medit add command -label "Add tkutils apps"   -command ::launcherapp::doAddApps
    $medit add separator
    $medit add command -label "Check entries..."   -command ::launcherapp::doCheck

    set mhelp $mb.help
    menu $mhelp -tearoff 0
    $mb add cascade -label "Help" -menu $mhelp
    $mhelp add command -label "About" -command ::launcherapp::doAbout
}

# ---- menu actions ----------------------------------------------------------
proc ::launcherapp::_status {msg} {
    variable S
    if {$S(status) ne "" && [winfo exists $S(status)]} { $S(status) configure -text $msg }
}

proc ::launcherapp::_editorTop {} {
    # open the form editor on the panel and return its toplevel
    variable S
    ::tkutils::tkulauncher::editEntries $S(win)
    return .tkulauncher_editor
}

proc ::launcherapp::doEdit {} {
    _editorTop
    _status "Editing menu -- Save writes the file and updates the launcher"
}

proc ::launcherapp::doSuggest {} {
    set top [_editorTop]
    if {[llength [info commands ::tkutils::tkulauncher::_edSuggest]]} {
        ::tkutils::tkulauncher::_edSuggest $top
    }
    _status "Pick entries to add, then Insert"
}

proc ::launcherapp::doQuickAdd {} {
    set top [_editorTop]
    if {[llength [info commands ::tkutils::tkulauncher::_edQuickAdd]]} {
        ::tkutils::tkulauncher::_edQuickAdd $top
    }
    _status "Added a default set -- Save to keep it"
}

# Check every entry -- programs, files, system tools, and whether the web
# addresses still answer -- and list the result (tkulauncher::checkDialog).
proc ::launcherapp::doCheck {} {
    variable S
    ::tkutils::tkulauncher::checkDialog $S(win)
    _status "Checking entries -- double-click a row to edit it"
}

proc ::launcherapp::doReload {} {
    variable S
    catch {::tkutils::tkulauncher::reload $S(start)}
    catch {::tkutils::tkulauncher::reload $S(win)}
    _status "Reloaded [file tail $S(config)]"
}

proc ::launcherapp::openConfigFolder {} {
    variable S
    set dir [file dirname $S(config)]
    if {[catch {::tclutils::tuopen::launch $dir} e]} { _status "Could not open folder: $e" } \
    else { _status "Opened $dir" }
}

proc ::launcherapp::doQuit {} { exit 0 }

proc ::launcherapp::doAbout {} {
    tk_messageBox -icon info -title "About Launcher" -message \
        "Launcher\n\nA start menu / launcher panel built on the tkutils\ntkulauncher widget. Right-click entries to edit, or use\nthe Edit menu to add suggestions.\n\nConfig: [set ::launcherapp::S(config)]"
}

# Is the scrollable panel available? Needs tkuscrolledframe -> scrollutil.
proc ::launcherapp::canScroll {} {
    if {[catch {package require scrollutil}]} { return 0 }
    if {[catch {package require tkutils::tkuscrolledframe}]} { return 0 }
    return 1
}

# Set the window / taskbar icon from a bundled icon.png (next to this script,
# also inside a zipkit). This is the runtime Tk icon; the .exe *file* icon in
# Explorer is a separate PE resource -- see windows-icon.md to change that.
proc ::launcherapp::_setIcon {top} {
    set here [file dirname [file normalize [info script]]]
    set cands [list [file join $here icon.png] [file join $here .. icon.png]]
    foreach f $cands {
        if {[file exists $f]} {
            if {![catch {image create photo ::launcherapp::icon -file $f}]} {
                catch {wm iconphoto $top -default ::launcherapp::icon}
            }
            return
        }
    }
}

# ---- main ------------------------------------------------------------------
proc ::launcherapp::main {argv} {
    set config [expr {[llength $argv] ? [lindex $argv 0] : [defaultConfig]}]
    if {[info exists ::env(LAUNCHER_SELFTEST)] && $::env(LAUNCHER_SELFTEST) ne ""} {
        puts "canScroll=[canScroll]"
        puts "auto_path has pkgs: [expr {[lsearch -glob $::auto_path *pkgs*]>=0}]"
        puts "tkutical (tical) available: [expr {![catch {package require tkutils::tkutical}]}]"
        exit 0
    }
    buildApp . $config
}

# Run the UI when executed directly, or via -launch inside a zipkit. A test
# harness that sets ::LAUNCHERAPP_TEST suppresses the auto-run.
if {![info exists ::LAUNCHERAPP_TEST]} {
    if {[info exists ::argv0] && [file normalize $::argv0] eq [file normalize [info script]]} {
        ::launcherapp::main $::argv
    }
}
