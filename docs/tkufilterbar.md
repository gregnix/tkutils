# tkutils::tkufilterbar

Per-column filter bar: one small labelled entry per column. Each field filters
its own column; the consumer ANDs the non-empty fields together. Complements
`tkusearchbar` (a single free-text box) for spreadsheet-style multi-column
filtering. The set of columns is dynamic -- call `setColumns` to (re)build the
row, e.g. whenever a new result set is shown.

## API

```tcl
set w [::tkutils::tkufilterbar::widget .f ?-command cmd? ?-delay ms? ?-width n?]
::tkutils::tkufilterbar::setColumns $w {col1 col2 ...}  ;# (re)build the row
::tkutils::tkufilterbar::columns    $w
::tkutils::tkufilterbar::getFilters $w                  ;# dict {col -> text}, non-empty only
::tkutils::tkufilterbar::getFilter  $w col
::tkutils::tkufilterbar::setFilter  $w col text         ;# programmatic, does not fire
::tkutils::tkufilterbar::clear      $w                  ;# empties all, fires
::tkutils::tkufilterbar::focusFirst $w
```

`-command` is called as `cmd filters`, where `filters` is a dict mapping each
non-empty column to its text, in column order. Typing fires it after `-delay`
ms of inactivity (default 300) and on `<Return>`; `clear` fires immediately.
`-width` is the per-entry width (default 10).

## Notes

- The bar holds no filtering logic itself -- it only reports the typed fields.
  The consumer decides how to match (substring, prefix, numeric comparison ...)
  and combines the conditions (typically AND).
- `setColumns` discards any previously typed contents.
- Pairs naturally with `tkusearchbar`: use the search bar for a free-text AND
  search and the filter bar for per-column conditions, ANDing both.

Tcl/Tk 8.6 and 9.x.
