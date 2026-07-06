# tdbc-sqlite-editor -- SQLite editor over TDBC

A variant of the sqledit editor family that talks to SQLite through
**`tdbc::sqlite3`** instead of the bare `sqlite3` command. The GUI is the
shared `sqledit-core` / `sqledit-form` / `sqledit-sheet` from the sibling
`sqlite-editor/` directory, reused unchanged -- only the backend differs.

```
wish tdbc-sqlite-editor.tcl
```

## Why a second SQLite backend

It is the reference **TDBC** backend for the family: the same `be-tdbc.tcl`
shape works for `tdbc::postgres` / `tdbc::mysql` by swapping the driver and the
introspection SQL. It is intentionally **self-contained** -- no dependency on
the `tdbutils` framework -- so it can be verified in isolation.

## The two TDBC pitfalls, handled here

- **Macke 1 -- `allrows -as dicts` drops NULL columns.** Result grids are built
  from `$rs columns` + `$rs nextlist` (not `-as dicts`), so every column
  survives and NULL comes through as an empty string, correctly aligned.
- **Macke 2 -- a bind dict missing a key binds SQL NULL.** That is exactly what
  the form view wants for INSERT/UPDATE, so `execParams` passes the params dict
  straight through. A real `0` is stored as `0`, distinct from NULL.

## Known limitation

`tdbc::sqlite3` does not expose column names for a **zero-row** result set
(unlike the bare `sqlite3` `A(*)` fallback in `be-sqlite.tcl`). An empty SELECT
therefore yields no headers -- rows are correctly empty. Table browsing of a
non-empty table is unaffected; column metadata for the form/browser comes from
`PRAGMA table_info`. If empty-table headers are wanted, the driver's
`$stmt getDBhandle` escape hatch can supply them, at the cost of a native
sqlite3 touch.

## Files

- `be-tdbc.tcl` -- the `::sqledit::be::*` backend (TDBC, self-contained)
- `tdbc-sqlite-editor.tcl` -- launcher (sources the shared core + this backend)
- `be_tdbc.test` -- Tk-free backend contract tests (15, NULL-focused)
- `tdbc_editor.test` -- GUI smoke test (4, end-to-end via the shared grid)

## Requirements

- Tcl 8.6+ (verified on 8.6.14 and 9.0.2)
- `tdbc::sqlite3`
- Tk + tkutils (for the GUI; the backend tests are Tk-free)
