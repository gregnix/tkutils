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
::tkutils::tkulauncher::showCalendar   path  ;# open the built-in calendar window
::tkutils::tkulauncher::showCalculator path  ;# open the built-in calculator window
::tkutils::tkulauncher::editEntries   path  ;# open the form-based entry editor
::tkutils::tkulauncher::saveEntries   items file  ;# write entries (JSON or INI by extension)
::tkutils::tkulauncher::systemIds            ;# all known system ids (for pickers)
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
- `-columns` (list mode) lay the buttons out in N columns instead of one, so a
  small panel of important entries stays compact. Section headers and separators
  span all columns. Combine with `-scroll` if needed.
- `-tooltips` show a tooltip on each list button: an entry's explicit `tooltip`
  field, or (when on) one derived from what the entry would launch (the command,
  URL, or resolved system command). Handy when labels are short.
- `-scroll` (list mode) put the buttons in a scrollable frame with a scrollbar,
  so a long list stays usable; `-height` sets its pixel height (default 400). The
  **mouse wheel** scrolls the panel from anywhere in it (via `tkuwheel`), and
  keeps working after a reload.
- `-settings` when true and a `-file` is in use, append a **Settings** group
  (submenu in menu mode, section in list mode) with *Edit menu...*, *Open file
  location*, and *Reload*.

## Entry spec

A list of dicts, each with a `type`:

```tcl
{type app  label "Firefox" cmd {firefox} icon path dir path tooltip text}  ;# run a program
{type url       label "Manual"   target https://tcl.tk}  ;# open a URL
{type open      label "Home"     target /home/greg}      ;# open a file/folder
{type separator}                                          ;# a divider
{type menu      label "Internet" items {...}}            ;# a submenu / section
{type system    id taskmanager}                         ;# an environment-aware system tool
{type calendar}                                         ;# open a built-in calendar window
{type calc}                                             ;# open a built-in calculator window
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

## Long menus

In **list** mode, a long button column can overflow the window; pass `-scroll 1`
(optionally with `-height`) to put it in a scrollable frame with a scrollbar. In
**menu** mode, Tk scrolls an over-long menu natively (arrows); the better fix
there is to group entries into submenus with `type menu`.

## Icons, working directory, availability

App and other entries take a few optional fields:

- `icon` -- a path to an image file (png/gif/...) or the name of an existing Tk
  image; shown next to the label in both modes. A missing/unreadable icon is
  ignored (the entry just shows text).
- `dir` -- a working directory the program is launched in (app entries).
- `terminal` -- run a CLI program inside a terminal window (app entries): on
  Windows a new console (`cmd /k`), on Linux the desktop terminal with `-e`
  (or `--` for gnome-terminal). Use for htop, less, a REPL, etc.

On **Windows**, app entries are launched through `start`, so a program that is
registered under *App Paths* (Firefox, Chrome, ...) works even though it is not on
`PATH` -- you do not need to give a full path. A working directory is passed via
`start /D`. On **Linux/macOS** the program is run directly (it must be on `PATH`
or given as a full path).

App entries whose program is **not found** are shown **greyed out** (disabled),
so a menu never offers something that would fail. On Windows a bare name is
assumed launchable (start resolves it); only an explicit path that does not exist
is greyed out. `available $entry` reports this (url/open/system entries are always
available, since they go through the OS opener).

```tcl
{type app label "Editor" cmd {code} icon ~/.icons/code.png dir ~/projects}
::tkutils::tkulauncher::available {type app label X cmd firefox}   ;# 1 or 0
```

## Editing the menu with a form

When a launcher is built with `-file` and `-settings 1`, the Settings submenu
offers "Edit menu (form)..." next to the plain text editor. A launcher built with
`-editable 1` (even from `-items`, with no Settings group) can also be edited by
right-clicking it and choosing "Edit..." -- handy for a list-mode panel. The Type field is a
dropdown, and for `system` entries the System id field is a dropdown of every
known system id (sound, bluetooth, display, ...), so you pick instead of type. It opens a form-based
editor (needs `tkutils::tkuform`): a list of entries on the left, a form on the
right. New/Delete manage the list, and a "New in:" dropdown chooses which menu a new
entry is created in. Up/Down reorder the selected entry within its menu, and
"Move to..." moves it into another menu (top level or any submenu). Apply copies the form into the
selected entry; "Update launcher" applies the changes to the live launcher; and
"Save to file..." writes them back -- as JSON (full fidelity) or INI (flat prefix form)
chosen by the file extension -- then reloads the launcher.

```tcl
::tkutils::tkulauncher::editEntries .launcher    ;# open the editor
::tkutils::tkulauncher::saveEntries $items menu.json  ;# or menu.ini
```

Saving is symmetric with loading: `menu.json` round-trips every field including
nested submenus; `menu.ini` maps top-level menus to sections and entries to
`label = prefix: value` lines (`app:`, `url:`, `open:`, `file:`, `system:`).

## Calendar and calculator

A `calendar` entry opens a small calendar window, and a `calc` entry opens the
built-in calculator (`tkucalc`, with keyboard input and history) -- both in a
reusable window that stays above the launcher (a transient satellite of it) and
minimizes with it.

The calendar picks the richest widget available: if the `tical` engine is on the
auto_path it uses `tkutical` (month view with week numbers and German holidays),
otherwise the dependency-free clickable `tkucalendar`, then the text `tkucal`,
then a built-in month grid. So a launcher works with no external programs, and
gets more when tical is present.

```tcl
{type calendar}   ;# label defaults to "Calendar"
{type calc}       ;# label defaults to "Calculator"
```

## Calendar

A `calendar` entry opens a small calendar window (month view with
previous/next/today). It uses the tkutils `tkucal` widget when available and
falls back to a dependency-free month grid otherwise -- so it works everywhere,
like the rest of the launcher.

```tcl
{type calendar}                 ;# label defaults to "Calendar"
{type calendar label "Kalender"}
```

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
`taskmanager`, `settings`, `printers`, `autostart`, `display`, `network`,
`sound`, `bluetooth`, `power`, `keyboard`, `mouse`, `appearance`, `datetime`,
`users`, `about`, `calculator`, `editor`, `screenshot`, `lock`, `diskmanager`,
`controlpanel` (Windows), `devicemanager` (Windows), `services` (Windows),
`software`, `printjobs`, `systeminfo, logout, restart, shutdown, suspend, brightness, wifi, updates, firewall, fonts, notifications, colorpicker, magnifier, onscreenkeyboard, clipboard, environment`. An entry with no
`label` gets a built-in title. Ids that have no command on the current platform
(e.g. `cmd` on Linux) are simply omitted by `-system` / `systemItems`.

```tcl
# ready-made group of the tools available here (default set: terminal,
# filemanager, taskmanager, settings, printers, printjobs, network, sound,
# bluetooth, power, display, autostart, systeminfo -- unavailable ones omitted):
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


