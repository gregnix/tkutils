# tkutils::tkulauncher

An application launcher widget, in two shapes from one widget: a `menu` (a
ttk::menubutton with nested cascades -- a "Start" menu) or a `list` (a vertical
column of ttk::buttons -- a launcher panel). Entries start a program, open a URL,
or open a file/folder. **Cross-platform**: URLs and files are opened with the OS
default through `tclutils::tuopen` (xdg-open / open / cmd start), so nothing is
tied to a desktop environment -- the same launcher works on Windows and Linux.
Tk 8.6+ and 9.x.

## API

```tcl
::tkutils::tkulauncher::widget  path ?options?
::tkutils::tkulauncher::load    file       ;# parse a .json/.ini spec -> items
::tkutils::tkulauncher::resolve entry      ;# what an entry would launch (no side effect)

::tkutils::tkulauncher::reload       path  ;# re-read the -file spec and rebuild
::tkutils::tkulauncher::editConfig   path  ;# open the config file in an editor
::tkutils::tkulauncher::openLocation path  ;# open the folder holding the config
```

## Options

- `-mode`     `menu` or `list` (default `list`).
- `-text`     menubutton label in menu mode (default `Start`).
- `-items`    the entry spec (a Tcl list of dicts).
- `-file`     load the spec from a `.json` or `.ini` file instead.
- `-onlaunch` optional script, appended `{kind argv}` just before launching. A
  false return suppresses the actual launch -- useful for logging, confirmation,
  or testing.
- `-system` when true, append a **System** group of environment-aware tools
  (terminal, file manager, task manager, printers, autostart, ...) that resolve
  to the right command for the running platform / desktop.
- `-settings` when true and a `-file` is in use, append a **Settings** group
  (submenu in menu mode, section in list mode) with *Edit menu...*, *Open file
  location*, and *Reload*.

## Entry spec

A list of dicts, each with a `type`:

```tcl
{type app       label "Firefox"  cmd {firefox}}          ;# run a program
{type url       label "Manual"   target https://tcl.tk}  ;# open a URL
{type open      label "Home"     target /home/greg}      ;# open a file/folder
{type separator}                                          ;# a divider
{type menu      label "Internet" items {...}}            ;# a submenu / section
{type system    id taskmanager}                         ;# an environment-aware system tool
```

- **app** -- `cmd` is a program and its arguments; run in the background.
- **url** / **open** -- `target` is opened with the OS default application.
- **separator** -- a divider.
- **menu** -- in `menu` mode a cascade (submenu); in `list` mode a section header
  (a bold label) followed by its items.

## Two shapes

```tcl
package require tkutils::tkulauncher

set spec {
    {type menu label Internet items {
        {type app label Firefox cmd firefox}
        {type url label "Tcl Manual" target https://www.tcl.tk/man/tcl9.0/}
    }}
    {type separator}
    {type app label Terminal cmd xterm}
}

# a Start menu:
::tkutils::tkulauncher::widget .start -mode menu -text Start -items $spec
pack .start

# or a launcher panel:
::tkutils::tkulauncher::widget .panel -mode list -items $spec
pack .panel -fill both -expand 1
```

## From a file

```tcl
::tkutils::tkulauncher::widget .l -mode list -file ~/.config/mylauncher.json
```

**JSON** -- an object `{"items":[...]}` or a bare array of entries:

```json
{ "items": [
    { "type": "menu", "label": "Internet", "items": [
        { "type": "app", "label": "Firefox", "cmd": ["firefox"] },
        { "type": "url", "label": "Manual", "target": "https://tcl.tk" }
    ]},
    { "type": "app", "label": "Terminal", "cmd": ["xterm"] }
]}
```

**INI** -- each `[section]` is a submenu; each `key = value` is an entry, with a
`type:` prefix picking the type (default `app`):

```ini
[Internet]
Firefox = app: firefox
Manual  = url: https://tcl.tk

[System]
Terminal = xterm
Home     = open: /home/greg
TaskMgr  = system: taskmanager
```

JSON is parsed through `tclutils::tujson`, INI through `tclutils::tuini`.

## Settings: edit, locate, reload

A launcher built from a file can manage its own configuration. Either turn on
`-settings` for a ready-made Settings group, or wire these to your own buttons /
menu entries:

```tcl
::tkutils::tkulauncher::editConfig   .l   ;# open the config in $EDITOR / notepad
::tkutils::tkulauncher::openLocation .l   ;# open the folder it lives in
::tkutils::tkulauncher::reload       .l   ;# re-read it and rebuild in place
```

The usual flow is *Edit menu...* (opens the file), make changes, *Reload* (the
launcher rebuilds without a restart). Editing and locating go through
`tclutils::tuopen`, so they use the OS editor and file manager on both Windows
and Linux. Without a `-file`, these report that there is nothing to edit.

## System tools (environment-aware)

A `system` entry names a well-known tool by `id`, and the launcher chooses the
right command for the running platform and desktop -- so one menu does the right
thing on Windows 11, XFCE, GNOME or KDE:

```tcl
{type system id terminal}      ;# xfce4-terminal / gnome-terminal / konsole / wt.exe
{type system id taskmanager}   ;# xfce4-taskmanager / gnome-system-monitor / taskmgr.exe
{type system id printers}      ;# system-config-printer / ms-settings:printers
{type system id autostart}     ;# xfce4-session-settings / shell:startup / ~/.config/autostart
```

Known ids: `terminal`, `cmd` (Windows), `powershell`, `filemanager`,
`taskmanager`, `settings`, `printers`, `autostart`, `display`. An entry with no
`label` gets a built-in title. Ids that have no command on the current platform
(e.g. `cmd` on Linux) are simply omitted by `-system` / `systemItems`.

```tcl
# ready-made group of the tools available here:
::tkutils::tkulauncher::widget .l -mode list -items $spec -system 1

# or build the spec yourself and embed it:
set sys [::tkutils::tkulauncher::systemItems -ids {terminal taskmanager printers}]

# resolve one id to a command without launching (override platform for testing):
::tkutils::tkulauncher::resolveSystem taskmanager -platform windows
# -> kind exec argv {taskmgr.exe}

# the display title for a system id (used when an entry gives no label):
::tkutils::tkulauncher::systemTitle taskmanager     ;# -> "Task Manager"
```

The commands are sensible defaults; adjust the `sysCat` catalogue for site
specifics. `resolveSystem` takes `-platform` / `-os` / `-desktop` overrides.

## resolve

`resolve` turns an entry into an action dict `{kind exec|open argv {...}}` without
performing it, so a caller (or a test) can see what a click would do:

```tcl
::tkutils::tkulauncher::resolve {type url label X target https://tcl.tk}
# -> kind open argv https://tcl.tk
```

## See also

`tclutils::tuopen`, `tclutils::tujson`, `tclutils::tuini`, `tkumenu`
