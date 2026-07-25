# tkutils 0.43.0

`tkutils` is a collection of Tcl/Tk GUI widgets that sit on top of the pure-Tcl
engines in [`tclutils`](https://github.com/gregnix/tclutils). It is intentionally separate from
`tclutils` so that console/server/CI use never requires `Tk`.

- **Rule:** the engine lives in `tclutils`, the GUI in `tkutils`. Each widget is
  a package `tkutils::tk<name>` (file `lib/tm/tkutils/tk<name>-0.1.tm`).
- **Tcl/Tk:** 8.6+ and 9.x. The umbrella package loads the **41 core widgets**;
  optional widgets that need external packages are not in the umbrella.

## Install / path setup

`tkutils` needs `tclutils` on the Tcl module path. Pick one:

```bash
# explicit (recommended for tests/CI)
export TCLUTILS_TM=/path/to/tclutils-0.61.0/lib/tm
export TKUTILS_TM=/path/to/tkutils-0.43.0/lib/tm

# or source the bootstrap (adds both libs, finds the highest version)
tclsh -e 'source /path/to/tkutils-0.43.0/tools/setup.tcl'
```

Then:

```tcl
package require tkutils            ;# loads all core widgets
package require tkutils::tkunotes   ;# or a single widget
```

> Note: auto-discovery sorts sibling `tclutils-*` folders with
> `lsort -decreasing -dictionary` (version-aware), so the newest is chosen.

## Core widgets (in the umbrella)

| Widget | Engine (tclutils) | What it does |
|--------|-------------------|--------------|
| `tkuhexedit` | tubin, tuhexdump | Hex editor: offset/hex/ASCII, open/save, goto, find, patch |
| `tkucsv`     | tucsv     | CSV viewer (treeview) |
| `tkudiff`    | tudiff    | Side-by-side text diff |
| `tkumd`      | tumd      | Markdown structure / TOC |
| `tkujson`    | tujson    | JSON tree (from `parseTyped`) |
| `tkucal`     | tucal     | Calendar text view |
| `tkueditor`  | tuiconv   | Text editor (toolbar, status bar, encoding/EOL, search/replace, undo/redo, goto, context menu) |
| `tkuzip`     | tuzip     | ZIP member tree |
| `tkufuzzy`   | tufuzzy   | Fuzzy search / best matches |
| `tkudialog`  | Tk        | message / confirm / warning / **form** dialogs |
| `tkubase64`  | tubase64  | Encode/decode panes |
| `tkustrings` | tustrings | Printable strings from binaries |
| `tkutoolbar` | Tk (tkuballoon) | Toolbar: buttons/toggles/dropdowns, icon/text/both, tooltips, shortcuts, optional action binding |
| `tkuballoon` | Tk        | Balloon help / tooltips for any widget (shared popup, hover delay) |
| `tkucontextmenu` | Tk    | Right-click context menus (command/check/radio/cascade, spec builder, standard edit) |
| `tkubind`    | Tk        | Platform key bindings (`Mod-` modifier), accelerators, isEditing guard, groups |
| `tkuaction`  | Tk        | Action abstraction: one action drives many widgets (enabled/checked/invoke) |
| `tkukeynav`  | Tk        | Keyboard focus navigation: Tab/Shift-Tab + Return-to-next-field form ergonomics |
| `tkulabeled` | Tk        | Labeled input composites (label + entry/combo/spin/check/text), `value` accessor |
| `tkuvalidate`| Tk, tuvalidate | Inline validation feedback (red field + tkuballoon message) using tuvalidate predicates |
| `tkumarquee` | Tk        | Rubber-band rectangle selection on a canvas (region crop/zoom/select), scroll-safe |
| `tkustatus`  | Tk        | Status bar (fields, flash) |
| `tkunotes`   | tunotes   | Hierarchical notes (tree + editor, tags, expand/collapse, subtree export) |
| `tkuform`    | Tk        | Declarative form (entry/combo/check/spin/text → dict) |
| `tkuical`    | tuical    | iCalendar event viewer/**editor** |
| `tkuldif`    | tuldif    | LDIF entry viewer/**editor** |
| `tkuini`     | tuini     | INI viewer/**editor** (sections + key/value) |
| `tkuvcard`   | tuvcard   | vCard contact viewer/**editor** |
| `tkudateentry`| Tk (clock)| Date entry with a drop-down calendar picker |
| `tkutimeentry`| Tk        | Time entry (HH:MM[:SS]) with spinboxes |
| `tkunumentry` | Tk        | Validated numeric entry (decimals, min/max) |
| `tkutags`    | Tk        | Tag editor: removable chips + input (suggestions) |
| `tkusearchbar`| Tk        | Debounced search bar + optional filter |
| `tkufilterbar`| Tk        | Per-column filter bar (one entry per column, ANDed substrings) |
| `tkutree`    | Tk        | ttk::treeview wrapper (load nested data, selection) |
| `tkufiletree`| Tk        | lazy file-system tree (filter, activate-to-open) on tkutree |
| `tkuimage`   | Tk (imgtools opt.) | image fit/scale/thumbnail + zoom/scroll viewer |
| `tkutodo`    | tuical    | iCalendar VTODO task list (toggle done, due/priority/%) |
| `tkudavbrowser` | tudav  | read-only CalDAV/CardDAV collection browser (grouped, selection callback) |
| `tkudavaccount`| tudav   | DAV account form + connection test (PROPFIND) |

`tkuical`, `tkuldif`, `tkuini`, `tkuvcard` accept `-editable 0` for a read-only view.

## Optional widgets (not in the umbrella)

| Widget | Needs | Notes |
|--------|-------|-------|
| `tkutils::tkutablelist` | **Tablelist** (tklib) | Full editable/sortable table; CSV import/export; tests skip without Tablelist |
| `tkutils::tkuxml`       | **tDOM**     | XML tree |
| `tkutils::tkusqlite`    | **sqlite3**  | Lightweight DB browser |
| `tkutils::tkuwinico` | `tclutils::tuico` | Build Windows `.ico` files from Tk images: each size rendered from SVG, or scaled from a photo; transparency preserved |
| `tkutils::tkucanvaspng` | `tclutils::tupngdraw` (Glyphs for `-fontmap`) | Export a live Tk canvas to PNG: lines (arrows/dashes), shapes, elliptical arcs, text, images |
| `tkutils::tkutical` | **tical** (`tical::view::month` + `tical::render::canvas`) | Month calendar on a canvas: prev/next/today, week numbers, day selection (none/single/multiple, Shift-click ranges), `-command` |
| `tkutils::tkumonthcanvas` | **tical** | Canvas calendar (month/quarter/year): themes, week numbers, weekday header, today/weekend/holiday/note states, day selection (none/single/multiple) |
| `tkutils::tkuicon` | **tksvg** (Tk 8.6) / native SVG (Tk 9) | SVG/PNG icon loader; generates the icon set from `tclutils::tusvg`; HiDPI rescale, cache |
| `tkutils::tkuscrolledframe` | **scrollutil** (tklib) | Scrollable frame container (pack content into `content`); thin scrollutil wrapper |

These are pure-Tcl-engine-free GUIs that depend on an external package; on a
stack without that package they are simply not loaded (and their tests skip).

## Quick start

```bash
# a widget launcher
tclsh bin/tkunotes.tcl
# a demo
tclsh examples/demo-tkuical.tcl
```

There are **38 demos** under `examples/` and **24 launchers** under `bin/`.

## Tests

Each `tests/*.test` runs in its own interpreter; `tests/all.tcl` runs the suite.
`tests/stack.test` loads **tclutils + tkutils in one interpreter** and exercises
several widgets against their engines.

```bash
export TCLUTILS_TM=/path/to/tclutils-0.61.0/lib/tm
xvfb-run -a tclsh tests/all.tcl       # GUI tests need a display (Xvfb)
```

GUI tests use the `haveTk` constraint; widgets requiring Tablelist/tDOM/sqlite3
skip cleanly when those packages are absent.

## Dependency summary

`tkutils 0.43.0` pairs with `tclutils 0.61.0`. The editing helpers
(`tkuini`/`tkuvcard`/`tkuical`/`tkuldif`) and `tkunotes` subtree/tags build on the
`tclutils` engines, so a current `tclutils` is required alongside. The recommended
pairing is **tclutils 0.61.0 + tkutils 0.43.0**.

`tkuwinico` in particular needs **tclutils 0.61.0 or newer**: it builds on
`tclutils::tuico`, which arrived with that release. An older tclutils on the
module path fails at `package require`, not at build time.

## License

MIT — see `LICENSE` (or the tclutils LICENSE for the shared stack).
