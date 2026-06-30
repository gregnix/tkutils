# tkutils::tkumdview

Markdown viewer widget: a two-pane frame with a headings outline on the left and
a rendered preview on the right. The document is parsed and rendered through
`tclutils::tumd` (a CommonMark subset), so the viewer needs no browser. Pure
Tk/ttk; namespace `::tkutils::tkumdview`.

## API
```tcl
set w [::tkutils::tkumdview::widget .w ?-width N? ?-height N?]   ;# -> frame path
::tkutils::tkumdview::loadFile    $w path     ;# read utf-8 file, render -> char count
::tkutils::tkumdview::setMarkdown $w md       ;# set text, rebuild outline, render -> char count
::tkutils::tkumdview::getMarkdown $w          ;# current document source
::tkutils::tkumdview::headings    $w          ;# outline of the current document
::tkutils::tkumdview::toHtml      $w          ;# HTML of the current document
::tkutils::tkumdview::tocWidget   $w          ;# path of the outline list
::tkutils::tkumdview::textWidget  $w          ;# path of the preview text widget
```

## Widget options

`widget` returns the frame `$path` it creates (a `ttk::frame` holding a
horizontal `ttk::panedwindow`: outline on the left, preview on the right).
`-width` and `-height` (default `72` x `26`) size the preview text widget in
characters and lines.

## Outline and navigation

The left pane lists the document's headings. Selecting an entry scrolls the
matching heading into view in the preview, so the outline acts as a clickable
table of contents. `tocWidget` and `textWidget` return the two underlying
widget paths if you need to restyle or bind them directly.

## Loading and rendering

`setMarkdown` replaces the document, rebuilds the outline and re-renders the
preview, returning the character count. `loadFile` reads the file as utf-8 and
hands it to `setMarkdown`, so a document renders identically under Tcl 8.6 and
Tcl 9. `getMarkdown` returns the current source.

Parsing and HTML generation are delegated to `tclutils::tumd`: `headings` and
`toHtml` are convenience pass-throughs that run the engine over the current
document, so the viewer and any export stay consistent.

```tcl
package require tkutils::tkumdview
set w [::tkutils::tkumdview::widget .v]
pack $w -fill both -expand 1
::tkutils::tkumdview::loadFile $w README.md
set html [::tkutils::tkumdview::toHtml $w]   ;# same render, as HTML
```
