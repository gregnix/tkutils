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
        ?-stripes COLOR?]

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
::tkutils::tkutablelist::configureColumn $w col -sortmode integer -align right ...

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

Declarative columns: a `-columns` entry may be a plain title (spaces allowed) or
a list `{title -align right -width N -sortmode integer -editable 1 ...}`:

```tcl
set w [::tkutils::tkutablelist::widget .w \
    -columns {Name {Age -sortmode integer -align right} {Full Name}}]
```

Editing: with `-editable 1` (or `configureColumn $w col -editable 1`),
double-click a cell to edit it; `rows`/`getRow` then reflect the new value.

## Launcher
```bash
tclsh bin/tkutablelist.tcl
```
