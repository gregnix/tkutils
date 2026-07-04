# Changelog

## 0.42.1

- README updated to 0.42.0 / 41 core widgets; recommended pairing is now
  tclutils 0.59.0 + tkutils 0.42.0.
- Restored `tests/stack.test` (loads tclutils + tkutils in one interpreter and
  exercises a widget against its engine); referenced in the README but the file
  had been missing.
- `tkudhash` added to the umbrella and given a man page.

## 0.42.0

Changes since 0.41.0.

- `tkuwheel` 0.2: new `-dynamic 0|1` option for `redirect`. With `-dynamic 1` a
  `<Configure>` hook on the root re-applies the wheel binding (coalesced via
  `after idle`) to descendants that are **added after the call** -- e.g. a
  designer palette whose tool buttons are created at runtime. `unbind` stops the
  dynamic re-application.
- `tkuwheel` 0.2: horizontal tilt-wheel support on X11. `-orient x` and
  `-orient both` now also bind `<Button-6>`/`<Button-7>` (Tk 8.7+; wrapped in
  `catch`, so Tk 8.6 skips them cleanly). The 0.1 API is unchanged; existing
  calls behave exactly as before. Tests 17 total (16 + 1 tilt-skip on 8.6).

## 0.41.0

Changes since 0.40.0.

- `tkueditor` 0.2: optional toolbar (`tkutoolbar` + `tkuicon` icons, with a text
  fallback when SVG is unavailable) carrying Open, Save, Undo, Redo, Cut, Copy
  and a find box, and an optional status bar (`tkustatus`) showing the modified
  flag, encoding, line-ending style and Ln/Col. Both default on; turn them off
  with `-toolbar 0` / `-statusbar 0`.
- `tkueditor` encoding-aware load/save via `tclutils::tuiconv` (default utf-8,
  so a document behaves identically under Tcl 8.6 and 9.x). Line endings are
  detected on load, normalised to LF in the buffer and restored on save.
- `tkueditor` new API (the 0.1 API is unchanged): `-toolbar`, `-statusbar`,
  `-encoding`, `-eol` options plus `encoding`, `eol`, `toolbarWidget`,
  `statusbarWidget`, `setStatus`, `refreshStatus`. The toolbar's Undo/Redo and
  Cut/Copy follow the undo stack and the selection; loading a file leaves the
  cursor at the start. The `bin/tkueditor.tcl` launcher now uses the built-in
  toolbar and status bar and keeps its find/replace bar.

## 0.40.0

Changes since 0.28.0. The widget set grew substantially and the original core
widgets were renamed to the `tku*` prefix for namespace hygiene. Runs on Tk 8.6
and Tk 9.x.

- Prefix rename: the initial core widgets `tk*` were renamed to `tku*`
  (`tkhexedit` -> `tkuhexedit`, `tkform` -> `tkuform`, `tktoolbar` ->
  `tkutoolbar`, etc.). The umbrella now lists 39 widgets.
- Shared GUI helpers / behaviours: `tkuaction` (action objects + accelerators),
  `tkuballoon` (tooltips), `tkubind` (binding helpers), `tkucontextmenu`,
  `tkukeynav` (keyboard navigation), `tkumarquee` (canvas rubber-band select),
  `tkulabeled`, `tkuvalidate`, `tkutree`.
- New widgets: `tkufilterbar`, `tkusearchbar`, `tkutags`, `tkutodo`, and the
  entry widgets `tkudateentry`, `tkutimeentry`, `tkunumentry`.
- WebDAV widgets: `tkudavaccount`, `tkudavbrowser`.
- `tkutoolbar` 0.2 (action integration, tooltip delegation to `tkuballoon`).
- `tkuimage` 0.2: image viewer widget with `view`, fit/zoom, `zoomLevel` and a
  `-onchange` callback; lazy imgtools detection and display-size clamping.
- Optional widgets (not in the umbrella, external dependency or specialised):
  `tkcanvaspng`, `tkmonthcanvas`, `tkuicon` (tksvg), `tkuscrolledframe`
  (scrollutil), `tkusqlite` (sqlite3), `tkutablelist` (Tablelist), `tkutical`,
  `tkuxml` (tDOM).
- Per-module `test` / `doc` / `man`; `tcltest` suite green on Tk 8.6 and Tk 9.x
  (optional widgets skip cleanly when their dependency is absent).
- Recommended pairing: tclutils 0.53.0 + tkutils 0.40.0.

## 0.28.0

Initial public release.

- Tk GUI widgets built on the pure-Tcl engines in `tclutils`; kept separate so
  console/server/CI use never requires Tk. Runs on Tk 8.6 and Tk 9.x.
- 20 core widgets in the umbrella package: tkhexedit, tkcsv, tkdiff, tkmd,
  tkjson, tkcal, tkeditor, tkzip, tkfuzzy, tkbase64, tkstrings, tknotes, tkical,
  tkldif, tkini, tkvcard, plus the shared GUI helpers tkdialog, tkform,
  tktoolbar, tkstatus.
- Editing in the record viewers (tkini, tkvcard, tkldif, tkical, tknotes) with
  `-editable 0` for read-only use.
- Optional widgets (not in the umbrella, external dependency): tktablelist
  (Tablelist), tkxml (tDOM), tksqlite (sqlite3).
- README widget catalogue, per-widget docs and man pages, runnable demos and
  CLI launchers.
- `tcltest` suite including `tests/stack.test` (tclutils + tkutils in one
  interpreter); green on Tk 8.6 and Tk 9.x (optional widgets skip cleanly when
  their dependency is absent).
- Recommended pairing: tclutils 0.41.0 + tkutils 0.28.0.
