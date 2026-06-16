# tkutils::tkuscrolledframe

A scrollable frame container -- the one container ttk does not provide natively.
Pack arbitrary widgets into its content frame and they scroll. A thin, proc-style
wrapper over Csaba Nemethi's `scrollutil` (`scrollarea` + `scrollableframe`), in
tkutils conventions (path = identity, per-widget state, `<Destroy>` cleanup).

**Optional module** -- needs the external `scrollutil` package (tklib); not loaded
by the tkutils umbrella. Without it, `widget` reports `{TKUTILS TKUSCROLLEDFRAME
NOSCROLLUTIL}`.

## API

```tcl
::tkutils::tkuscrolledframe::widget .sf ?-width n? ?-height n? \
    ?-xscrollincrement n? ?-yscrollincrement n?      ;# returns .sf
::tkutils::tkuscrolledframe::content .sf              ;# the frame to pack into
::tkutils::tkuscrolledframe::see     .sf $child ?corner?
::tkutils::tkuscrolledframe::xview   .sf ?args?
::tkutils::tkuscrolledframe::yview   .sf ?args?
::tkutils::tkuscrolledframe::autosize  .sf dimensions
::tkutils::tkuscrolledframe::autofillx .sf 0|1
::tkutils::tkuscrolledframe::autofilly .sf 0|1
::tkutils::tkuscrolledframe::configure .sf ?-option value ...?
::tkutils::tkuscrolledframe::scrollableframe .sf      ;# underlying scrollutil widget
::tkutils::tkuscrolledframe::scrollarea      .sf
```

```tcl
package require tkutils::tkuscrolledframe        ;# require explicitly (optional)
tkuscrolledframe::widget .sf -width 400 -height 300
pack .sf -fill both -expand 1
set c [tkuscrolledframe::content .sf]
foreach i {1 2 3 4 5} { pack [ttk::button $c.b$i -text "Row $i"] -fill x }
```

## Notes

- The widget *is* the frame at `.sf`; your content goes into
  `[tkuscrolledframe::content .sf]`, not `.sf` directly.
- Errors carry `{TKUTILS TKUSCROLLEDFRAME <REASON>}`
  (`NOSCROLLUTIL`, `NOWIDGET`, `OPTION`, `VALUE`).

## Demo

```bash
tclsh examples/demo-tkuscrolledframe.tcl     # needs scrollutil
```

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tkuscrolledframe::seerect path x1 y1 x2 y2 ?corner? ;# scroll the inner frame so the given region becomes visible
```
