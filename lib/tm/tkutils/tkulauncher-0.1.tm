# tkutils::tkulauncher -- an application launcher widget (ttk).
#
# A cross-platform (Windows and Linux) launcher, in two shapes from one widget:
#
#   menu  -- a ttk::menubutton with nested cascades (a "Start" menu)
#   list  -- a vertical column of ttk::buttons (a launcher panel)
#
# Entries can start a program, open a URL, or open a file/folder. URLs and
# files/folders are opened with the OS default via tclutils::tuopen
# (xdg-open / open / cmd start), so nothing here is tied to a desktop
# environment -- unlike a raw exo-open/xfce launcher, this works the same on
# Windows and Linux.
#
# Entries come from a Tcl spec (-items) or a file (-file, .json or .ini), parsed
# through tclutils engines (tujson / tuini). Model (parsing, launching) lives in
# tclutils; this is just the View.
#
#   ::tkutils::tkulauncher::widget .l -mode menu -text Start -items $spec
#   ::tkutils::tkulauncher::widget .l -mode list -file menu.json
#
# Entry spec: a list of dicts, each with a "type":
#   {type app   label L cmd  {prog arg ...}}   run a program (background)
#   {type url   label L target URL}            open a URL (OS default)
#   {type open  label L target PATH}           open a file/folder (OS default)
#   {type separator}                            a divider
#   {type menu  label L items {...}}           a submenu (menu mode) or a
#                                               section header + its items (list)

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuopen

namespace eval ::tkutils {}
namespace eval ::tkutils::tkulauncher {
    namespace export widget load resolve reload editConfig openLocation \
        resolveSystem systemItems systemTitle
    variable state
}

# Build a launcher at $path. Options:
#   -mode   menu|list           (default list)
#   -text   label               menubutton text in menu mode (default "Start")
#   -items  spec                entry spec (a Tcl list of dicts)
#   -file   path                load the spec from a .json or .ini file
#   -onlaunch script            optional; appended {kind argv} before launching,
#                               for logging/testing. Return a false value to
#                               suppress the actual launch.
proc ::tkutils::tkulauncher::widget {path args} {
    variable state
    array set o {-mode list -text Start -items {} -file "" -onlaunch "" -settings 0 -system 0}
    array set o $args

    set items $o(-items)
    if {$o(-file) ne ""} { set items [load $o(-file)] }

    set state($path,onlaunch) $o(-onlaunch)
    set state($path,mode)     $o(-mode)
    set state($path,file)     $o(-file)
    set state($path,settings) $o(-settings)
    set state($path,system)   $o(-system)
    set state($path,items)    $items

    if {$o(-mode) eq "menu"} {
        ttk::menubutton $path -text $o(-text)
        set m [menu $path.menu -tearoff 0]
        $path configure -menu $m
    } else {
        ttk::frame $path
    }
    _populate $path
    bind $path <Destroy> [list ::tkutils::tkulauncher::_cleanup $path %W]
    return $path
}

# (Re)fill the widget from state. Called at build time and by reload. If
# -settings is on and a config file is in use, a Settings group is appended:
# edit the config, open its folder, and reload.
proc ::tkutils::tkulauncher::_populate {path} {
    variable state
    set items $state($path,items)
    # optional System group: environment-aware tools (terminal, task manager,
    # printers, autostart, ...) that resolve to the right command per platform.
    if {[info exists state($path,system)] && $state($path,system)} {
        set sys [systemItems]
        if {[llength $sys]} {
            lappend items [dict create type separator]
            lappend items [dict create type menu label "System" items $sys]
        }
    }
    if {$state($path,settings) && $state($path,file) ne ""} {
        lappend items [dict create type separator]
        lappend items [dict create type menu label "Settings" items [list \
            [dict create type _edit     label "Edit menu..."] \
            [dict create type _location label "Open file location"] \
            [dict create type _reload   label "Reload"] \
        ]]
    }
    if {$state($path,mode) eq "menu"} {
        $path.menu delete 0 end
        _fillMenu $path $path.menu $items
    } else {
        foreach c [winfo children $path] { destroy $c }
        _fillList $path $path $items 0
    }
}

# Label for an entry: explicit -label, or the system title for a system entry.
proc ::tkutils::tkulauncher::_label {entry} {
    if {[dict exists $entry label]} { return [dict get $entry label] }
    if {[dict get $entry type] eq "system" && [dict exists $entry id]} {
        return [systemTitle [dict get $entry id]]
    }
    return "?"
}

