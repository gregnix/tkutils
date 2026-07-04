# postgresql-editor

A PostgreSQL database editor, browser and inspector — the PostgreSQL member of
the `sqledit` family. It reuses the **entire** GUI of `sqlite-editor`
(`sqledit-core` / `sqledit-form` / `sqledit-sheet`) unchanged and only swaps the
backend: instead of `be-sqlite.tcl` it loads **`be-postgres.tcl`**, which talks
to PostgreSQL directly through **`tdbc::postgres`**.

So the editor, the sortable result grid, the object browser, history, saved
queries, pagination, CSV/JSON export and the form view all behave exactly like
the SQLite edition — against a PostgreSQL server.

## Direct SQL vs. PostgREST

This editor uses **`tdbc::postgres`** (a direct SQL connection), like a small
DBeaver: arbitrary SQL, schema browsing, DDL. That is a **different layer** than
`tclutils::tupostgrest`, the REST client an *application* uses to reach a
PostgREST endpoint. PostgREST only exposes selected tables/views and cannot run
arbitrary SQL or introspect the catalog, so it is not the right tool for an
editor. Rule of thumb: **editor/admin → tdbc::postgres; app data access →
tupostgrest.**

## Requirements

- `tdbc::postgres` (the PostgreSQL TDBC driver).
- `tkutils` (`tkutoolbar`, `tkustatus`, `tkudialog`, `tkutablelist`) and
  `tclutils` (`tujson`, `tucsv`) on the module path — resolved by the shared
  `apps/_lib/paths.tcl` bootstrap.
- The sibling `apps/sqlite-editor/` directory, which holds the shared core.

## Run

```sh
wish postgresql-editor.tcl
```

A **Connect…** dialog asks for host / port / database / user / password. Leave
the password empty for `trust`/peer setups. After connecting, the object browser
fills with the tables, views, indexes, sequences, triggers and functions of the
user schemas (system schemas are hidden).

## Names and schemas

PostgreSQL has schemas, which SQLite does not. Objects are shown
**schema-qualified** as `schema.name`, except for the `public` schema, whose
objects are shown bare (`name`). The preview and DDL functions quote identifiers
and split the schema off again, so `sqledit_test.parent` and `documents` both
work.

## What the backend maps

`be-postgres.tcl` implements the same `::sqledit::be::*` contract as
`be-sqlite.tcl`:

| Concept | SQLite | PostgreSQL |
|---|---|---|
| run one statement | `db eval` | `tdbc prepare`/`execute` (columns, rows, rowcount) |
| bound params | `:name` via `db eval` | `:name` via `tdbc` (injection-safe) |
| object list | `sqlite_master` | `pg_tables` / `pg_views` / `pg_indexes` / `pg_sequences` / `information_schema.triggers` / `pg_proc` |
| columns / PK | `PRAGMA table_info` | `information_schema.columns` + PK join |
| foreign keys | `PRAGMA foreign_key_list` | `information_schema` constraint views |
| CREATE text | `sqlite_master.sql` | `pg_get_viewdef` / `pg_get_indexdef` / `pg_get_triggerdef` / `pg_get_functiondef`; tables reconstructed from the catalog |
| RLS policies | (n/a) | `pg_class.relrowsecurity` + `pg_policies` → `ENABLE/FORCE ROW LEVEL SECURITY` + `CREATE POLICY` appended to the table DDL |
| summary | `PRAGMA`s | `version()`, `pg_database_size`, `pg_encoding_to_char` |

One PostgreSQL-specific subtlety handled here: **`tdbc` represents a SQL `NULL`
by omitting the column from the row dict** — the backend reads nullable columns
defensively so a `NULL` default or length never crashes a lookup.

## Row-Level Security

`pg_get_*def()` does not cover **RLS policies**, so an editor that shows only the
plain `CREATE TABLE` would hide a table's real access rules. When you inspect a
table, the reconstructed DDL therefore appends its RLS state and policies from
the catalog (`pg_class.relrowsecurity` / `pg_policies`):

```sql
CREATE TABLE "api"."documents" ( ... );

ALTER TABLE "api"."documents" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "documents_select" ON "api"."documents"
    FOR SELECT
    USING ((classification <= api.dept_level()));
```

Each policy is rebuilt with its command (`FOR ALL/SELECT/…`), `AS RESTRICTIVE`
where applicable, the `TO role` list (omitted for `PUBLIC`), and the `USING` /
`WITH CHECK` expressions. Tables without RLS are unaffected — they show just the
`CREATE TABLE`. This makes the editor usable as an admin front end for an
RLS-based design such as the DMS.

## Semicolons and functions

`tdbc::postgres` uses prepared statements, and its tokenizer **rejects any `;`
it sees outside a `'...'` string — even a single trailing one** — and it does
**not** understand PostgreSQL dollar-quoting (`$tag$...$tag$`). That breaks the
two things a SQL editor does most: ending a statement with `;` and creating
functions/triggers.

The backend deals with it in two layers:

- **Statement splitter.** `run` splits the editor's text into individual
  statements on `;`, but respects `'...'` strings, `"..."` identifiers,
  `$tag$...$tag$` bodies, `--` line comments and nesting `/* */` block comments.
  Each statement is sent without its terminator, so a trailing `;` and whole
  scripts of several statements just work. The last statement's result set is
  shown (like SQLite's `db eval`); affected-row counts of DML are summed.
- **psql fallback.** A statement that still contains a `;` inside a
  dollar-quoted body (a function, trigger function or `DO` block) *cannot* go
  through `tdbc::postgres` at all. Such statements are run through the **`psql`**
  client, using the connection info from the Connect dialog. If `psql` is not on
  `PATH`, the editor reports a clear error instead of a cryptic tokenizer
  message. Everything else — including calling the function afterwards — goes
  through `tdbc` normally.

## Tests

`be_postgres.test` verifies the backend against a **live** PostgreSQL. The
connection comes from environment variables (defaults for a local trust
cluster):

```
PGEDIT_HOST=127.0.0.1  PGEDIT_PORT=5432  PGEDIT_DB=postgres
PGEDIT_USER=postgres   PGEDIT_PASSWORD=
```

The test creates an isolated `sqledit_test` schema, exercises the contract
(run / execParams / objects / columns / foreignKeys / schemaOf / previewSql /
summary) and drops the schema again. If no connection can be made, all tests
**skip** (constraint `pgdb`), so the suite is safe to run anywhere:

```sh
# against a local cluster on port 5432, database "postgres"
tclsh be_postgres.test
# or point it somewhere:
PGEDIT_PORT=5433 PGEDIT_DB=dmsdemo tclsh be_postgres.test
```

## Layout note

The shared UI (`sqledit-core` / `sqledit-form` / `sqledit-sheet`) lives in
`apps/sqlite-editor/`; this launcher sources it from there. The backend
(`be-postgres.tcl`) is the only file specific to this editor.
