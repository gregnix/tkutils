# tkutils::tkimage

Image helpers and a scrollable, zoomable viewer widget. Scaling uses the
`imgtools` extension when it is installed and falls back to Tk's built-in photo
`subsample`/`zoom` otherwise -- `imgtools` is optional (loaded via `catch`).

## Helpers

```tcl
tkimage::fit imgW imgH boxW boxH ?mode?   ;# {newW newH scale}; mode contain|cover|none
tkimage::load file ?dst?                  ;# photo from file (PNG/GIF native)
tkimage::fromData bytes ?dst?             ;# photo from raw PNG/GIF bytes (in-memory)
tkimage::scale src w h ?dst?              ;# scaled photo (imgtools or Tk fallback)
tkimage::thumbnail src maxSize ?dst?      ;# contain-fit into maxSize box
```

## Viewer widget

```tcl
set v [tkimage::view .v ?-fitmode contain?]
pack $v -fill both -expand 1
tkimage::openFile .v photo.png
tkimage::zoomIn .v ; tkimage::zoomOut .v ; tkimage::zoom1 .v ; tkimage::fitView .v
tkimage::getImage .v                       ;# the original photo image
```

The viewer is a frame with a scrolled canvas; in `contain` fit-mode it re-fits on
resize, otherwise it honours the current zoom. Images are cleaned up
automatically when the widget is destroyed. JPEG and other non-native formats
require the Img/tkimg extension for `load`/`openFile`.
