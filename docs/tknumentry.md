# tkutils::tknumentry

Numeric entry with input validation, fixed decimals and optional min/max
clamping. Clamping and reformatting happen on commit (Return / focus-out).

## API

```tcl
set w [::tkutils::tknumentry::widget .n ?-decimals n? ?-min v? ?-max v? \
        ?-textvariable var? ?-width n? ?-command cmd?]
::tkutils::tknumentry::getValue $w        ;# number, or "" if empty
::tkutils::tknumentry::setValue $w 3.14
::tkutils::tknumentry::clear    $w
```

Typing is restricted to a valid (partial) number with at most `-decimals`
fractional digits. `setValue` errors on a non-number with
`{TKUTILS TKNUMENTRY VALUE}`. `-command` is called with the value on commit.
