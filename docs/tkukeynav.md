# tkutils::tkukeynav

Keyboard focus navigation helpers: consistent Tab / Shift-Tab traversal plus
Return-to-next-field form ergonomics, the way data-entry users expect. Pure Tk,
works with classic and ttk inputs. Bindings are per widget and released on
`<Destroy>`.

## Movement

```tcl
::tkutils::tkukeynav::next $w      ;# focus next widget in tab order (returns it)
::tkutils::tkukeynav::prev $w      ;# focus previous
```

## Per-widget bindings

```tcl
::tkutils::tkukeynav::enable $w ?-onreturn cmd? ?-onescape cmd? ?-tab 0|1?
::tkutils::tkukeynav::disable $w
```

`-tab` (default 1) installs Tab/Shift-Tab traversal that also works inside
widgets which would otherwise swallow Tab. `-onreturn`/`-onescape` run on
Return/Escape and stop further handling.

## Form ergonomics

```tcl
::tkutils::tkukeynav::form $container ?-onsubmit cmd? ?-wrap 0|1? ?-onescape cmd?
```

Treats the focusable input descendants of `$container` (entries, combos,
spinboxes, text, listboxes, check/radio) as a form: Return advances to the next
field; on the last field it runs `-onsubmit` (or wraps to the first when
`-wrap 1`). Returns the ordered list of fields.

```tcl
package require tkutils::tkukeynav
ttk::frame .form
foreach n {name email phone} { pack [ttk::entry .form.$n] }
pack .form
tkukeynav::form .form -onsubmit {saveContact}
```

## Notes

- Errors carry `{TKUTILS TKUKEYNAV <REASON>}` (`NOWIDGET`, `OPTION`).

## Demo

```bash
tclsh examples/demo-tkukeynav.tcl
```
