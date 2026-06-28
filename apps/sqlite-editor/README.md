# sqlite-editor

A SQLite database editor, browser and inspector built on the **tkutils** widget
family (`tkutoolbar`, `tkustatus`, `tkudialog`) plus `ttk` (notebook, treeview).

It is the first member of a planned family of database editors (sqlite /
postgresql / oracle) that share one UI behind a thin backend boundary: every
SQLite-specific query lives in `::sqledit::be::*`, so a PostgreSQL (tdbc) or
Oracle (oratcl) backend can later be dropped in behind the same procs.

## Features
- **Editor** -- free-form SQL with **F5** / *Execute*; results in a sortable
  grid (`tkutils::tkutablelist`): click a column header to sort, click again to
  reverse. Numeric columns sort by value and are right-aligned.
- **Filter** -- a search bar above the result grid filters the shown rows live.
  Several space-separated terms are ANDed (a row must contain *all* of them);
  the drop-down scopes the search to a single column or to all cells. Clearing
  the box restores every row.
- **Browser** -- object tree of tables / views / indexes / triggers /
  sequences; double-click a table or view to browse its rows.
- **Information** -- per-object details (columns, PK/NOT NULL, CREATE text) and
  a database summary (version, encoding, size, object counts).
- **History** -- every executed statement with time and status; double-click to
  reload it into the editor.
- **Saved queries** -- the *Queries* menu saves the current SQL under a name,
  reloads it later, or deletes it. The store is JSON (via `tclutils::tujson`) in
  a per-user config file; override the path with the `SQLEDIT_QUERIES`
  environment variable.
- **Pagination** -- the result is shown one page at a time (*Rows/page*:
  50/100/200/500/1000/All) with first/prev/next/last navigation and a
  "page X / Y (N rows)" indicator. Filtering and header-click sorting apply to
  the whole result, so a sort is correct across page boundaries, not just within
  the visible page.
- **Max rows** -- an optional fetch cap (0 = unlimited) stops reading a large
  result early, so huge tables do not have to be pulled into memory in full; a
  capped result is flagged in the status line and history.
- **Export result** as CSV (`tclutils::tucsv`), text (`tclutils::tutable`), or
  JSON (`tclutils::tujson`; an array of row objects, numeric cells as numbers).
- **Import CSV** (`tclutils::tucsv`) -- *File &gt; Import CSV...* loads a file
  into a table: an existing table is appended to (the CSV columns must be a
  subset of its columns), otherwise a new all-TEXT table is created from the
  header. Rows are inserted with bound parameters inside one transaction.
- **Export schema** -- the full set of CREATE statements as a runnable `.sql`.
- **Open URLs** -- for columns whose name contains `url` (e.g. `name_url`,
  `club_url`) the form shows an *"Open in browser"* button per such column, and
  the datasheet offers a right-click *"Open in browser"* entry; both open the
  cell's URL in the system browser (`xdg-open` / `open` / `start`). The button /
  menu entry is enabled only when the current cell holds an `http(s)://` value.

## Requirements
- Tcl/Tk 8.6+ or 9.x
- the external **sqlite3** package (tclsqlite)
- the **Tablelist** package (`tablelist_tile`), used by the sortable result grid
- **tkutils** and **tclutils** as sibling directories (or via the
  `TKUTILS_TM` / `TCLUTILS_TM` environment variables)

## Run
```
wish sqlite-editor.tcl ?database.db?
```

## Headless / testing
The whole data and introspection layer is dialog-free
(`::sqledit::_*`, backend `::sqledit::be::*`): `_open`, `_run` (returns
`{columns rows changes}`), `_objects type`, `_columns`, `_schemaOf`, `_info`,
`_schemaDump`, `_history*`, `_export{Csv,Text,Json,Schema}`.

The `tcltest` files live in the repository root and are run individually
(there is no aggregator script). `sqlite_editor.test` is Tk-free and runs under
`tclsh`; the form, datasheet and result-grid suites drive Tk widgets, so run
them under a display, e.g. `xvfb-run`:

```sh
tclsh sqlite_editor.test               # data + introspection layer (no Tk)
xvfb-run -a wish sqledit_form.test     # form widget    (needs Tk)
xvfb-run -a wish sqledit_sheet.test    # datasheet      (needs Tk)
xvfb-run -a wish sqledit_result.test   # sortable grid + filter (needs Tk + Tablelist)
xvfb-run -a wish sqledit_queries.test  # saved-queries menu     (needs Tk + Tablelist)
```

If `tkutils` / `tclutils` are not siblings, prefix the commands with
`TKUTILS_TM=/path/tkutils/lib/tm TCLUTILS_TM=/path/tclutils/lib/tm`.

Generate a sample database with `tclsh make-demo.tcl`.
