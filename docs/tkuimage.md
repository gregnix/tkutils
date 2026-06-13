# tkutils::tkuimage

Image helpers and a scrollable, zoomable viewer widget. Scaling uses the
`imgtools` extension when it is installed and falls back to Tk's built-in photo
`subsample`/`zoom` otherwise -- `imgtools` is optional (loaded via `catch`).

## Helpers

```tcl
tkuimage::fit imgW imgH boxW boxH ?mode?   ;# {newW newH scale}; mode contain|cover|none
tkuimage::load file ?dst?                  ;# photo from file (PNG/GIF native)
tkuimage::fromData bytes ?dst?             ;# photo from raw PNG/GIF bytes (in-memory)
tkuimage::scale src w h ?dst?              ;# scaled photo (imgtools or Tk fallback)
tkuimage::thumbnail src maxSize ?dst?      ;# contain-fit into maxSize box
```

## Viewer widget

```tcl
set v [tkuimage::view .v ?-fitmode contain? ?-onchange cmd?]
pack $v -fill both -expand 1
tkuimage::openFile .v photo.png
tkuimage::zoomIn .v ; tkuimage::zoomOut .v ; tkuimage::zoom1 .v ; tkuimage::fitView .v
tkuimage::getImage  .v                      ;# the original photo image
tkuimage::zoomLevel .v                      ;# effective on-screen scale, 1.0 == 100%
```

The viewer is a frame with a scrolled canvas; in `contain` fit-mode it re-fits on
resize, otherwise it honours the current zoom. `-onchange cmd` runs `cmd $path`
after every redraw (load, zoom, fit, resize) -- useful to drive a status line;
read the current scale with `zoomLevel` (returns the exact zoom factor in
actual/zoom mode, the computed fit ratio in contain mode, or 0 before any load). Images are cleaned up
automatically when the widget is destroyed. JPEG and other non-native formats
require the Img/tkimg extension for `load`/`openFile`.

## Changes in 0.2

- Added `zoomLevel` (effective on-screen scale) and the `view -onchange cmd`
  callback (fires after every redraw: load, zoom, fit, resize).
- Fixed: switching to a smaller image now resizes the display so no pixels of
  the previous image remain.
- Fixed: the first zoom out of fit-mode continues from the on-screen scale
  instead of jumping relative to the full original resolution.
- imgtools is now detected lazily at scale time (used whenever available,
  regardless of package load order); display size is clamped to a sane range.