# ---- menu mode ------------------------------------------------------------
proc ::tkutils::tkulauncher::_fillMenu {path menu items} {
    set sub 0
    foreach e $items {
        set type [dict get $e type]
        switch -- $type {
            separator { $menu add separator }
            menu {
                set child [menu $menu.[incr sub] -tearoff 0]
                $menu add cascade -label [_label $e] -menu $child
                _fillMenu $path $child [dict get $e items]
            }
            default {
                $menu add command -label [_label $e] \
                    -command [list ::tkutils::tkulauncher::_activate $path $e]
            }
        }
    }
}

# ---- list mode ------------------------------------------------------------
# Nested menus do not map to a flat button column, so a "menu" entry becomes a
# section header (a bold label) followed by its items, one level deep-flattened.
proc ::tkutils::tkulauncher::_fillList {path parent items depth} {
    set n 0
    foreach e $items {
        set type [dict get $e type]
        set w $parent.i[incr ::tkutils::tkulauncher::_seq]
        switch -- $type {
            separator {
                ttk::separator $w -orient horizontal
                pack $w -side top -fill x -padx 5 -pady 6
            }
            menu {
                ttk::label $w -text [_label $e] -anchor w \
                    -font TkHeadingFont
                pack $w -side top -fill x -padx 5 -pady {6 2}
                _fillList $path $parent [dict get $e items] [expr {$depth+1}]
            }
            default {
                ttk::button $w -text [_label $e] \
                    -command [list ::tkutils::tkulauncher::_activate $path $e]
                pack $w -side top -fill x -padx 5 -pady 2
            }
        }
    }
}
namespace eval ::tkutils::tkulauncher { variable _seq 0 }

# ---- resolve + activate ---------------------------------------------------
# resolve turns an entry into an action WITHOUT performing it, so callers and
# tests can inspect what would run. Returns {kind K argv {...}} where kind is
# exec | open, or throws on a malformed entry. (open covers url and file/dir --
# both go through the OS default opener.)
proc ::tkutils::tkulauncher::resolve {entry} {
    switch -- [dict get $entry type] {
        app - command {
            if {![dict exists $entry cmd]} { error "app entry has no cmd" }
            return [dict create kind exec argv [dict get $entry cmd]]
        }
        url - open - file {
            if {![dict exists $entry target]} { error "entry has no target" }
            return [dict create kind open argv [list [dict get $entry target]]]
        }
        system {
            if {![dict exists $entry id]} { error "system entry has no id" }
            return [resolveSystem [dict get $entry id]]
        }
        default { error "cannot launch entry of type [dict get $entry type]" }
    }
}

proc ::tkutils::tkulauncher::_activate {path entry} {
    variable state
    # built-in settings actions act on this launcher, not on an external target
    switch -- [dict get $entry type] {
        _edit     { editConfig   $path ; return }
        _location { openLocation $path ; return }
        _reload   { reload       $path ; return }
    }
    if {[catch {resolve $entry} act]} {
        _error $path "Cannot launch '[_label $entry]':\n$act" ; return
    }
    # optional hook: {kind argv}; a false return suppresses the real launch
    if {$state($path,onlaunch) ne ""} {
        set go [uplevel #0 [list {*}$state($path,onlaunch) \
                    [dict get $act kind] [dict get $act argv]]]
        if {[string is boolean -strict $go] && !$go} return
    }
    if {[catch {_perform $act} e]} {
        _error $path "Could not launch '[_label $entry]':\n$e"
    }
}

proc ::tkutils::tkulauncher::_perform {act} {
    switch -- [dict get $act kind] {
        exec { exec {*}[dict get $act argv] & }
        open { ::tclutils::tuopen::launch [lindex [dict get $act argv] 0] }
    }
}

proc ::tkutils::tkulauncher::_error {path msg} {
    if {[llength [info commands ::tkutils::tkudialog::showError]]} {
        ::tkutils::tkudialog::showError $msg
    } else {
        catch {tk_messageBox -icon error -message $msg}
    }
}

# ---- loading a spec from a file -------------------------------------------
# .json: an object {mode? items:[...]} or a bare array of entries.
# .ini : each [section] is a submenu; each key=value is an entry, the value's
#        first token picking the type (app:/url:/open:) else app by default.
proc ::tkutils::tkulauncher::load {file} {
    set ext [string tolower [file extension $file]]
    set ch [open $file r] ; fconfigure $ch -encoding utf-8
    set text [read $ch] ; close $ch
    switch -- $ext {
        .json { return [_loadJson $text] }
        .ini  { return [_loadIni  $text] }
        default { error "unsupported launcher file type: $ext (use .json or .ini)" }
    }
}

