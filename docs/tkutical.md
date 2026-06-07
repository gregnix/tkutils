# tkutils::tkutical

Calendar **widget** backed by the **tical** engine. Renders a month or week view on
a canvas with optional week numbers and holidays and none|single|multiple day
selection. Optional widget (requires tical; not in the tkutils umbrella).

## API
```tcl
package require tkutils::tkutical

set w [::tkutils::tkutical::widget .w \
    ?-view month|week? ?-date YYYY-MM-DD? ?-year Y -month M? \
    ?-weeknumbers 0|1? ?-fontsize N? ?-holidays list? \
    ?-selectmode none|single|multiple? ?-command cmd?]

::tkutils::tkutical::setView  $w month|week    ;# getView
::tkutils::tkutical::setDate  $w YYYY-MM-DD     ;# getDate  (reference date)
::tkutils::tkutical::setMonth $w year month     ;# getMonth -> {year month}
::tkutils::tkutical::next  $w                    ;# prev / today (step by the view's unit)
::tkutils::tkutical::selectMode    $w mode
::tkutils::tkutical::getSelection  $w            ;# setSelection / clearSelection
::tkutils::tkutical::refresh       $w
::tkutils::tkutical::canvasWidget  $w            ;# the underlying canvas
```
`-command cmd` is called with the selection list on selection change.

## Errors
`{TKUTILS TKUTICAL <REASON>}` (`VIEW`, `DATE`, `MONTH`, `SELECTMODE`).

## Launcher
```bash
wish bin/tkutical.tcl ?YYYY-MM-DD?
```

## See also
`tical(n)`, `tkutils::tkmonthcanvas`.
