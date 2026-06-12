# tkutils::tkuvalidate

Inline validation feedback for input widgets. Attach a validator to an
entry/combo/spinbox: on focus-out (or on every key) the value is checked; invalid
input gets a red foreground, the ttk `invalid` state, and a `tkuballoon` message
explaining why; valid input clears all that. The GUI companion to
`tclutils::tuvalidate` (which supplies the predicates). Pure Tk + tclutils.

## API

```tcl
::tkutils::tkuvalidate::attach $w $validator \
    ?-message s? ?-when focusout|key|both? ?-allowempty 0|1? \
    ?-getcmd cmd? ?-onvalid cmd? ?-oninvalid cmd?
::tkutils::tkuvalidate::check  $w        ;# validate now -> 0|1
::tkutils::tkuvalidate::valid  $w        ;# last result
::tkutils::tkuvalidate::clear  $w        ;# remove marking + detach
::tkutils::tkuvalidate::allValid {w ...} ;# re-check all; 1 only if every one valid
```

`$validator` is either a `tclutils::tuvalidate` predicate name
(`email url ipv4 port alpha alnum numeric integer`) or any command prefix to
which the widget value is appended and that returns a boolean.

```tcl
package require tkutils::tkuvalidate
tkuvalidate::attach .email email   -message "Enter a valid e-mail"
tkuvalidate::attach .age   integer -message "Digits only" -when key -allowempty 0
tkuvalidate::attach .user  [list apply {{v} {expr {[string length $v] >= 3}}}] \
    -message "At least 3 characters"
if {[tkuvalidate::allValid {.email .age .user}]} { save }
```

## Notes

- `-allowempty 1` (default) leaves an empty field unmarked (optional fields);
  set `0` to require a value.
- `-getcmd` overrides how the value is read (default `[$w get]`); needed for
  text widgets, e.g. `-getcmd {.notes get 1.0 end-1c}`.
- The message is shown via `tkutils::tkuballoon` (hover to read it); the red
  foreground is the immediate cue.
- Errors carry `{TKUTILS TKUVALIDATE <REASON>}`
  (`NOWIDGET`, `OPTION`, `WHEN`, `NOENGINE`).

## Demo

```bash
tclsh examples/demo-tkuvalidate.tcl
```
