# tkutils::tkdateentry

Date entry with a drop-down calendar picker: an entry showing a date plus a
button that drops down a month grid of day buttons (Monday-first) with
previous/next navigation, **Today** and **Clear**. The displayed text uses
`-dateformat`; `getDate` always returns the ISO date. Date math uses `clock`.

## API

```tcl
set w [::tkutils::tkdateentry::widget .d ?-dateformat fmt? ?-width n? \
        ?-textvariable var? ?-command cmd?]
::tkutils::tkdateentry::getText  $w        ;# entry text (formatted)
::tkutils::tkdateentry::getDate  $w        ;# ISO yyyy-mm-dd, or "" if empty/invalid
::tkutils::tkdateentry::setDate  $w iso    ;# set from ISO date ("" clears)
::tkutils::tkdateentry::today    $w
::tkutils::tkdateentry::clear    $w
```

`-command` is called with the ISO date (or "" on Clear) when a day is picked.
`setDate` rejects non-ISO input with error code `{TKUTILS TKDATEENTRY DATE}`.
