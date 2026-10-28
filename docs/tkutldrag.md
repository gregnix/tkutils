# tkutils::tkutldrag

Let the user reorder `tablelist` rows with the mouse and get a callback
after each move. Wraps tablelist's `-movablerows`. Library-neutral.

## Package

```tcl
package require tkutils::tkutldrag 0.1
```

Requires `Tk` and `tablelist`.

## Commands

```tcl
::tkutils::tkutldrag::enable  tbl ?options?   ;# -> select mode now in use
::tkutils::tkutldrag::disable tbl
::tkutils::tkutldrag::order   tbl ?parent?    ;# -> ids of the children of parent
```

`order` returns the row ids (`-name`) of the children of `parent` (default
`root`) in display order; rows without a name give their key. Store it to
keep a user-defined order.

## Options

| Option         | Default | Meaning                                               |
|----------------|---------|-------------------------------------------------------|
| `-command`     | `{}`    | called after a move as `cmd tbl id parent position`  |
| `-samelevel`   | `1`     | only reorder among siblings, never a new parent      |
| `-acceptchild` | `{}`    | own `-acceptchildcommand` (overrides `-samelevel`)   |
| `-acceptdrop`  | `{}`    | own `-acceptdropcommand` (overrides `-samelevel`)    |

## Usage

```tcl
package require Tk
package require tablelist_tile
package require tkutils::tkutldrag

proc moved {tbl id parent pos} {
    saveOrder [::tkutils::tkutldrag::order $tbl]
}
::tkutils::tkutldrag::enable .t -command moved
```

## Notes

- `-movablerows` works only with select mode `single` or `multiple`.
  `enable` changes `browse` to `single` and `extended` to `multiple`.
- With `-samelevel 1` a row in a tree can be dropped only before a sibling;
  the end of a child list other than the top level is not a drop target.
- Escape cancels a drag (tablelist).
- A table sorted by column shows its sort order; after the user drags a row,
  call `$tbl resetsortinfo` if the arrow should go.

## Error codes

`-errorcode {TKUTILS TKUTLDRAG OPTION}`.
