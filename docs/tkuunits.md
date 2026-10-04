# tkutils::tkuunits

Convert screen distances between px, pt, mm, cm and inch. Tk accepts the
units itself (`winfo fpixels . 10m`), but turning pixels back into
millimetres, or one unit into another, is left to the caller. Useful for
label and print previews. Pure Tk, Tcl/Tk 8.6+ / 9.x.

## Commands

```tcl
::tkutils::tkuunits::units                          ;# -> px pt mm cm inch
::tkutils::tkuunits::toPixels value unit ?window?   ;# -> float pixels
::tkutils::tkuunits::fromPixels px ?window?         ;# -> dict px pt mm cm inch
::tkutils::tkuunits::convert value from to ?window? ;# -> float
```

```tcl
tkuunits::toPixels 62 mm               ;# label width on screen
tkuunits::convert 62 mm cm             ;# 6.2
dict get [tkuunits::fromPixels 300] mm
```

Units are `px pt mm cm inch`; the Tk letters `p m c i` and `in` are accepted
as well. `pt` is the printer's point, 1/72 inch, as in Tk. Conversions use
the screen resolution of *window* (default `.`), so pixel values follow
`tk scaling`; unit-to-unit results do not depend on it.

Errors: `{TKUTILS TKUUNITS UNIT}` (unknown unit), `{TKUTILS TKUUNITS VALUE}`
(not a number, e.g. `2c`), `{TKUTILS TKUUNITS WINDOW}` (no such window).
