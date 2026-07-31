# tkutils::tkucalendar

A clickable month calendar widget: a month grid with previous/next/today
navigation and click-to-select day cells -- a dependency-free replacement for
`widget::calendar`. The reference month and the selected day are tracked as ISO
dates; the display uses the system locale (or a given `-locale`) for month and
weekday names. Pure Tk + `clock`; nothing external. Tk 8.6+ and 9.x.

## API

```tcl
::tkutils::tkucalendar::widget       path ?options?
::tkutils::tkucalendar::getDate      path   ;# selected ISO date, or ""
::tkutils::tkucalendar::getFormatted path   ;# selected date via -dateformat, or ""
::tkutils::tkucalendar::setDate      path iso
::tkutils::tkucalendar::today        path
::tkutils::tkucalendar::next         path   ;# move one month forward
::tkutils::tkucalendar::prev         path   ;# move one month back
::tkutils::tkucalendar::getMonth     path   ;# "yyyy mm" of the displayed month
```

## Options

- `-date` iso -- initially selected day (ISO `yyyy-mm-dd`); default: none.
- `-firstday` -- first column: `monday` (default) or `sunday`.
- `-dateformat` fmt -- clock format used by `getFormatted` (default `%Y-%m-%d`).
- `-locale` name -- locale for month/weekday names (default: current).
- `-command` script -- appended the selected ISO date on each selection.

## Example

```tcl
package require tkutils::tkucalendar

::tkutils::tkucalendar::widget .cal -date 2026-07-15 -dateformat "%d.%m.%Y" \
    -command {apply {{iso} {puts "picked $iso"}}}
pack .cal

::tkutils::tkucalendar::getDate .cal        ;# -> 2026-07-15
::tkutils::tkucalendar::getFormatted .cal   ;# -> 15.07.2026
```

Clicking a day selects it (highlighted); today is emphasized. Navigation keeps
the current selection. Internally everything is ISO; `-dateformat` and `-locale`
only affect what is shown, so date handling stays version- and locale-safe.

## See also

`tkudateentry`, `tkucal`, `tkucalc`
