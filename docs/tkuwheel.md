# tkutils::tkuwheel

Forward mouse-wheel events to a scrollable target. Solves a common Tk problem:
embedded windows (e.g. a frame inside a `text` widget) and ordinary child
widgets receive the wheel event themselves, so an outer scroller stops scrolling
while the pointer is over them. `tkuwheel` re-binds the wheel on a widget -- and,
by default, its whole subtree -- so the events are sent to a target widget's
`yview` / `xview`. Pure Tk, Tcl/Tk 8.6+ / 9.x.

Cross-platform: it binds `<MouseWheel>` (Windows/macOS) and `<Button-4>` /
`<Button-5>` (X11). Direction comes from the sign of the delta, so one notch
scrolls a fixed number of units regardless of the platform's delta magnitude.

## Commands

```tcl
::tkutils::tkuwheel::redirect target w ?-orient y|x|both? ?-amount N? ?-recursive 0|1?
::tkutils::tkuwheel::unbind   w ?-recursive 0|1?
```

### redirect

Binds the wheel on `w` so the events scroll `target`. `target` must understand
the standard `yview` / `xview scroll N units` protocol (text, canvas, listbox,
ttk::treeview, ...). Returns `w`.

| Option | Default | Meaning |
|--------|---------|---------|
| `-orient y` | `y` | plain wheel scrolls `target` vertically |
| `-orient x` | | plain wheel scrolls `target` horizontally |
| `-orient both` | | plain wheel = vertical, `Shift`+wheel = horizontal |
| `-amount N` | `3` | units scrolled per wheel notch (positive integer) |
| `-recursive` | `1` | bind every descendant of `w` too (`0` = only `w`) |

The subtree is bound as it exists at call time; re-run `redirect` after adding
child widgets. Bindings are removed automatically when `w` is destroyed.

### unbind

Removes the wheel bindings that `redirect` set on `w` (and its subtree unless
`-recursive 0`).

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
```

## Errors

Error code `{TKUTILS TKUWHEEL <REASON>}`:

| REASON | When |
|--------|------|
| `OPTION` | unknown option, missing value, bad `-orient` / `-amount` / `-recursive` |
| `WINDOW` | `target` or `w` does not exist |
