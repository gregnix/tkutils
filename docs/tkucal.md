# tkutils::tkucal

Calendar view. Built on `tclutils::tucal`; shows a month in a monospace view with
previous/next/today navigation.

## API
```tcl
set w [::tkutils::tkucal::widget .w ?-year Y? ?-month M? ?-weeknumbers 0|1?]
::tkutils::tkucal::setMonth $w year month   ;# returns {year month}; throws on bad date
::tkutils::tkucal::getMonth $w              ;# {year month}
::tkutils::tkucal::next $w                   ;# advance one month (wraps the year)
::tkutils::tkucal::prev $w
::tkutils::tkucal::today $w
::tkutils::tkucal::getText $w               ;# the rendered calendar text
```

The toolbar has prev/next/Today plus a **Wk** checkbox to toggle week numbers.

## Launcher
```bash
tclsh bin/tkucal.tcl 6 2026     ;# month year
```