proc ::tkutils::tkulauncher::_loadJson {text} {
    package require tclutils::tujson
    set d [::tclutils::tujson::fromJson $text]
    # bare array -> the items; object -> its "items"
    if {[string index [string trimleft $text] 0] eq "\["} { return $d }
    if {[dict exists $d items]} { return [dict get $d items] }
    return {}
}

proc ::tkutils::tkulauncher::_loadIni {text} {
    package require tclutils::tuini
    set data [::tclutils::tuini::parse $text]
    set items {}
    foreach sec [::tclutils::tuini::sections $data] {
        if {$sec eq ""} continue
        set sub {}
        foreach k [::tclutils::tuini::keys $data $sec] {
            set v [::tclutils::tuini::get $data $sec $k]
            lappend sub [_iniEntry $k $v]
        }
        lappend items [dict create type menu label $sec items $sub]
    }
    return $items
}

# One "key = value" line -> an entry. A "type:" prefix on the value picks the
# type; otherwise it is a program to exec.
#   Firefox = app: firefox
#   Manual  = url: https://tcl.tk
#   Home    = open: /home/greg
proc ::tkutils::tkulauncher::_iniEntry {label value} {
    set value [string trim $value]
    if {[regexp {^(app|url|open|file|system)\s*:\s*(.*)$} $value -> t rest]} {
        set rest [string trim $rest]
        switch -- $t {
            app    { return [dict create type app    label $label cmd $rest] }
            system { return [dict create type system label $label id  $rest] }
            default { return [dict create type $t label $label target $rest] }
        }
    }
    return [dict create type app label $label cmd $value]
}

# ---- settings: edit the config, open its folder, reload -------------------
# Re-read the -file spec and rebuild the widget in place. No-op without a file.
proc ::tkutils::tkulauncher::reload {path} {
    variable state
    if {![info exists state($path,file)] || $state($path,file) eq ""} return
    if {[catch {load $state($path,file)} items]} {
        _error $path "Could not reload menu:\n$items" ; return
    }
    set state($path,items) $items
    _populate $path
}

# Open the config file in a text editor (EDITOR / notepad / open -e), via tuopen.
proc ::tkutils::tkulauncher::editConfig {path} {
    variable state
    set f [expr {[info exists state($path,file)] ? $state($path,file) : ""}]
    if {$f eq ""} { _error $path "No config file to edit (menu was built from a Tcl spec)." ; return }
    if {[catch {::tclutils::tuopen::edit $f} e]} {
        _error $path "Could not open editor:\n$e"
    }
}

# Open the folder containing the config file (or the cwd if built from a spec).
proc ::tkutils::tkulauncher::openLocation {path} {
    variable state
    set f [expr {[info exists state($path,file)] ? $state($path,file) : ""}]
    set target [expr {$f ne "" ? $f : [pwd]}]
    if {[catch {::tclutils::tuopen::openDir $target} e]} {
        _error $path "Could not open file location:\n$e"
    }
}

proc ::tkutils::tkulauncher::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    array unset state $path,*
}

# ---- system tools: environment-aware entries ------------------------------
# A "system" entry names a well-known tool by id (terminal, cmd, powershell,
# filemanager, taskmanager, settings, printers, autostart, display), and the
# right command for the running platform / desktop is chosen automatically.
# This is what lets one menu offer "Task Manager" or "Printers" and have it do
# the right thing on Windows 11, XFCE, GNOME or KDE.

