# tkutils::tkupreview

A content preview widget. **Policy-free by design**: it knows how to *display* a
range of content kinds, but nothing about file types, extensions, providers, or
where the content comes from. The caller decides what to show; the widget just
shows it. That split keeps it reusable -- a file manager, a diff tool, a help
browser can all use it, with the file-type-to-preview-kind mapping living in the
application, not here. Tk 8.6+ and 9.x.

## API

```tcl
::tkutils::tkupreview::widget  path              ;# build the widget

# each display method takes (path title content|img|file):
::tkutils::tkupreview::text     path title text
::tkutils::tkupreview::markdown path title text
::tkutils::tkupreview::html     path title text
::tkutils::tkupreview::json     path title text
::tkutils::tkupreview::xml      path title text
::tkutils::tkupreview::ini      path title text
::tkutils::tkupreview::csv      path title text ?-delimiter c? ...
::tkutils::tkupreview::hex      path title bytes
::tkutils::tkupreview::image    path title file  ;# path to an image file
::tkutils::tkupreview::photo    path title photo ;# a ready Tk photo
::tkutils::tkupreview::pdf      path title file  ;# rendered first page
::tkutils::tkupreview::sqlite   path title file  ;# table browser
::tkutils::tkupreview::message  path msg         ;# a centered notice

::tkutils::tkupreview::clear    path
::tkutils::tkupreview::kind     path              ;# current kind, or ""
```

## Display kinds

Text-shaped content is passed as a string; the caller decodes bytes first
(providers return raw bytes). Structured kinds render through sibling tkutils
widgets when available and fall back to plain text otherwise:

- **text** -- plain text.
- **markdown** -- rendered via `tkumdview`.
- **html** -- rendered via `tcllitehtml` (a limited HTML/CSS engine).
- **json / xml / ini** -- structured viewers (`tkujson`, `tkuxml`, `tkuini`).
- **csv** -- a table via `tkucsv`; pass `-delimiter \t` for TSV.
- **hex** -- a hex dump of raw bytes.
- **image** -- PNG/GIF/JPEG/TIFF/BMP/ICO from a file path, in a zoomable canvas.
- **photo** -- a Tk photo the caller already built.
- **pdf** -- the first page rendered to an image.
- **sqlite** -- a table browser over a database file.
- **message** -- a centered one-line notice (empty state, errors).

Each method sets the widget's `kind`, queryable with `kind`.

## Use

```tcl
package require tkutils::tkupreview

::tkutils::tkupreview::widget .pv
pack .pv -fill both -expand 1

# the application maps type -> kind; the widget stays unaware of files:
::tkutils::tkupreview::text .pv "notes.txt (1.2 KB)" $decodedText
::tkutils::tkupreview::message .pv "Select a file to preview."
```

## The policy-free split

The widget never inspects a file name or asks a provider anything. It receives
already-decoded content (or a file path for the binary kinds) and a title, and
displays it. Deciding that `*.md` means markdown, or reading bytes from a ZIP and
decoding UTF-8, is the application's job. This is what lets the same widget serve
very different applications unchanged.

## See also

`tkumdview`, `tkujson`, `tkucsv`, `tkusqlite`, `tkuimage`
