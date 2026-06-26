# tkutils::tkutablelist (optional)

A multi-column table built on the **Tablelist** megawidget (from tklib): a
rows/columns API, click-to-sort headers, editable cells, selection helpers,
per-column configuration, optional frozen title columns, CSV loading via
tclutils `tucsv`, and display of a tclutils `tunotes` store.

OPTIONAL widget -- NOT in the tkutils umbrella. Require it directly once
Tablelist is installed (e.g. `apt install tklib`):

```tcl
package require tkutils::tkutablelist
```

## API
```tcl
set w [::tkutils::tkutablelist::widget .w ?-columns {t...}? ?-stretch all? \
        ?-titlecolumns N? ?-sortable 1? ?-editable 0? ?-selectmode extended? \
        ?-stripes COLOR? ?-selectcommand cmd? ?-doublecommand cmd?]

# rows
::tkutils::tkutablelist::insert    $w row
::tkutils::tkutablelist::setRows   $w rows
::tkutils::tkutablelist::rows      $w
::tkutils::tkutablelist::getRow    $w index
::tkutils::tkutablelist::setRow    $w index row
::tkutils::tkutablelist::deleteRow $w index
::tkutils::tkutablelist::clear     $w
::tkutils::tkutablelist::size      $w

# cells
::tkutils::tkutablelist::cellText  $w row col
::tkutils::tkutablelist::setCell   $w row col value

# columns
::tkutils::tkutablelist::setColumns      $w {titles}
::tkutils::tkutablelist::columns         $w
::tkutils::tkutablelist::configureColumn $w col  -sortmode integer -align right ...
::tkutils::tkutablelist::configureRow    $w row  -foreground gray -background ...
::tkutils::tkutablelist::configureCell   $w r,c  -background yellow -foreground ...

# selection
::tkutils::tkutablelist::selection    $w        ;# selected row indices
::tkutils::tkutablelist::selectedRows $w        ;# selected rows
::tkutils::tkutablelist::selectRows   $w {i...}

# sorting / data sources
::tkutils::tkutablelist::sortBy   $w col ?-increasing|-decreasing?
::tkutils::tkutablelist::loadCsv  $w csv ?-header 0|1? ?-delimiter ,?
::tkutils::tkutablelist::fromNotes $w store ?-indent 0|1?   ;# a tunotes store
::tkutils::tkutablelist::tableWidget $w

# CSV export / edit hook
::tkutils::tkutablelist::toCsv   $w ?-header 0|1?           ;# -> CSV text
::tkutils::tkutablelist::saveCsv $w file ?-header 0|1?
::tkutils::tkutablelist::editEndCommand $w cmd             ;# cmd: path row col text -> new text
```

# selection / activation callbacks
::tkutils::tkutablelist::selectCommand $w ?cmd?           ;# get or set
::tkutils::tkutablelist::doubleCommand $w ?cmd?           ;# get or set
```

## Row / cell formatting

`configureRow` and `configureCell` are thin pass-throughs to Tablelist's
`rowconfigure`/`cellconfigure` (mirroring `configureColumn`). `row` may be a row
index, `end`, or a full key (see Hierarchy); `cell` is `"row,col"`. They accept
the usual `-foreground`/`-background`/`-font` options and return the target.

## Footer (summary row)

With `-footer 1`, `widget` adds a second single-row tablelist directly below the
table body and above the horizontal scrollbar. The wrapper keeps both in sync
coherently: the table's `-xscrollcommand` updates the scrollbar **and** mirrors
the footer's horizontal position (it does not get overwritten), and the footer
clones the table's column widths, alignment, `-hide` flags and `-titlecolumns`
on creation and on every column resize/move. So footer totals stay aligned under
their columns even while scrolling, and the scrollbar keeps working.

```tcl
set w [::tkutils::tkutablelist::widget .t -columns {Article Qty Price} \
           -titlecolumns 1 -footer 1]

::tkutils::tkutablelist::footerWidget $w        ;# -> $w.foot  (or "" if no footer)
::tkutils::tkutablelist::footerSet    $w {Sum: 18 7,70}        ;# one value per column
::tkutils::tkutablelist::footerSum    $w -columns {1 2} -label Sum: -labelcolumn 0 ?-format %.2f?
```

`footerSum` totals the given columns (German-aware via `tclutils::tunum`, like
`tkutlfooter::autosum`) and writes each sum under its own column, with `-label`
in `-labelcolumn`. `-format` applies Tcl `[format]` to the sum (English dot) -- for
locale-specific currency output, compute the strings yourself and use `footerSet`.

## Hierarchy (parent / child rows)

```tcl
set key [::tkutils::tkutablelist::insertChild $w parent values ?index?]
::tkutils::tkutablelist::expand   $w ?row?     ;# no row -> expand every row
::tkutils::tkutablelist::collapse $w ?row?     ;# no row -> collapse every row
```

`parent` is `root` or a full key; `insertChild` returns the **full key** of the
new row (`k0`, `k1`, …), which you pass as the next `parent` and to
`configureRow` to colour the row. `expand`/`collapse` take a row index or key, or
operate on all rows when called with no row.

```tcl
set a [::tkutils::tkutablelist::insertChild $w root  {Level1 ...}]
set b [::tkutils::tkutablelist::insertChild $w $a    {Level2 ...}]
::tkutils::tkutablelist::configureRow $w $a -foreground darkblue
::tkutils::tkutablelist::expand $w
```

## Callbacks

`-selectcommand` fires on `<<TablelistSelect>>` as `cmd $w $row`, where `$row` is
the first selected row index, or `-1` when the selection is empty.
`-doublecommand` fires on a double-click on a data row as `cmd $w $row`, only when
the click lands on a row (header/empty space is ignored). The click position is
resolved with `tablelist::convEventFields`, so the row is correct regardless of
stripes or separators. Both default to `""` (no callback). They can also be set
or read at runtime with `selectCommand`/`doubleCommand`.

The callback intentionally passes only the row index; fetch the row data via the
existing API (`rows`, `getRow`, `cellText`). When `-editable 1` is also used,
prefer `-selectcommand` for row activation, since double-click may overlap with
in-cell editing.

Declarative columns: a `-columns` entry may be a plain title (spaces allowed) or
a list `{title -align right -width N -sortmode integer -editable 1 ...}`:

```tcl
set w [::tkutils::tkutablelist::widget .w \
    -columns {Name {Age -sortmode integer -align right} {Full Name}}]
```

Editing: with `-editable 1` (or `configureColumn $w col -editable 1`),
double-click a cell to edit it; `rows`/`getRow` then reflect the new value.

## Errors

Unknown widget options raise `{TKUTILS TKUTABLELIST OPTION}`.

## Launcher
```bash
tclsh bin/tkutablelist.tcl
```
