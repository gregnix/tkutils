# Changelog

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
