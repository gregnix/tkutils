# tkutils::tkcal

Calendar view. Built on `tclutils::tucal`; shows a month in a monospace view with
previous/next/today navigation.

## API
```tcl
set w [::tkutils::tkcal::widget .w ?-year Y? ?-month M? ?-weeknumbers 0|1?]
::tkutils::tkcal::setMonth $w year month   ;# returns {year month}; throws on bad date
::tkutils::tkcal::getMonth $w              ;# {year month}
::tkutils::tkcal::next $w                   ;# advance one month (wraps the year)
::tkutils::tkcal::prev $w
::tkutils::tkcal::today $w
::tkutils::tkcal::getText $w               ;# the rendered calendar text
```

The toolbar has prev/next/Today plus a **Wk** checkbox to toggle week numbers.

## Launcher
```bash
tclsh bin/tkcal.tcl 6 2026     ;# month year
```
