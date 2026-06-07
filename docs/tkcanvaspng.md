# tkutils::tkcanvaspng

Render a Tk **canvas** to a **PNG** (pure Tcl, no external tools) via
`tclutils::tupngdraw`. Useful for exporting canvas drawings/charts. Requires Tk plus
`tclutils::tupngdraw`; TTF text needs the optional `Glyphs` package. Optional widget
(not in the tkutils umbrella).

## API
```tcl
package require tkutils::tkcanvaspng

# PNG bytes of the canvas:
set png [::tkutils::tkcanvaspng::render $canvas \
    ?-region {x1 y1 x2 y2}? ?-scale N? ?-background color? \
    ?-textcmd cmd? ?-fontmap map?]

# write straight to a file (returns the file name):
::tkutils::tkcanvaspng::write out.png $canvas ?same options?
```
- `-region` defaults to `[$canvas bbox all]`; an empty canvas is an error.
- `-scale` is a positive-integer pixel multiplier.
- `-background` defaults to the canvas background, else white.
- `-fontmap` maps Tk fonts to TTF files for glyph rendering (needs `Glyphs`).

## Errors
`{TKUTILS TKCANVASPNG <REASON>}` (`WINDOW`, `EMPTY`).

## See also
`tclutils::tupngdraw`, `tclutils::tupng`.
