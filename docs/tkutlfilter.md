# tkutils::tkutlfilter

Filter a `tablelist` by hiding the rows that do not match. The rows stay in
the widget, so row ids (`-name`), attributes, embedded windows and the
selection of visible rows are kept. Library-neutral.

## Package

```tcl
package require tkutils::tkutlfilter 0.1
```

Requires `Tk` and `tablelist`.

## Commands

```tcl
::tkutils::tkutlfilter::filter tbl query ?options?     ;# -> number of matching rows
::tkutils::tkutlfilter::later  tbl ms query ?options?  ;# filter after ms of quiet
::tkutils::tkutlfilter::clear  tbl                     ;# show the filtered rows again
::tkutils::tkutlfilter::query  tbl                     ;# -> current query or ""
```

A row is shown when it matches the query in one of the searched columns,
every `-where` condition and the `-command`. An empty query without
`-where` or `-command` clears the filter. `later` sends
`<<TkutlFilterApplied>>` to the table after filtering.

## Options

| Option     | Default     | Meaning                                              |
|------------|-------------|------------------------------------------------------|
| `-columns` | all visible | columns the query is searched in                     |
| `-mode`    | `substring` | `substring`, `exact`, `glob`, `regexp`               |
| `-nocase`  | `1`         | case-insensitive matching                            |
| `-where`   | `{}`        | `{col text ...}`: per-column conditions, all must match |
| `-command` | `{}`        | own test, called as `cmd tbl key row`, returns 0 or 1 |

In `-where`, `col` is a column index, a column `-name` or a column title.
The dict that `tkutils::tkufilterbar` passes to its `-command` fits directly.

## Usage

```tcl
package require Tk
package require tablelist_tile
package require tkutils::tkutlfilter

ttk::entry .e -textvariable q
bind .e <KeyRelease> { ::tkutils::tkutlfilter::later .t 300 $q }
```

Per-column filter bar:

```tcl
set bar [::tkutils::tkufilterbar::widget .fb \
    -command {apply {{f} { ::tkutils::tkutlfilter::filter .t "" -where $f }}}]
::tkutils::tkufilterbar::setColumns $bar {Name City}
```

Own condition:

```tcl
proc adults {tbl key row} { expr {[lindex $row 2] >= 18} }
::tkutils::tkutlfilter::filter .t "" -command adults
```

## Notes

- Matching uses the displayed values (`getformatted`); `-command` gets the
  raw row (`get`).
- Rows the application hid itself (`-hide 1`) stay hidden and are not
  counted; `clear` shows only the rows the filter hid.
- In a tree a parent stays visible while one of its descendants matches.
  Collapsed nodes stay collapsed.
- `size` and `get 0 end` still count every row; use
  `getfullkeys 0 end -viewable` or `get 0 end -viewable` for the visible
  ones. `tkutablelist::toCsv` and `tkutlclip::copyAll` export only the
  visible rows.
- Each change sends `<<TablelistRowHiddenStateChanged>>`.

## Error codes

`-errorcode {TKUTILS TKUTLFILTER <REASON>}` (`OPTION`, `MODE`, `REGEXP`,
`WHERE`, `COLUMN`).
