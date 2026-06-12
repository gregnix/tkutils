# tkutils::tkulabeled

Labeled input composites -- a "label + control" row you drop into any layout,
for when a full `tkuform` dict is more than you need. The widget is the frame at
`$path`; the inner control is reachable, and one `value` accessor reads/writes
it. Types: entry, combo, spin, check, text. Pure Tk.

## API

```tcl
::tkutils::tkulabeled::add $path $type \
    ?-label s? ?-labelwidth n? ?-orient horizontal|vertical? ?control opts...?
::tkutils::tkulabeled::value $path ?newValue?   ;# get (1 arg) or set (2 args)
::tkutils::tkulabeled::control     $path        ;# the inner control widget
::tkutils::tkulabeled::labelwidget $path        ;# the ttk::label
::tkutils::tkulabeled::configure   $path ?-label s? ?control opts...?
```

`$type` is one of `entry combo spin check text` -- passed as a value, so nothing
here shadows a Tcl/Tk builtin. Options other than `-label`/`-labelwidth`/
`-orient` are forwarded to the inner control (`-values`, `-from`/`-to`,
`-variable`, `-width`, `-height`, …). `text` defaults to a vertical layout.

```tcl
package require tkutils::tkulabeled
tkulabeled::add .name  entry -label "Name:" -labelwidth 10
tkulabeled::add .lang  combo -label "Lang:" -values {Tcl Tk C}
tkulabeled::add .age   spin  -label "Age:"  -from 0 -to 120
tkulabeled::add .vip   check -label "VIP"   -variable ::vip
tkulabeled::add .notes text  -label "Notes:" -height 4
pack .name .lang .age .vip .notes -fill x
tkulabeled::value .name "Ada"
set who [tkulabeled::value .name]
```

## Notes

- `value` reads with one argument, writes with two (so an empty string is a
  valid value to set).
- For `check`, `value` reflects the bound `-variable`.
- Pairs well with `tkutils::tkukeynav` (Return-to-next-field) and
  `tkutils::tkuvalidate` (inline checks) on the inner `control`.
- Errors carry `{TKUTILS TKULABELED <REASON>}`
  (`TYPE`, `ORIENT`, `NOWIDGET`, `ARGS`).

## Demo

```bash
tclsh examples/demo-tkulabeled.tcl
```
