# oracle-editor

An Oracle database editor, browser and inspector — the Oracle member of the
`sqledit` family. It reuses the **entire** GUI of `sqlite-editor`
(`sqledit-core` / `sqledit-form` / `sqledit-sheet`) unchanged and only swaps the
backend: instead of `be-sqlite.tcl` it loads **`be-oracle.tcl`**, which talks to
Oracle directly through **Oratcl** (the OCI binding).

So the editor, the sortable result grid, the object browser, history, saved
queries, pagination, CSV/JSON export and the form view all behave exactly like
the SQLite and PostgreSQL editions — against an Oracle server.

## Why Oratcl (and not tdbc)

Oracle has two Tcl interfaces: **Oratcl** (the direct OCI binding) and
`tdbc::oracle`. This editor uses Oratcl, because it is the more widely used and
better-supported path in practice; the `be-oracle.tcl` backend hides Oratcl's
`ora*` API behind the same `::sqledit::be::*` contract the other backends
implement, so the shared GUI never sees the difference.

## Requirements

- **Oratcl** with a working **Oracle Instant Client** (`libclntsh.so` on Linux,
  `oci.dll` on Windows). Oratcl 4.6+ works on Tcl 8.6 and Tcl 9.
- `tkutils` (`tkutoolbar`, `tkustatus`, `tkudialog`, `tkutablelist`) and
  `tclutils` (`tujson`, `tucsv`) on the module path — resolved by the shared
  `apps/_lib/paths.tcl` bootstrap.
- The sibling `apps/sqlite-editor/` directory, which holds the shared core.

### Instant Client

The launcher runs `oratcl-bootstrap.tcl` **before** loading Oratcl. It:

- locates the Instant Client (known paths, e.g. `/opt/oracle/instantclient_*`
  on Linux, `C:\app\instantclient_*` on Windows);
- sets `ORACLE_LIBRARY` (Linux) or prepends the client dir to `PATH` (Windows);
- sets a default `NLS_LANG` (`GERMAN_GERMANY.AL32UTF8` / `…WE8MSWIN1252`).

**Explicitly-set `ORACLE_LIBRARY` / `NLS_LANG` win and are never overwritten** —
export them yourself for a non-standard client location or character set.

On Windows, if `oci.dll` fails to load with *error 126*, install the
**Microsoft VC++ Redistributable (VS2013)** — a known Instant-Client dependency.

Check the environment without starting the GUI:

```sh
tclsh oracle-editor.tcl --check
```

This prints the detected client, `ORACLE_LIBRARY`/`NLS_LANG`, whether Oratcl
loads, and the `orainfo` version/client dump.

## Run

```sh
wish oracle-editor.tcl
```

A **Connect…** dialog asks for a **connect string** plus user and password. The
connect string may be:

- **EZCONNECT**: `host:1521/XEPDB1` (no `tnsnames.ora` needed);
- a **TNS alias**: `XEPDB1` (resolved from `tnsnames.ora`);
- a full **DESCRIPTION**: `(DESCRIPTION=(ADDRESS=…)(CONNECT_DATA=…))`.

After connecting, the object browser fills with the tables, views, indexes,
sequences, triggers and functions of the **current schema**
(`USER_*` catalog views).

## Session conventions

The backend pins each session so the shared GUI sees stable values regardless of
the server's locale, and opens every statement handle the same way:

- `NLS_DATE_FORMAT = 'YYYY-MM-DD'`, `NLS_TIMESTAMP_FORMAT`, and
  `NLS_NUMERIC_CHARACTERS = '.,'` are set at connect;
- every statement handle gets `oraconfig utfmode 1` (Tcl 9 stability) and
  `oraconfig nullvalue ""` (NULL becomes the empty string for every type,
  matching the sqlite/postgres backends);
- pagination uses the `ROWNUM` subquery, not `LIMIT`;
- binds go through `oraparse` + `orabind` (`:name`), never string splicing.

## Names

Oracle stores unquoted identifiers in **UPPERCASE**, so objects appear uppercase
(`EMP`, `DEPTNO`). There is no schema qualification — the editor works in the
connected user's schema via the `USER_*` views.

## Multi-statement scripts and PL/SQL

`run` splits a script on `;`, respecting `'…'` strings, `"…"` quoted identifiers
and `--` / `/* */` comments. A **PL/SQL block** (`DECLARE` / `BEGIN` /
`CREATE … PROCEDURE|FUNCTION|TRIGGER|PACKAGE|TYPE`) keeps its inner `;` and is
submitted whole when terminated by a lone **`/`** on its own line (the SQL\*Plus
rule).

## What the backend maps

`be-oracle.tcl` implements the same `::sqledit::be::*` contract as
`be-sqlite.tcl` and `be-postgres.tcl`:

| Concept | SQLite | Oracle (Oratcl) |
|---|---|---|
| run one statement | `db eval` | `oraparse`/`oraexec` (+ `oracols`/`orafetch`) |
| affected rows | `db changes` | `oramsg $sh rows` |
| bound params | `:name` | `:name` via `orabind` (injection-safe) |
| object list | `sqlite_master` | `USER_TABLES` / `USER_VIEWS` / `USER_INDEXES` / `USER_SEQUENCES` / `USER_TRIGGERS` / `USER_OBJECTS` |
| columns / PK | `PRAGMA table_info` | `USER_TAB_COLUMNS` + `USER_CONSTRAINTS` (type `P`) |
| foreign keys | `PRAGMA foreign_key_list` | `USER_CONSTRAINTS` (type `R`) + `USER_CONS_COLUMNS` |
| table DDL | `sqlite_master.sql` | reconstructed from columns + PK + FK |
| view / trigger DDL | `sqlite_master.sql` | `USER_VIEWS.text` / `USER_TRIGGERS` (LONG — see note) |
| function DDL | — | `USER_SOURCE` (line by line) |
| pagination | `LIMIT` | `ROWNUM` subquery |

### LONG note

`USER_VIEWS.text` and `USER_TRIGGERS.trigger_body` are Oracle **LONG** columns.
Tables, indexes and sequences are reconstructed from the catalog (no LONG), and
functions/procedures are read from `USER_SOURCE` (VARCHAR2 lines, no LONG). For
views and triggers the backend raises the LONG fetch size when opening a
statement handle (trying the known `oraconfig` option names in a `catch`), so
long definitions come back whole. If your Oratcl build uses a different option
name and a very long view still truncates, tell the maintainer the exact
`oraconfig` LONG option and it will be set explicitly.

## Files

- `oracle-editor.tcl` — launcher (Instant-Client bootstrap + shared GUI).
- `be-oracle.tcl` — the Oracle backend (the only Oracle-specific logic).
- `oratcl-bootstrap.tcl` — Instant-Client detection / environment setup.
- shared core comes from `../sqlite-editor/`.
