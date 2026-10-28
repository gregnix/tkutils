# tkutils::tkutlstate

Save and restore a `tablelist`'s column layout — widths, hidden state, display
order and the active sort — so an application can persist how the user arranged
a table between sessions. Library-neutral.

## Package

```tcl
package require tkutils::tkutlstate 0.4
```

Requires `Tk` and `tablelist`.

## Commands

```tcl
::tkutils::tkutlstate::save            tbl          ;# -> state dict
::tkutils::tkutlstate::restore         tbl state
::tkutils::tkutlstate::saveToFile      tbl path
::tkutils::tkutlstate::restoreFromFile tbl path      ;# -> 1 applied, 0 missing
::tkutils::tkutlstate::saveVia         tbl key setPrefix   ;# {*}$setPrefix key dict
::tkutils::tkutlstate::restoreVia      tbl key getPrefix   ;# -> 1 applied, 0 missing
::tkutils::tkutlstate::autosave        tbl key setPrefix ?-delay ms?
::tkutils::tkutlstate::cancelAutosave  tbl
```

`tbl` is a raw tablelist. For a `tkutils::tkutablelist` wrapper, pass
`[tkutils::tkutablelist::tableWidget $w]`.

`saveVia`/`restoreVia` are **storage-neutral**: you inject a setter/getter
command *prefix* and the module appends the key (and, for the setter, the state
dict). They work against a file, an array, or a database settings table without
the module knowing the backend. `autosave` persists automatically -- debounced
-- whenever the user resizes, moves, hides or sorts a column.

The state is a plain Tcl dict, e.g.

```
version 2 ncols 3 columns {{id name width 20 hide 0} {id #Size ...} ...} \
    sort {columns {name} orders {increasing}}
```

`columns` lists the columns in display order. Each column is identified by
its `-name`, or by `#` plus its title when it has no name; width and hidden
state follow the column, not its index. `sort` holds all sort columns
(multi-column sort included).

so it is safe to store as text, embed in a config, or convert to JSON.

## Usage

```tcl
package require Tk
package require tablelist_tile
package require tkutils::tkutlstate

# on quit
::tkutils::tkutlstate::saveToFile .t [file join $cfgdir table.state]

# on start (after the table is built)
::tkutils::tkutlstate::restoreFromFile .t [file join $cfgdir table.state]
```

### Persist to a database settings table (autosave)

Given a settings store with `settingSet db key value` / `settingGet db key`:

```tcl
set raw [::tkutils::tkutablelist::tableWidget $w]

# on open, after the table is built and filled:
::tkutils::tkutlstate::restoreVia $raw overview \
    [list ::app::store::settingGet $db]
::tkutils::tkutlstate::autosave   $raw overview \
    [list ::app::store::settingSet $db]
```

Column widths and order are then written back (debounced) as the user adjusts
them, and reapplied next time the table opens. `cancelAutosave $raw` stops it.

### In-memory

```tcl
set st [::tkutils::tkutlstate::save .t]
# ... later ...
::tkutils::tkutlstate::restore .t $st
```

## Notes

- `restore` only touches columns that exist in both the saved state and the
  current table, so it degrades gracefully when the table definition changed.
- Give columns a `-name` so a renamed title does not lose its width.
- Version-1 states (saved by 0.1–0.3, index based) are still restored.
- Save the state *after* the user is done arranging (e.g. on window close), not
  on every column resize.

## Error codes

`-errorcode {TKUTILS TKUTLSTATE STATE}` when given a non-state value.