## Launching Tcl/Tk scripts (`tcl` entries)

A `tcl` entry runs a Tcl/Tk script with a chosen interpreter, cross-platform.
Fields: `target` (the script path), `interp` (one of `wish9`, `wish8`, `tclsh9`,
`tclsh8`; default `wish9`), optional `tcllibpath` (set as `TCLLIBPATH` for the
child -- the essence of a tcl8env/tcl9env setup), optional `args`, `dir`, and
`terminal` (for `tclsh` scripts). Interpreter keys map per platform:

| key    | Linux      | Windows        |
|--------|------------|----------------|
| wish9  | wish9.0    | wish90.exe     |
| wish8  | wish8.6    | wish86t.exe    |
| tclsh9 | tclsh9.0   | tclsh90.exe    |
| tclsh8 | tclsh8.6   | tclsh86t.exe   |

The command `tclInterpreters` returns the available interpreter keys (used by
the editor dropdown), `resolveTclInterp key ?platform?` maps a key to the
executable for a platform, and `setTclInterp` overrides a mapping.

Override a mapping (e.g. an absolute path) with
`::tkutils::tkulauncher::setTclInterp wish9 -linux /opt/tcl9/bin/wish9.0 -windows C:/Tcl/bin/wish90.exe`.
Example entry: `{type tcl label "My App" target ~/app.tcl interp wish9 tcllibpath "~/lib/tcl9.0 ~/lib/tcltk"}`.


## Home directory and `~` (Tcl 9)

Tcl 9 no longer expands a leading `~` in file commands, so the launcher expands
it itself for path fields (`open`/`file` targets, `tcl` script/dir, each
`tcllibpath` entry, and system paths like autostart). `homeDir` returns the
user's home on both Tcl 8.6 and 9 (via `file home`, then `HOME`/`USERPROFILE`),
and `expandTilde path` turns a leading `~` or `~/...` into an absolute path,
leaving everything else (including URLs) untouched. So `~` in a config keeps
working under Tcl 9.


## Suggestions (not sure what to add?)

If you are not sure which entries a menu should have, the editor can suggest
some. **Quick add** inserts a sensible default set (terminal, file manager,
calculator, calendar, Home). **Suggest...** opens a checklist grouped by
category -- System tools, Power, Internet, Tcl scripts, Basics -- where you tick
what you want and press Insert. Both add into the menu chosen in the "New in:"
dropdown. The catalogue is `suggestions` (returns `{category {entry ...} ...}`)
and `quickAddSet` (the default set); both are plain data you can reuse.
