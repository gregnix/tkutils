# knowledge-base -- durable, searchable Tcl/Tk knowledge store

Replaces the per-session `wissen.md` with a database: categorised, tagged,
full-text-searchable knowledge entries (markdown), on **SQLite** (FTS5) or
**PostgreSQL** (tsvector). Built almost entirely from tclutils/tkutils means.

Status: **Phase 1-3 complete** -- data layer, full-text search, the wissen-md
importer, and the Tk GUI, all dual-verified on Tcl 8.6 and 9.0.

## Pieces

| File | Role |
|------|------|
| `kb-store.tcl` | data layer: schema, CRUD, tags, full-text search (`::kb::store::*`) |
| `kb-import.tcl` | import a `wissen-*.md` into the store (`::kb::import::*`) |
| `kb-export.tcl` | export the store back to markdown (`::kb::export::*`) |
| `examples/wissen-tcltk.md` | a curated Tcl/Tk dataset (34 entries, hierarchical categories + explicit tags) |
| `knowledge-base.tcl` | the Tk GUI (`::kbgui::*`) -- run with `wish knowledge-base.tcl ?dbfile?` |
| `tests/kb-store.test` | 28 tests (SQLite/FTS5) |
| `tests/kb-import.test` | 11 tests |
| `tests/kb-export.test` | 4 tests |
| `tests/kb-gui.test` | 37 GUI tests (xvfb) |

Reusable byproduct (in tclutils): **`tclutils::tutdbc`** -- NULL-safe TDBC
helpers (the tdbc analogue of `tusqlite`), used by this store and by the
`be-tdbc` editor backend.

## GUI

```
wish knowledge-base.tcl ?dbfile?     # default: ~/.local/share/knowledge-base/wissen.db
```

Assembled entirely from tkutils widgets, wired to the `kb-store` API:

- `tkusearchbar` -- full-text search box; searches globally or within the
  selected category.
- **Tag filter** (multi-select list under the tree): pick one or more tags with
  an **alle/eine** (AND/OR) toggle. Combines with the search text and the
  category scope; × clears the selection.
- `tkutltree` -- **hierarchical** category tree (left); selecting a parent lists
  the entries of all its subcategories (recursive). "Alle" resets it,
  The tree is **multi-select** (Ctrl/Shift) so several categories can be deleted
  at once via the context menu. "Verschieben…" re-parents the selected category
  under another. You can also
  **drag** a category onto another to re-parent it, or onto empty space to move
  it to the top level. The drop target is highlighted while dragging; cycles and
  no-op moves (already under that parent) are rejected with a clear message.
  **Right-click** a category for a context menu: new subcategory, rename, move,
  delete (deleting re-parents its children and entries to its parent).
- `tkutablelist` -- entry / result list (top right).
- `tkumdview` -- markdown preview of the selected entry (TOC pane hidden), with
  a tags line below.
- `tkueditor` -- the add/edit dialog's **markdown editor**: a formatting toolbar
  (bold/italic/code/H1/H2/list/link) plus a live `tkumdview` preview beside it.

The entry list is **multi-select** (Ctrl/Shift); **Loeschen** removes every
selected entry at once. **Right-click** an entry for a context menu (new / edit /
delete); right-clicking within a multi-selection keeps it.
New/Bearbeiten/Loeschen manage entries; **Import…** loads a `wissen-*.md`, **Export…** writes the whole store back
to markdown (round-trippable). The category combo accepts a
"Bereich / Thema / ..." **path** and creates any missing levels on save. Every
change refreshes the list and the FTS index.

## Data model

```
category(id, name, parent_id, sort)          -- self-referential hierarchy
entry(id, title, body, category_id, source, created, updated)
tag(id, name)   entry_tag(entry_id, tag_id)  -- many-to-many
```

Categories nest via `parent_id`; `categoryEntries` walks the tree with a
portable `WITH RECURSIVE`, so a parent lists all descendant entries.
`categoryMove` re-parents a category (guarded against cycles).
Portable CRUD runs through `tclutils::tutdbc`. Only the schema DDL and the
full-text search are backend-specific:

- **SQLite:** FTS5 external-content table `entry_fts` + sync triggers;
  `entry_fts MATCH :q`, ranked, with `snippet()`.
- **PostgreSQL:** a `tsvector` column kept current by a trigger + GIN index;
  `websearch_to_tsquery('german', :q)`, ranked by `ts_rank`, with `ts_headline`.

## Usage

```tcl
package require tdbc::sqlite3            ;# or tdbc::postgres
source kb-store.tcl
source kb-import.tcl

set s [::kb::store::openSqlite ~/.local/share/wissen.db]

# import a curated dataset. ## headings may carry a [Bereich/Thema] prefix that
# becomes a hierarchical category; a "Tags: a, b, c" line per section sets the
# tags explicitly (else they are guessed from `inline-code` spans).
::kb::import::file $s examples/wissen-tcltk.md tcltk

# export the store back to markdown (same format -> round-trips)
::kb::export::file $s wissen-out.md

# search
foreach r [::kb::store::search $s "monospace" -category $catId] {
    puts "[dict get $r title]: [dict get $r snippet]"
}
::kb::store::close $s
```

PostgreSQL opens the same way via `::kb::store::openPostgres` with the usual
tdbc connection args; connection profiles come from the shared
`sqledit-conn.tcl` store.

## Known driver quirks handled here

- tdbc::sqlite3's incremental `nextlist` cursor returns **no rows** for
  FTS5/virtual-table queries; `tutdbc::rows` therefore uses `allrows` and
  re-pads NULL columns from `$rs columns`, which works for both plain and FTS
  queries while staying NULL-safe.
- A `0` value stays `0`, distinct from NULL, on insert (bind vs. omit).

## Still to come

- **PostgreSQL** live verification (schema/FTS coded, untested without a server).
- **PDF book export** (docir + mdstack `book-build`): TOC + subject index from
  the tags, plus `wissen.md` / `uebergabe.md` regeneration from the DB.
- Backlog/uebergabe as a second entity (status open/done).
- Tag-heuristic refinement (the backtick importer still yields some noise).

## Requirements

- Tcl 8.6+ (verified 8.6.14 and 9.0.2)
- `tclutils::tutdbc` (+ `tclutils::common`)
- tkutils widgets: tkusearchbar, tkutltree, tkutablelist, tkumdview, tkueditor
- `tdbc::sqlite3` (SQLite, with FTS5) and/or `tdbc::postgres` (PostgreSQL)
