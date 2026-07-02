# tkutils::tkuwheel

Forward mouse-wheel events to a scrollable target. Solves a common Tk problem:
embedded windows (e.g. a frame inside a `text` widget) and ordinary child
widgets receive the wheel event themselves, so an outer scroller stops scrolling
while the pointer is over them. `tkuwheel` re-binds the wheel on a widget -- and,
by default, its whole subtree -- so the events are sent to a target widget's
`yview` / `xview`. Pure Tk, Tcl/Tk 8.6+ / 9.x.

Cross-platform: it binds `<MouseWheel>` (Windows/macOS) and `<Button-4>` /
`<Button-5>` (X11 vertical). For horizontal scrolling on X11 the tilt-wheel
buttons `<Button-6>` / `<Button-7>` are honoured as well (they exist only on
Tk 8.7+ and are skipped gracefully on Tk 8.6). Direction comes from the sign of
the delta, so one notch scrolls a fixed number of units regardless of the
platform's delta magnitude.

## Commands

```tcl
::tkutils::tkuwheel::redirect target w ?-orient y|x|both? ?-amount N? \
                                  ?-recursive 0|1? ?-dynamic 0|1?
::tkutils::tkuwheel::unbind   w ?-recursive 0|1?
```

### redirect

Binds the wheel on `w` so the events scroll `target`. `target` must understand
the standard `yview` / `xview scroll N units` protocol (text, canvas, listbox,
ttk::treeview, ...). Returns `w`.

| Option | Default | Meaning |
|--------|---------|---------|
| `-orient y` | `y` | plain wheel scrolls `target` vertically |
| `-orient x` | | plain wheel scrolls `target` horizontally (plus tilt-wheel) |
| `-orient both` | | plain wheel = vertical, `Shift`+wheel / tilt-wheel = horizontal |
| `-amount N` | `3` | units scrolled per wheel notch (positive integer) |
| `-recursive` | `1` | bind every descendant of `w` too (`0` = only `w`) |
| `-dynamic` | `0` | also cover descendants added *after* the call |

By default the subtree is bound as it exists at call time. For a container that
is populated at runtime (e.g. a designer palette whose buttons appear later),
pass **`-dynamic 1`**: a `<Configure>` hook on `w` re-applies the binding to any
new descendants (coalesced via `after idle`), so wheel-over-child keeps
scrolling `target`. This relies on `w` being managed and resizing when children
are added -- the normal case for a growing frame; if you build `w` fully before
showing it, a single `redirect` is enough. Bindings are removed automatically
when `w` is destroyed.

### unbind

Removes the wheel bindings that `redirect` set on `w` (and its subtree unless
`-recursive 0`) and stops any `-dynamic` re-application on that root.

## Example

```tcl
package require tkutils::tkuwheel

# A frame full of labels embedded in a scrolling text widget would otherwise
# swallow the wheel. Forward it back to the text widget:
text .t -yscrollcommand {.sb set}
ttk::scrollbar .sb -command {.t yview}
grid .t .sb -sticky nsew

frame .t.card
label .t.card.title -text "Embedded"
label .t.card.body  -text "Scrolls the text widget anyway"
pack  .t.card.title .t.card.body
.t window create end -window .t.card

::tkutils::tkuwheel::redirect .t .t.card        ;# wheel over the card scrolls .t

# A scrollable palette (canvas + inner frame) filled with tools at runtime:
canvas .c -yscrollcommand {.csb set}
ttk::scrollbar .csb -command {.c yview}
frame .c.inner
.c create window 0 0 -anchor nw -window .c.inner
::tkutils::tkuwheel::redirect .c .c.inner -dynamic 1   ;# future buttons covered
::tkutils::tkuwheel::redirect .c .c
```

## Errors

Error code `{TKUTILS TKUWHEEL <REASON>}`:

| REASON | When |
|--------|------|
| `OPTION` | unknown option, missing value, bad `-orient` / `-amount` / `-recursive` / `-dynamic` |
| `WINDOW` | `target` or `w` does not exist |
