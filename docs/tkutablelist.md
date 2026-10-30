# tkutils::tkutablelist (optional)

A multi-column table built on the **Tablelist** megawidget (from tklib): a
rows/columns API, click-to-sort headers, editable cells, selection helpers,
per-column configuration, optional frozen title columns, CSV loading via
tclutils `tucsv`, and display of a tclutils `tunotes` store.

OPTIONAL widget -- not listed in the tkutils umbrella itself, but
`tkutils::tkufilelist` (in the umbrella) requires it, so loading the umbrella
loads it too and needs Tablelist. Standalone: require it directly once
Tablelist is installed (e.g. `apt install tklib`):

```tcl
package require tkutils::tkutablelist
```

## API
```tcl
set w [::tkutils::tkutablelist::widget .w ?-columns {t...}? ?-stretch all? \
        ?-titlecolumns N? ?-sortable 1? ?-editable 0? ?-selectmode extended? \
        ?-exportselection 0? ?-stripes COLOR? ?-selectcommand cmd? \
        ?-doublecommand cmd?]
# -exportselection defaults to 0 (PRIMARY not cleared by menus); use 1 for Tk-like export

# rows
::tkutils::tkutablelist::insert    $w row ?id?
::tkutils::tkutablelist::setRows   $w rows ?-ids idList?
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
::tkutils::tkutablelist::selectRows   $w {i...}   ;# first row active and visible

# stable row ids (row -name)
::tkutils::tkutablelist::rowId       $w index     ;# -> id or ""
::tkutils::tkutablelist::findId      $w id        ;# -> index or -1
::tkutils::tkutablelist::selectedIds $w
::tkutils::tkutablelist::selectIds   $w {id...}   ;# -> ids found

# sorting / data sources
::tkutils::tkutablelist::sortBy   $w col ?-increasing|-decreasing?
::tkutils::tkutablelist::loadCsv  $w csv ?-header 0|1? ?-delimiter ,?
::tkutils::tkutablelist::fromNotes $w store ?-indent 0|1?   ;# a tunotes store
::tkutils::tkutablelist::tableWidget $w

# CSV export / edit hook
::tkutils::tkutablelist::toCsv   $w ?-header 0|1? ?-all 0|1? ?-formatted 0|1? ?tucsv options?
::tkutils::tkutablelist::saveCsv $w file ?toCsv options? ?-encoding utf-8?
::tkutils::tkutablelist::editEndCommand $w cmd             ;# cmd: path row col text -> new text
```

# selection / activation callbacks
::tkutils::tkutablelist::selectCommand $w ?cmd?           ;# get or set
::tkutils::tkutablelist::doubleCommand $w ?cmd?           ;# get or set
```

## Row ids, sorting, CSV

Row indices change when the user sorts. `insert … id` and `setRows … -ids`
store an id in the row's `-name`; `findId`, `selectedIds` and `selectIds` work
with ids; `selectedIds` leaves out selected rows without an id, use
`curselection` for all selected rows. `setRows` inserts all rows in one `insertlist` and re-applies the
current sort order. With `-ids`, the list needs one id per row.

With `-sortable 1` a header click calls `tablelist::sortByColumn` (toggles the
order, shows the arrow, sends `<<TablelistColumnSorted>>`); Shift+click adds
further sort columns (`tablelist::addToSortColumns`).

`toCsv` exports what the user sees: viewable rows and visible columns, raw
cell values. `-all 1` takes every row and column, `-formatted 1` the displayed
values. Other options go to `tclutils::tucsv::text`, e.g. `-delimiter ;` or
`-profile excel-de` (`;`, CRLF, BOM). `saveCsv` writes UTF-8 unless
`-encoding` says otherwise, through a temporary file
(`tclutils::common::replaceFile`): a failed write leaves the old file.

```tcl
::tkutils::tkutablelist::setRows $w $rows -ids $ids
::tkutils::tkutablelist::selectIds $w [list $currentId]
::tkutils::tkutablelist::saveCsv $w out.csv -profile excel-de
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

`setRows` raises `{TKUTILS TKUTABLELIST OPTION <opt>}` for an unknown option
and `{TKUTILS TKUTABLELIST IDS}` when the number of ids does not match.

Unknown widget options raise `{TKUTILS TKUTABLELIST OPTION <opt>}` with the message `unknown option "<opt>"` and a second line `Known:` listing the valid options (since 2026-10-20; before without the option name).

## Launcher
```bash
tclsh bin/tkutablelist.tcl
```
