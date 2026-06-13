# tkutils::tkumarquee

Rubber-band (marquee) rectangle selection on a canvas: drag to draw a live
selection rectangle; on release the region is reported in **canvas** coordinates
(scroll-safe via `canvasx`/`canvasy`). The caller decides what to do with it —
crop, zoom-to-region, select items, measure. Pure Tk.

## API

```tcl
::tkutils::tkumarquee::enable .c ?-onselect cmd? ?-onstart cmd? ?-button N? \
    ?-minsize px? ?-outline color? ?-fill color? ?-dash pattern? ?-stipple bitmap? ?-keep 0|1?
::tkutils::tkumarquee::disable .c
::tkutils::tkumarquee::region  .c        ;# last region {x1 y1 x2 y2} or ""
::tkutils::tkumarquee::active  .c        ;# 1 while a drag is in progress
```

- `-onselect cmd` runs on release as `cmd $c x1 y1 x2 y2` with `x1<=x2`,
  `y1<=y2` (a reversed drag is normalised).
- `-onstart cmd` runs on press as `cmd $c x y`.
- `-minsize` (default 3) suppresses the callback for a click or a tiny drag.
- `-keep 1` leaves the rectangle item on the canvas after release (default
  deletes it, so you can draw your own marker from the reported coordinates).
- `-button`, `-outline`, `-fill`, `-dash`, `-stipple` tune the input button and
  appearance. Tk canvas fills have no alpha, so for a translucent overlay use a
  solid `-fill` plus a `-stipple` (e.g. `gray12`) rather than an 8-digit RGBA
  colour (which Tk rejects).

```tcl
package require tkutils::tkumarquee
tkumarquee::enable .c -onselect {apply {{c x1 y1 x2 y2} {
    # e.g. zoom to the selected region
    puts "selected $x1,$y1 .. $x2,$y2"
}}}
```

## Notes

- Coordinates are canvas coordinates, so selection is correct even when the
  canvas is scrolled or has a `-scrollregion`.
- Errors carry `{TKUTILS TKUMARQUEE <REASON>}` (`NOWIDGET`, `OPTION`).

## Demo

```bash
tclsh examples/demo-tkumarquee.tcl
```
