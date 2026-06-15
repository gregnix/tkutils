# tkutils::tkutlstate

Save and restore a `tablelist`'s column layout — widths, hidden state, display
order and the active sort — so an application can persist how the user arranged
a table between sessions. Library-neutral.

## Package

```tcl
package require tkutils::tkutlstate 0.1
```

Requires `Tk` and `tablelist`.

## Commands

```tcl
::tkutils::tkutlstate::save            tbl          ;# -> state dict
::tkutils::tkutlstate::restore         tbl state
::tkutils::tkutlstate::saveToFile      tbl path
::tkutils::tkutlstate::restoreFromFile tbl path      ;# -> 1 applied, 0 missing
```

The state is a plain Tcl dict, e.g.

```
version 1 ncols 4 columns {{width 20 hide 0} ...} columnorder {...} \
    sortcolumn 1 sortorder decreasing
```

so it is safe to store as text, embed in a config, or convert to JSON.

## Usage

```tcl
package require Tk
package require tablelist
package require tkutils::tkutlstate

# on quit
::tkutils::tkutlstate::saveToFile .t [file join $cfgdir table.state]

# on start (after the table is built)
::tkutils::tkutlstate::restoreFromFile .t [file join $cfgdir table.state]
```

In-memory:

```tcl
set st [::tkutils::tkutlstate::save .t]
# ... later ...
::tkutils::tkutlstate::restore .t $st
```

## Notes

- `restore` only touches columns that exist in both the saved state and the
  current table, so it degrades gracefully when the table definition changed.
- `columnorder` is captured/applied when the tablelist build supports it
  (wrapped in `catch`).
- Save the state *after* the user is done arranging (e.g. on window close), not
  on every column resize.

## Error codes

`-errorcode {TKUTILS TKUTLSTATE STATE}` when given a non-state value.
