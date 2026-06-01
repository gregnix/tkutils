# tkutils::tktablelist (optional)

A multi-column table built on the **Tablelist** megawidget (from tklib): a
rows/columns API, click-to-sort headers, editable cells, selection helpers,
per-column configuration, optional frozen title columns, CSV loading via
tclutils `tucsv`, and display of a tclutils `tunotes` store.

OPTIONAL widget -- NOT in the tkutils umbrella. Require it directly once
Tablelist is installed (e.g. `apt install tklib`):

```tcl
package require tkutils::tktablelist
```

## API
```tcl
set w [::tkutils::tktablelist::widget .w ?-columns {t...}? ?-stretch all? \
        ?-titlecolumns N? ?-sortable 1? ?-editable 0? ?-selectmode extended? \
        ?-stripes COLOR?]

# rows
::tkutils::tktablelist::insert    $w row
::tkutils::tktablelist::setRows   $w rows
::tkutils::tktablelist::rows      $w
::tkutils::tktablelist::getRow    $w index
::tkutils::tktablelist::setRow    $w index row
::tkutils::tktablelist::deleteRow $w index
::tkutils::tktablelist::clear     $w
::tkutils::tktablelist::size      $w

# cells
::tkutils::tktablelist::cellText  $w row col
::tkutils::tktablelist::setCell   $w row col value

# columns
::tkutils::tktablelist::setColumns      $w {titles}
::tkutils::tktablelist::columns         $w
::tkutils::tktablelist::configureColumn $w col -sortmode integer -align right ...

# selection
::tkutils::tktablelist::selection    $w        ;# selected row indices
::tkutils::tktablelist::selectedRows $w        ;# selected rows
::tkutils::tktablelist::selectRows   $w {i...}

# sorting / data sources
::tkutils::tktablelist::sortBy   $w col ?-increasing|-decreasing?
::tkutils::tktablelist::loadCsv  $w csv ?-header 0|1? ?-delimiter ,?
::tkutils::tktablelist::fromNotes $w store ?-indent 0|1?   ;# a tunotes store
::tkutils::tktablelist::tableWidget $w

# CSV export / edit hook
::tkutils::tktablelist::toCsv   $w ?-header 0|1?           ;# -> CSV text
::tkutils::tktablelist::saveCsv $w file ?-header 0|1?
::tkutils::tktablelist::editEndCommand $w cmd             ;# cmd: path row col text -> new text
```

Declarative columns: a `-columns` entry may be a plain title (spaces allowed) or
a list `{title -align right -width N -sortmode integer -editable 1 ...}`:

```tcl
set w [::tkutils::tktablelist::widget .w \
    -columns {Name {Age -sortmode integer -align right} {Full Name}}]
```

Editing: with `-editable 1` (or `configureColumn $w col -editable 1`),
double-click a cell to edit it; `rows`/`getRow` then reflect the new value.

## Launcher
```bash
tclsh bin/tktablelist.tcl
```
