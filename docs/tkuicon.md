# tkutils::tkuicon

Loads `.svg`/`.png` icons as Tk photo images and generates the built-in icon set
on the fly from `tclutils::tusvg`. Results are cached.

**Optional module** -- not loaded by the tkutils umbrella. SVG needs the `tksvg`
package on Tk 8.6, or native SVG on Tk 8.7+. Without SVG support the file loader
still handles PNG/GIF, and `create` reports `{TKUTILS TKUICON NOSVG}`.

## API

```tcl
::tkutils::tkuicon::hassvg                       ;# 1 if SVG rendering is available
::tkutils::tkuicon::available                    ;# predefined icon names
::tkutils::tkuicon::create  name size ?-color c? ?-strokeWidth w? ?-name img?
::tkutils::tkuicon::load    file ?-height h? ?-width w? ?-name img?
::tkutils::tkuicon::rescale imgName newHeight    ;# re-render/scale an icon
::tkutils::tkuicon::loadToolbarSet size ?-color c? ?-icons {names...}? ;# -> dict
::tkutils::tkuicon::clearCache
```

```tcl
package require tkutils::tkuicon            ;# require explicitly (optional)
set save [::tkutils::tkuicon::create save 24 -color "#1565c0"]
::tkutils::tkutoolbar::addButton $tb save "Save" {saveDoc} -icon $save
```

## Notes

- `rescale` (not `scale`, which is a Tk widget command) prefers true SVG
  re-rendering for crisp HiDPI results, falling back to integer photo zoom.
- Icon geometry comes from `tclutils::tusvg`, required lazily inside `create`
  (`{TKUTILS TKUICON NOGEN}` if missing).
- Errors carry `{TKUTILS TKUICON <REASON>}` (`NOSVG`, `FORMAT`, `NOGEN`).

## Demo

```bash
tclsh examples/demo-tkuicon.tcl     # shows the icon grid where SVG is supported
```
