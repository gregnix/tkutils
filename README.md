# tkutils 0.30.0

`tkutils` is a collection of Tcl/Tk GUI widgets that sit on top of the pure-Tcl
engines in [`tclutils`](../tclutils-0.41.0/). It is intentionally separate from
`tclutils` so that console/server/CI use never requires `Tk`.

- **Rule:** the engine lives in `tclutils`, the GUI in `tkutils`. Each widget is
  a package `tkutils::tk<name>` (file `lib/tm/tkutils/tk<name>-0.1.tm`).
- **Tcl/Tk:** 8.6+ and 9.x. The umbrella package loads the **20 core widgets**;
  optional widgets that need external packages are not in the umbrella.

## Install / path setup

`tkutils` needs `tclutils` on the Tcl module path. Pick one:

```bash
# explicit (recommended for tests/CI)
export TCLUTILS_TM=/path/to/tclutils-0.41.0/lib/tm
export TKUTILS_TM=/path/to/tkutils-0.27.0/lib/tm

# or source the bootstrap (adds both libs, finds the highest version)
tclsh -e 'source /path/to/tkutils-0.27.0/tools/setup.tcl'
```

Then:

```tcl
package require tkutils            ;# loads all core widgets
package require tkutils::tknotes   ;# or a single widget
```

> Note: auto-discovery sorts sibling `tclutils-*` folders with
> `lsort -decreasing -dictionary` (version-aware), so the newest is chosen.

## Core widgets (in the umbrella)

| Widget | Engine (tclutils) | What it does |
|--------|-------------------|--------------|
| `tkhexedit` | tubin, tuhexdump | Hex editor: offset/hex/ASCII, open/save, goto, find, patch |
| `tkcsv`     | tucsv     | CSV viewer (treeview) |
| `tkdiff`    | tudiff    | Side-by-side text diff |
| `tkmd`      | tumd      | Markdown structure / TOC |
| `tkjson`    | tujson    | JSON tree (from `parseTyped`) |
| `tkcal`     | tucal     | Calendar text view |
| `tkeditor`  | common    | Text editor (context menu, undo/redo, search/replace, goto, read-only) |
| `tkzip`     | tuzip     | ZIP member tree |
| `tkfuzzy`   | tufuzzy   | Fuzzy search / best matches |
| `tkdialog`  | Tk        | message / confirm / warning / **form** dialogs |
| `tkbase64`  | tubase64  | Encode/decode panes |
| `tkstrings` | tustrings | Printable strings from binaries |
| `tktoolbar` | Tk        | Toolbar (buttons, separators) |
| `tkstatus`  | Tk        | Status bar (fields, flash) |
| `tknotes`   | tunotes   | Hierarchical notes (tree + editor, tags, expand/collapse, subtree export) |
| `tkform`    | Tk        | Declarative form (entry/combo/check/spin/text → dict) |
| `tkical`    | tuical    | iCalendar event viewer/**editor** |
| `tkldif`    | tuldif    | LDIF entry viewer/**editor** |
| `tkini`     | tuini     | INI viewer/**editor** (sections + key/value) |
| `tkvcard`   | tuvcard   | vCard contact viewer/**editor** |
| `tkdateentry`| Tk (clock)| Date entry with a drop-down calendar picker |
| `tktimeentry`| Tk        | Time entry (HH:MM[:SS]) with spinboxes |
| `tknumentry` | Tk        | Validated numeric entry (decimals, min/max) |
| `tktags`    | Tk        | Tag editor: removable chips + input (suggestions) |
| `tksearchbar`| Tk        | Debounced search bar + optional filter |
| `tktree`    | Tk        | ttk::treeview wrapper (load nested data, selection) |

`tkical`, `tkldif`, `tkini`, `tkvcard` accept `-editable 0` for a read-only view.

## Optional widgets (not in the umbrella)

| Widget | Needs | Notes |
|--------|-------|-------|
| `tkutils::tktablelist` | **Tablelist** (tklib) | Full editable/sortable table; CSV import/export; tests skip without Tablelist |
| `tkutils::tkxml`       | **tDOM**     | XML tree |
| `tkutils::tksqlite`    | **sqlite3**  | Lightweight DB browser |

These are pure-Tcl-engine-free GUIs that depend on an external package; on a
stack without that package they are simply not loaded (and their tests skip).

## Quick start

```bash
# a widget launcher
tclsh bin/tknotes.tcl
# a demo
tclsh examples/demo-tkical.tcl
```

There are **23 demos** under `examples/` and **23 launchers** under `bin/`.

## Tests

Each `tests/*.test` runs in its own interpreter; `tests/all.tcl` runs the suite.
`tests/stack.test` loads **tclutils + tkutils in one interpreter** and exercises
several widgets against their engines.

```bash
export TCLUTILS_TM=/path/to/tclutils-0.41.0/lib/tm
xvfb-run -a tclsh tests/all.tcl       # GUI tests need a display (Xvfb)
```

GUI tests use the `haveTk` constraint; widgets requiring Tablelist/tDOM/sqlite3
skip cleanly when those packages are absent.

## Dependency summary

`tkutils 0.28.0` works with `tclutils 0.35.0+` (editing helpers for
`tkini`/`tkvcard`/`tkical`/`tkldif`); `tknotes` subtree/tags need `tclutils
0.33.0+`. The recommended pairing is **tclutils 0.41.0 + tkutils 0.28.0**.

## License

MIT — see `LICENSE` (or the tclutils LICENSE for the shared stack).
