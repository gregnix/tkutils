# Launcher

> Current build-app (Tcl/Tk 9 only): `-launch` is not needed -- the program
> starts the app through its own argv0 guard; the SQL editors bring their
> shared code from `_lib/sqledit` themselves (no `-include`); the prober
> looks in the Tcl running build-app when `-extlib` is missing. See
> `build-app-README.md` (tclutils/apps/build-app/doc).

A standalone start menu / launcher panel built on the tkutils `tkulauncher`
widget. It shows a **Start** menu button plus a two-column, scrollable launcher
panel, both loaded from one JSON config file and editable in place
(**right-click -> Edit...**). The built-in calendar and calculator entries are
included, so it runs without any external helper programs.

## Running

```bash
wish launcher.tcl ?config.json?
```

With no argument it uses (and creates on first run) a per-user config:

- Unix: `$XDG_CONFIG_HOME/tkulauncher/menu.json` (or `~/.config/tkulauncher/menu.json`)
- Windows: `%APPDATA%/tkulauncher/menu.json`

The libraries (`tkutils`, `tclutils`) are found via the shared bootstrap
`../_lib/paths.tcl` -- no manual `export` needed when they sit in a standard
location. The scrollable panel also needs **Tablelist**/**scrollutil** (tklib)
on the `auto_path`; without them the panel still works, just without scrolling.

## Menu bar

The window has a **File / Edit / Help** menu bar:

- **File**: Reload, Open config folder, Quit.
- **Edit**: **Edit menu...** (opens the form editor), **Add suggestions...**
  (opens the editor and the suggestion catalogue), **Quick add defaults**
  (inserts a sensible default set). Great when you are not sure what to add.
  **Check entries...** goes through every entry without starting anything:
  is the program found, does the file or folder exist, does the system tool
  exist here, does the web address still answer (redirects are followed and
  shown as "moved" with the new address). https needs the `tls` package; a
  page that cannot be checked on this computer (no `tls`, no CA bundle) is
  listed as "not checked" with the reason, not as a problem. Double-click a
  row to edit the entry.
  **Add tkutils apps** puts the other apps of this folder (address book,
  CSV editor, knowledge base, notes, the SQL editors, search and replace,
  developer toolbox, GUI designer) into a submenu **Apps**; run again, it
  replaces that submenu. They start with the same Tcl/Tk as the launcher
  (interpreter `current`). A new menu already has it. A packaged launcher
  has no apps next to it and says so. An editor whose database package is
  missing (Oratcl, the PostgreSQL driver) shows that on start;
  **Check entries...** only checks that the script and wish exist.
- **Help**: About.

A status line at the bottom shows what happened; on first run it points you to
*Edit > Add suggestions...*.

## Editing

Right-click the Start button or the panel and choose **Edit...** to open the
form editor: a list of entries (submenus shown indented), a form on the right
that shows only the fields of the chosen type (Type and System id are
dropdowns), and a **New in:** picker to choose which menu a new entry lands in.
**Apply** changes the selected entry; **Save** applies it too, writes the
config file and updates the launcher; **Save as...** writes another file;
**Check...** checks the entries as they are in the editor. **Close** asks
when something is unsaved. Because the app is file-backed, saved changes
survive a restart.

## Building a standalone program

Use the repo's own builder, `tclutils/apps/build-app` (or the packaged
`tclutils/apps/bin/build-app-zipkit-linux`). It turns this app into a single
Tcl 9 zipkit executable via `tclutils::tuzipfs` -- the app follows the
`build-app` app conventions (one `buildApp`/`main` entry proc started with
`-launch`, self-references via `[info script]`, dependencies via
`package require`, config written only to the user's home).

This is a **GUI** app, so it needs a **wish** basekit. From
`tclutils/apps/bin/` (side-by-side `tclutils/` and `tkutils/` checkouts):

```bash
xvfb-run -a ./build-app-zipkit-linux -kind gui -out tkulauncher \
    -basekit basekit-tk \
    -app ../../../tkutils/apps/launcher -main launcher.tcl \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -extlib /path/to/tklib/modules
```

Notes:

- no `-launch`: build-app sets `argv0` to `launcher.tcl`, so its argv0
  guard starts the app inside the zipkit, too.
- `-tm` twice: the `tkutils` and `tclutils` module trees.
- `-extlib` points at a tklib `modules` dir so the prober can bundle
  Tablelist/scrollutil for the scrollable panel. Add `-probe 0` to skip probing
  (then bundle external packages yourself or drop `-scroll`).
- For the rich calendar (holidays), the `tical` engine must be on the path at
  build time (probe) or bundled with `-include DIR=pkgs/tical` (cross build).
  Without it the calendar still works via the dependency-free `tkucalendar`.
- A GUI build runs the prober, which briefly starts the app -- give it a display
  via `xvfb-run -a` on a headless host.

The result is one file: `./tkulauncher ?config.json?`. With a static BAWT /
magicsplat basekit it is fully self-contained (`ldd` shows no libtcl/libtk).

See `tclutils/apps/build-app/doc/` for the full builder documentation and more
worked examples (notes-app, sqlite-editor, ...).

## Menu templates

Ready-made configs to start from lie next to `launcher.tcl`. Point the app at
one:

```bash
wish launcher.tcl example-developer.json
```

- `example-developer.json` -- terminal/editor/file manager, Tcl/Tk docs, dev web
  links, a System submenu, calculator + calendar, a Projects shortcut.
- `example-sysadmin.json` -- System / Network / Maintenance / Power submenus
  wired to the built-in system entries (task manager, services, firewall,
  updates, restart/shutdown, ...), plus terminal and file manager.
- `example-tclscripts.json` -- Tcl scripts started with wish/tclsh 8.6 or 9,
  with `TCLLIBPATH` per entry. The paths are placeholders (`~/projects/...`):
  adjust them; **Check entries...** shows which ones are missing.
- `example-minimal.json` -- just terminal, file manager, calculator, calendar,
  Home. A clean starting point.
- `example-menu.json` -- the short sample used in the docs.

Copy one to your config location (see "Running" above) and edit it in place via
right-click -> Edit..., or just pass it on the command line. System entries
resolve per platform automatically; ones your desktop can't provide are skipped.

## Icon

The window / taskbar icon is loaded from `icon.png` next to the script (bundled
automatically into a standalone build, since build-app copies the whole app
directory). Replace `icon.png` to change it. The `.exe` *file* icon in Explorer
is a separate PE resource -- see `windows-icon.md` for how to change that.

## Files

- `launcher.tcl`      the application
- `icon.png`          window/taskbar icon (bundled automatically)
- `windows-icon.md`   how to change the .exe file icon (rcedit)
- `build.md`          the build command for a Windows .exe in short
- `example-*.json`    ready-made menu templates (see above)
- `tests/launcher.test`  smoke test: `tclsh tests/launcher.test` (needs a
  display, headless under `xvfb-run -a`)

## Cross-building a Windows .exe on Linux

The output platform is decided entirely by `-basekit`: pass a **Windows** static
basekit and you get a Windows `.exe`, even while building on Linux. `zipfs mkimg`
prepends the PE interpreter and appends the archive; the stdlib comes from that
same Windows basekit.

```bash
wish9.0 build-app.tcl \
  -kind gui -out tkulauncher.exe \
  -basekit /path/to/zipkit-9_0_4-win64-intel-tk.exe \
  -app ../../../tkutils/apps/launcher -main launcher.tcl \
  -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
  -include /path/to/tklib/modules/scrollutil=pkgs/scrollutil \
  -include /path/to/tical=pkgs/tical \
  -probe 0
```

Two things matter for a cross build:

- **`-probe 0`.** The prober would start the app to discover dependencies, but a
  Windows `.exe` can't run on Linux. With probing off, `-extlib` does nothing, so
  external packages (scrollutil for the scrollable panel) are **not** bundled
  automatically -- bundle them yourself with `-include` (see next point).
- **Bundle scrollutil with `-include DIR=pkgs/scrollutil`.** The app adds any
  bundled `pkgs/` directory to the `auto_path` at startup, so the scrollable
  panel works in the `.exe`. Without it the app still runs -- it just falls back
  to a non-scrolling panel (see `canScroll`). Add Tablelist the same way if you
  need it.
- **Bundle `tical` with `-include DIR=pkgs/tical`** if you want the rich calendar
  (`tkutical`: week numbers + German holidays). `tical` is an external pkgIndex
  library, so like scrollutil it must be bundled explicitly. Without it the
  calendar entry falls back to the dependency-free `tkucalendar` -- still
  clickable, just without holidays.

You need only the Windows basekit -- no Wine, no MinGW. The result begins with
`MZ`, is a valid PE, and runs on Windows.
