# tkutils::tkutlgroup

Group flat rows into a `tablelist` tree: one parent row per value of a key
column, the original rows as its children, with optional sums and a member
count in the parent row. Library-neutral.

## Package

```tcl
package require tkutils::tkutlgroup 0.1
```

Requires `Tk` and `tablelist`. Uses `tclutils::tunum` to read formatted
numbers (`1.234,56`) in sum columns when it is on the path.

## Commands

```tcl
::tkutils::tkutlgroup::group   tbl rows keyCol ?options?  ;# -> parent keys
::tkutils::tkutlgroup::ungroup tbl                        ;# -> flat rows
```

`group` appends to the table; call `$tbl delete 0 end` first to replace its
contents. `ungroup` returns the member rows in display order with the key
column filled in again.

## Options

| Option    | Default        | Meaning                                         |
|-----------|----------------|-------------------------------------------------|
| `-sum`    | `{}`           | columns to total in the parent row              |
| `-count`  | `{}`           | column for the number of members                |
| `-blank`  | `1`            | leave the key column empty in the child rows    |
| `-format` | `%.2f`         | Tcl `format` for sums that are not integers     |
| `-font`   | bold default   | font of the parent rows                         |
| `-expand` | `1`            | `0` collapses the groups                        |

## Usage

```tcl
package require Tk
package require tablelist_tile
package require tkutils::tkutlgroup

tablelist::tablelist .t -treecolumn 0 \
    -columns {16 Customer left 12 Article left 6 Qty right 10 Amount right 4 N right}
::tkutils::tkutlgroup::group .t $orders 0 -sum {2 3} -count 4
```

## Notes

- Groups appear in the order their keys first occur in `rows`.
- Sorting keeps the groups: tablelist sorts the parent rows by their own
  cells (the sums) and the children inside each parent.
- Cells in a `-sum` column that are no number count as 0.

## Error codes

`-errorcode {TKUTILS TKUTLGROUP <REASON>}` (`OPTION`, `COLUMN`).