namespace eval ::tkutils::tkulauncher {
    # id -> human title (used when an entry gives no label)
    variable sysTitle {
        terminal "Terminal"  cmd "Command Prompt"  powershell "PowerShell"
        filemanager "File Manager"  taskmanager "Task Manager"
        settings "System Settings"  printers "Printers"
        autostart "Autostart"  display "Display Settings"
    }
    # id -> { platkey -> {kind exec|open argv {...}} }. platkey is one of
    # windows macos xfce gnome kde linux; a unix desktop falls back to linux.
    variable sysCat {
        terminal {
            windows {kind exec argv {cmd.exe /c start "" wt.exe}}
            macos   {kind exec argv {open -a Terminal}}
            xfce    {kind exec argv {xfce4-terminal}}
            gnome   {kind exec argv {gnome-terminal}}
            kde     {kind exec argv {konsole}}
            linux   {kind exec argv {x-terminal-emulator}}
        }
        cmd {
            windows {kind exec argv {cmd.exe /c start "" cmd.exe}}
        }
        powershell {
            windows {kind exec argv {cmd.exe /c start "" powershell.exe}}
            linux   {kind exec argv {pwsh}}
        }
        filemanager {
            windows {kind exec argv {explorer.exe}}
            macos   {kind exec argv {open .}}
            xfce    {kind exec argv {thunar}}
            gnome   {kind exec argv {nautilus}}
            kde     {kind exec argv {dolphin}}
            linux   {kind open argv .}
        }
        taskmanager {
            windows {kind exec argv {taskmgr.exe}}
            macos   {kind exec argv {open -a {Activity Monitor}}}
            xfce    {kind exec argv {xfce4-taskmanager}}
            gnome   {kind exec argv {gnome-system-monitor}}
            kde     {kind exec argv {plasma-systemmonitor}}
        }
        settings {
            windows {kind open argv ms-settings:}
            macos   {kind exec argv {open -a {System Settings}}}
            xfce    {kind exec argv {xfce4-settings-manager}}
            gnome   {kind exec argv {gnome-control-center}}
            kde     {kind exec argv {systemsettings}}
        }
        printers {
            windows {kind open argv ms-settings:printers}
            macos   {kind open argv {x-apple.systempreferences:com.apple.preference.printfax}}
            xfce    {kind exec argv {system-config-printer}}
            gnome   {kind exec argv {gnome-control-center printers}}
            kde     {kind exec argv {systemsettings kcm_printer_manager}}
            linux   {kind exec argv {system-config-printer}}
        }
        autostart {
            windows {kind exec argv {explorer.exe shell:startup}}
            macos   {kind open argv {x-apple.systempreferences:com.apple.preferences.users}}
            xfce    {kind exec argv {xfce4-session-settings}}
            gnome   {kind open argv {~/.config/autostart}}
            kde     {kind exec argv {systemsettings kcm_autostart}}
            linux   {kind open argv {~/.config/autostart}}
        }
        display {
            windows {kind open argv ms-settings:display}
            xfce    {kind exec argv {xfce4-display-settings}}
            gnome   {kind exec argv {gnome-control-center display}}
            kde     {kind exec argv {systemsettings kcm_kscreen}}
        }
    }
}

proc ::tkutils::tkulauncher::systemTitle {id} {
    variable sysTitle
    if {[dict exists $sysTitle $id]} { return [dict get $sysTitle $id] }
    return $id
}

# Map platform/os/desktop to a catalogue key.
proc ::tkutils::tkulauncher::_platkey {plat os desktop} {
    if {$plat eq "windows"} { return windows }
    if {[string match -nocase *darwin* $os]} { return macos }
    set d [string tolower $desktop]
    if {[string match *xfce* $d]}    { return xfce }
    if {[string match *gnome* $d]}   { return gnome }
    if {[string match *kde* $d] || [string match *plasma* $d]} { return kde }
    return linux
}

# Resolve a system id to an action {kind exec|open argv {...}} for the platform.
# Options -platform / -os / -desktop override detection (for testing). Throws if
# the id is unknown or has no command on that platform.
proc ::tkutils::tkulauncher::resolveSystem {id args} {
    variable sysCat
    array set o [list -platform $::tcl_platform(platform) \
                      -os $::tcl_platform(os) \
                      -desktop [expr {[info exists ::env(XDG_CURRENT_DESKTOP)] ? $::env(XDG_CURRENT_DESKTOP) : ""}]]
    array set o $args
    if {![dict exists $sysCat $id]} { error "unknown system id: $id" }
    set byPlat [dict get $sysCat $id]
    set key [_platkey $o(-platform) $o(-os) $o(-desktop)]
    # desktop-specific -> fall back to generic linux for unix desktops
    if {[dict exists $byPlat $key]} {
        return [dict get $byPlat $key]
    }
    if {$key in {xfce gnome kde} && [dict exists $byPlat linux]} {
        return [dict get $byPlat linux]
    }
    error "system '$id' is not available on this platform ($key)"
}

# The system ids that resolve on the current platform, as a spec of entries.
# Pass -ids to choose a subset/order; default is a sensible common set.
proc ::tkutils::tkulauncher::systemItems {args} {
    variable sysCat
    array set o {-ids {terminal filemanager taskmanager settings printers autostart}}
    array set o $args
    set out {}
    foreach id $o(-ids) {
        if {![catch {resolveSystem $id}]} {
            lappend out [dict create type system id $id label [systemTitle $id]]
        }
    }
    return $out
}

package provide tkutils::tkulauncher 0.1
