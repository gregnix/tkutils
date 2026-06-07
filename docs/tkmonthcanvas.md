# tkutils::tkmonthcanvas

Calendar **canvas** toolkit: draws month / quarter / year views onto a Tk canvas,
with themes, multi-day selection and click callbacks. Date and holiday logic come
from **tical** (`tical::config`, `tical::locale`, `tical::holidays`,
`tical::view::month`), so this is an **optional** widget (not loaded by the tkutils
umbrella).

Unlike the `widget $path` widgets, this is a **procedural** toolkit that draws onto
a canvas you create and manage (state is per-namespace = one active canvas).

## API
```tcl
package require tkutils::tkmonthcanvas

::tkutils::tkmonthcanvas::init ?-fontsize 11? ?-font Arial? \
    ?-locale de_DE? ?-timezone :Europe/Berlin? ?-theme default? \
    ?-onDayClick cmd? ?-onWeekClick cmd? ?-onMonthClick cmd?

# draw onto a canvas $c
::tkutils::tkmonthcanvas::drawMonth   $c year month ?x0 y0?
::tkutils::tkmonthcanvas::drawQuarter $c year month ?x0 y0?   ;# quarter containing month
::tkutils::tkmonthcanvas::drawYear    $c year ?x0 y0 cols?
::tkutils::tkmonthcanvas::clear       $c

# sizes (for -scrollregion) -> {width height}
::tkutils::tkmonthcanvas::getMonthSize
::tkutils::tkmonthcanvas::getQuarterSize
::tkutils::tkmonthcanvas::getYearSize ?cols?

# themes
::tkutils::tkmonthcanvas::setTheme default|dark|light
::tkutils::tkmonthcanvas::defineTheme name spec
::tkutils::tkmonthcanvas::getThemeValue key        ;# e.g. background

# callbacks
::tkutils::tkmonthcanvas::setCallback day    cmd   ;# cmd $c date
::tkutils::tkmonthcanvas::setCallback week   cmd   ;# cmd $c year weeknr
::tkutils::tkmonthcanvas::setCallback month  cmd   ;# cmd $c year month
::tkutils::tkmonthcanvas::setCallback select cmd   ;# cmd $c selectionList

# multi-day selection
::tkutils::tkmonthcanvas::setSelectMode none|single|multiple
::tkutils::tkmonthcanvas::getSelection             ;# sorted ISO dates
::tkutils::tkmonthcanvas::setSelection dates       ;# ISO dates and A..B ranges
::tkutils::tkmonthcanvas::clearSelection ?refresh?

# helpers / notes
::tkutils::tkmonthcanvas::getWeekDates  year weeknr
::tkutils::tkmonthcanvas::getMonthDates year month
::tkutils::tkmonthcanvas::addNote date text
::tkutils::tkmonthcanvas::hasNote date
::tkutils::tkmonthcanvas::setNotes dict
```

## Selection
With `selectmode multiple`: plain click selects one day, **Shift**-click selects the
inclusive range from the anchor, **Ctrl**-click toggles a single day. The selected
cell outline uses the theme's `selectOutline` colour.

## Errors
`return -code error -errorcode {TKUTILS TKMONTHCANVAS <REASON>}` (`SELECTMODE`, `SELECT`, ...).

## Demo
```bash
wish examples/demo-tkmonthcanvas.tcl
```

## See also
`tical(n)`, `tkutils::tkutical`.
