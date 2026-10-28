# tkutils::tkutlsort

Type-aware column sorting for a `tablelist` widget.

tablelist sorts columns as dictionary/ASCII text by default, which mis-orders
numeric and currency columns — e.g. `"1.234,56 €"` sorts before `"2,50 €"`.
`tkutlsort` sets the correct `-sortmode` per column, including a `num` mode that
compares human-formatted numbers via `tclutils::tunum`. Library-neutral.

## Package

```tcl
package require tkutils::tkutlsort 0.3
```

Requires `tablelist`. Uses `tclutils::tunum` for the `num` sort mode (falls back
to a built-in parser when tunum is not on the path).

## Commands

```tcl
::tkutils::tkutlsort::column  tbl col type ?cmd? ?-empty first|last?
::tkutils::tkutlsort::columns tbl {col type col type ...} ?-empty first|last?
```

`-empty` applies to `integer`, `real` and `num`: empty and unparsable cells
go first or last in **both** sort directions. Without it `integer` and `real`
use tablelist's own mode, which raises an error on empty cells. `columns`
passes `-empty` only to `integer`, `real` and `num` columns.

## Sort types

| type      | tablelist mode | use for                                         |
|-----------|----------------|-------------------------------------------------|
| `string`  | `dictionary`   | text (default-like)                             |
| `nocase`  | `asciinocase`  | case-insensitive text                           |
| `integer` | `integer`      | plain integers                                  |
| `real`    | `real`         | plain Tcl doubles (`12.5`)                       |
| `num`     | command (tunum)| human numbers / currency (`1.234,56 €`, `9,90`) |
| `command` | command        | your own 2-argument comparison proc (`?cmd?`)    |

## Usage

```tcl
package require Tk
package require tablelist_tile
package require tkutils::tkutlsort

tablelist::tablelist .t -columns {0 Article left 0 Price right 0 Qty right}
# ... insert rows ...

# Article = text, Price = currency, Qty = integer
::tkutils::tkutlsort::columns .t {0 string  1 num  2 integer}

.t sortbycolumn 1 -increasing      ;# now sorts 2,50 < 9,90 < 10,00 < 1.234,56
```

Custom comparator:

```tcl
proc cmpLen {a b} { expr {[string length $a] - [string length $b]} }
::tkutils::tkutlsort::column .t 0 command cmpLen
```

Empty cells at the end, ascending or descending:

```tcl
::tkutils::tkutlsort::column .t 2 integer -empty last
```

## Notes

- `num` parses EU (`1.234,56`) and US (`1,234.56`) grouping and strips currency
  symbols; unparsable cells (empty, text) sort after all numbers.
- Sorting itself is still triggered the normal tablelist way
  (`sortbycolumn`, label-click, `-labelcommand` etc.); `tkutlsort` only
  configures *how* each column compares.

## Error codes

`-errorcode {TKUTILS TKUTLSORT <REASON>}` (`TYPE`, `CMD`, `SPEC`, `OPTION`, `EMPTY`).
