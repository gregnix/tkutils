# tkutils::tkutltree

Convert between nested data and a `tablelist` tree, with **free column mapping**.
A node is a dict of named fields plus an optional list of child nodes; `-fields`
maps field names to columns in order, so each tree row carries several columns —
not just a key/value pair. Library-neutral.

## Package

```tcl
package require tkutils::tkutltree 0.3
```

Requires `Tk` and `tablelist`. The tablelist should have a tree column
(`-treecolumn`).

## Data model

```tcl
set data {
    {name Root size 0 type dir children {
        {name docs size 0 type dir children {
            {name a.txt size 12 type file}
            {name b.txt size 34 type file}
        }}
        {name img.png size 900 type file}
    }}
}
```

Each node is a dict: `<field> <value> ...` plus an optional `children`
(configurable via `-childrenkey`) holding a list of child nodes. The top level
is a list of nodes.

## Commands

```tcl
::tkutils::tkutltree::fromData tbl data -fields {f ...} ?options?   ;# -> top-level keys
::tkutils::tkutltree::toData   tbl       -fields {f ...} ?-childrenkey children? ?-node root? ?-idfield f?
::tkutils::tkutltree::clear    tbl ?-node root?
::tkutils::tkutltree::lazy     tbl loadCmd -fields {f ...} ?options?
::tkutils::tkutltree::reveal   tbl index      ;# expand ancestors, see; -> row index
::tkutils::tkutltree::findId   tbl id         ;# -> row index or -1
```

- **`-fields`** (required) — field names in column order. Field *i* fills
  column *i*; missing fields become empty cells.
- **`-childrenkey`** — the node key holding child nodes (default `children`).
- **`-parent` / `-node`** — a tablelist node reference (full key) to build under
  / read from (default `root`, the whole tree).
- **`-idfield f`** — the value of field `f` becomes the row's `-name` (a
  stable id for `findId`, `findrowname -descend`); `toData` writes it back.
- **`-expand none|all|N`** — collapse everything, expand everything, or show
  `N` levels. Without it rows are inserted as tablelist does (expanded).
- **`-lazykey f`** — a node with a true field `f` and no children gets an
  expand arrow; its children are loaded by `lazy`.

`fromData` inserts each level with one `insertchildlist`.

## Lazy loading

```tcl
proc loadDir {tbl key} {
    set dir [$tbl rowcget $key -name]
    lmap f [glob -nocomplain -directory $dir *] {
        list path $f name [file tail $f] lazy [file isdirectory $f]
    }
}
::tkutils::tkutltree::lazy .t loadDir -fields {name} -idfield path -lazykey lazy
::tkutils::tkutltree::fromData .t [list [list path $top name $top lazy 1]] \
    -fields {name} -idfield path -lazykey lazy
```

`lazy` sets the table's `-expandcommand` and `-populatecommand`. The first
expand of a lazy node, or a `searchcolumn -descend` that reaches it, calls
`loadCmd tbl key` once; the returned nodes are inserted with the options
given to `lazy`. Nodes returned with a true `-lazykey` field are lazy again.

## Usage

```tcl
package require Tk
package require tablelist_tile
package require tkutils::tkutltree

tablelist::tablelist .t -columns {0 Name left 0 Size right 0 Type left} -treecolumn 0
pack .t

::tkutils::tkutltree::fromData .t $data -fields {name size type}

# ... user expands/edits ...

set data2 [::tkutils::tkutltree::toData .t -fields {name size type}]
```

`fromData`/`toData` round-trip is stable: reading a tree back and rebuilding it
yields the same structure.

## Notes

- The number of `-fields` should match the number of columns you want filled;
  extra columns are left empty, extra fields are ignored.
- `toData` reads the **raw** cell values (`get`), so it returns the stored data,
  not any `-formatcommand` display text.
- Use a different `-childrenkey` if your data already uses `children` for
  something else.

## Error codes

`-errorcode {TKUTILS TKUTLTREE <REASON>}` (`FIELDS`, `OPTION`, `EXPAND`).
