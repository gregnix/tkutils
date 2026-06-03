# tkutils::tktimeentry

Time entry with hour and minute spinboxes (optionally seconds). `getTime`/
`setTime` use `HH:MM` (or `HH:MM:SS` with `-seconds`).

## API

```tcl
set w [::tkutils::tktimeentry::widget .t ?-time HH:MM? ?-increment min? \
        ?-seconds bool? ?-command cmd?]
::tkutils::tktimeentry::getTime $w
::tkutils::tktimeentry::setTime $w 09:30
```

`-increment` is the minute step (default 5). `-command` is called with the time
string on change. `setTime` rejects out-of-range/malformed input with
`{TKUTILS TKTIMEENTRY TIME}`.
