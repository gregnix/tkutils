# Launcher

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
- **Help**: About.

A status line at the bottom shows what happened; on first run it points you to
*Edit > Add suggestions...*.

## Editing

Right-click the Start button or the panel and choose **Edit...** to open the
form editor: a list of entries (submenus shown indented), a form on the right
(Type and System id are dropdowns), a **New in:** picker to choose which menu a
new entry lands in, **Update launcher** to apply live, and **Save to file...**
to persist. Because the app is file-backed, saved changes survive a restart.

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
    -launch '::launcherapp::main $argv' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -extlib /path/to/tklib/modules
```

Notes:

- `-launch '::launcherapp::main $argv'` -- always double-quote `-launch`; the
  argv0 guard in `launcher.tcl` does not fire inside a zipkit, so build-app
  starts the app through this call.
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

Ready-made configs to start from are in `examples/`. Point the app at one:

```bash
wish launcher.tcl examples/example-developer.json
```

- `example-developer.json` -- terminal/editor/file manager, Tcl/Tk docs, dev web
  links, a System submenu, calculator + calendar, a Projects shortcut.
- `example-office.json` -- documents, web mail/calendar links, a Printing
  submenu, calendar + calculator.
- `example-sysadmin.json` -- System / Network / Maintenance / Power submenus
  wired to the built-in system entries (task manager, services, firewall,
  updates, restart/shutdown, ...), plus terminal and file manager.
- `example-minimal.json` -- just terminal, file manager, calculator, calendar,
  Home. A clean starting point.

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
- `example-menu.json` a sample config you can pass on the command line
- `examples/`         ready-made menu templates (developer, office, sysadmin, minimal)
- `tests/`            a headless smoke test

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
  -launch '::launcherapp::main $argv' \
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
