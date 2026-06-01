# Roadmap

`tkutils` provides Tk GUI widgets on top of the pure-Tcl engines in
[`tclutils`](../tclutils-0.41.0/). See [`README.md`](README.md) for the full
widget catalogue and [`docs/architecture.md`](docs/architecture.md) for the
design.

## Shipped

- **20 core widgets** in the umbrella (`package require tkutils`):
  tkhexedit, tkcsv, tkdiff, tkmd, tkjson, tkcal, tkeditor, tkzip, tkfuzzy,
  tkbase64, tkstrings, tknotes, tkical, tkldif, tkini, tkvcard, plus the shared
  GUI helpers tkdialog, tkform, tktoolbar, tkstatus.
- **Editing** in the record viewers: tkini, tkvcard, tkldif, tkical, tknotes
  (programmatic ops + edit bars, `-editable 0` for read-only).
- **Optional widgets** (not in the umbrella, external dependency): tktablelist
  (Tablelist), tkxml (tDOM), tksqlite (sqlite3).
- README rewritten as a full widget catalogue; `tests/stack.test` exercises
  tclutils + tkutils together in one interpreter.

> The shared GUI helpers that the original roadmap listed for a future "0.5.0"
> (status bar, toolbar, dialog/search helpers) are all shipped.

## Planned

| Widget | Backend (tclutils) | Purpose |
|--------|--------------------|---------|
| `tkutils::odfinspect` | `tuodf`, `tuzip` | ODT/ODS/ODG container + XML preview |
| `tkutils::pdfinspect` | `tupdf` | PDF objects, trailer, metadata, ZUGFeRD |
| `tkutils::mdview` | `tumd` | headings, TOC and HTML preview (beyond `tkmd`) |

Possible later: `tklog` (log viewer on `tugrep` / `tutail -f`), `tkchart`
(simple charts from lists).

## Related

- Output/export bridges (text/csv/json/pdf/odf) are tracked on the tclutils
  side in [`../tclutils-0.41.0/docs/todo-output.md`](../tclutils-0.41.0/docs/todo-output.md).
- Widget conventions: [`CONVENTIONS.md`](CONVENTIONS.md).
