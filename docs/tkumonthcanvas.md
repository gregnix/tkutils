# tkutils::tkumonthcanvas

Calendar **canvas** toolkit: draws month / quarter / year views onto a Tk canvas,
with themes, multi-day selection and click callbacks. Date and holiday logic come
from **tical** (`tical::config`, `tical::locale`, `tical::holidays`,
`tical::view::month`), so this is an **optional** widget (not loaded by the tkutils
umbrella).

Unlike the `widget $path` widgets, this is a **procedural** toolkit that draws onto
a canvas you create and manage (state is per-namespace = one active canvas).

## API
```tcl
package require tkutils::tkumonthcanvas

::tkutils::tkumonthcanvas::init ?-fontsize 11? ?-font Arial? \
    ?-locale de_DE? ?-timezone :Europe/Berlin? ?-theme default? \
    ?-onDayClick cmd? ?-onWeekClick cmd? ?-onMonthClick cmd?

# draw onto a canvas $c
::tkutils::tkumonthcanvas::drawMonth   $c year month ?x0 y0?
::tkutils::tkumonthcanvas::drawQuarter $c year month ?x0 y0?   ;# quarter containing month
::tkutils::tkumonthcanvas::drawYear    $c year ?x0 y0 cols?
::tkutils::tkumonthcanvas::clear       $c

# sizes (for -scrollregion) -> {width height}
::tkutils::tkumonthcanvas::getMonthSize
::tkutils::tkumonthcanvas::getQuarterSize
::tkutils::tkumonthcanvas::getYearSize ?cols?

# themes
::tkutils::tkumonthcanvas::setTheme default|dark|light
::tkutils::tkumonthcanvas::defineTheme name spec
::tkutils::tkumonthcanvas::getThemeValue key        ;# e.g. background
::tkutils::tkumonthcanvas::setFontSize size ?family? ;# set drawing font (default Arial)

# callbacks
::tkutils::tkumonthcanvas::setCallback day    cmd   ;# cmd $c date
::tkutils::tkumonthcanvas::setCallback week   cmd   ;# cmd $c year weeknr
::tkutils::tkumonthcanvas::setCallback month  cmd   ;# cmd $c year month
::tkutils::tkumonthcanvas::setCallback select cmd   ;# cmd $c selectionList

# multi-day selection
::tkutils::tkumonthcanvas::setSelectMode none|single|multiple
::tkutils::tkumonthcanvas::getSelection             ;# sorted ISO dates
::tkutils::tkumonthcanvas::setSelection dates       ;# ISO dates and A..B ranges
::tkutils::tkumonthcanvas::clearSelection ?refresh?

# helpers / notes
::tkutils::tkumonthcanvas::getWeekDates  year weeknr
::tkutils::tkumonthcanvas::getMonthDates year month
::tkutils::tkumonthcanvas::addNote date text
::tkutils::tkumonthcanvas::hasNote date
::tkutils::tkumonthcanvas::setNotes dict
```

## Selection
With `selectmode multiple`: plain click selects one day, **Shift**-click selects the
inclusive range from the anchor, **Ctrl**-click toggles a single day. The selected
cell outline uses the theme's `selectOutline` colour.

## Errors
`return -code error -errorcode {TKUTILS TKMONTHCANVAS <REASON>}` (`SELECTMODE`, `SELECT`, ...).

## Demo
```bash
wish examples/demo-tkumonthcanvas.tcl
```

## See also
`tical(n)`, `tkutils::tkutical`.
