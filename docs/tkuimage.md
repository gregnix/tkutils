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
set v [tkuimage::view .v ?-fitmode contain?]
pack $v -fill both -expand 1
tkuimage::openFile .v photo.png
tkuimage::zoomIn .v ; tkuimage::zoomOut .v ; tkuimage::zoom1 .v ; tkuimage::fitView .v
tkuimage::getImage .v                       ;# the original photo image
```

The viewer is a frame with a scrolled canvas; in `contain` fit-mode it re-fits on
resize, otherwise it honours the current zoom. Images are cleaned up
automatically when the widget is destroyed. JPEG and other non-native formats
require the Img/tkimg extension for `load`/`openFile`.
