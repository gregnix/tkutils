# HOWTO: preview content of many kinds

`tkupreview` displays content -- text, Markdown, HTML, JSON, XML, INI, CSV, a hex
dump, images, a rendered PDF page, a SQLite table browser, or a centered message
-- but it is **policy-free**: it never looks at a file name, asks a provider
anything, or decides what kind something is. The caller (the application) makes
that decision and hands over ready content. This recipe shows the split.

## The widget

```tcl
package require Tk
package require tkutils::tkupreview

::tkutils::tkupreview::widget .pv
pack .pv -fill both -expand 1

# empty state
::tkutils::tkupreview::message .pv "Select a file to preview."
```

## The application decides the kind

The mapping from file type to preview kind lives in *your* code, not the widget:

```tcl
proc preview {pv prov path} {
    set ext [string tolower [file extension $path]]
    switch -- $ext {
        .txt - .tcl - .log {
            # providers return raw bytes -> decode before showing text
            set text [encoding convertfrom utf-8 [$prov get $path]]
            ::tkutils::tkupreview::text $pv [file tail $path] $text
        }
        .md  { ::tkutils::tkupreview::markdown $pv [file tail $path] \
                   [encoding convertfrom utf-8 [$prov get $path]] }
        .json { ::tkutils::tkupreview::json $pv [file tail $path] \
                   [encoding convertfrom utf-8 [$prov get $path]] }
        .csv { ::tkutils::tkupreview::csv $pv [file tail $path] \
                   [encoding convertfrom utf-8 [$prov get $path]] }
        .tsv { ::tkutils::tkupreview::csv $pv [file tail $path] \
                   [encoding convertfrom utf-8 [$prov get $path]] -delimiter \t }
        default {
            # unknown -> a hex dump of the raw bytes
            ::tkutils::tkupreview::hex $pv [file tail $path] [$prov get $path]
        }
    }
}
```

Two things the application owns, not the widget:

- **Type -> kind.** The `switch` above. A different app could map the same
  extensions to different kinds.
- **Decoding.** Providers return raw bytes; the text-shaped kinds need a decoded
  string, so the app applies `encoding convertfrom utf-8` (and strips a BOM if
  present). The widget receives a finished string.

## Binary kinds take a file path

`image`, `pdf` and `sqlite` open a file, so for a provider-backed file, write the
bytes to a temp file first and hand over the path:

```tcl
set tmp [file tempfile]
set fh [open $tmp wb] ; puts -nonewline $fh [$prov get $path] ; close $fh
::tkutils::tkupreview::pdf $pv [file tail $path] $tmp
```

## Graceful fallback

Structured kinds (markdown, json, html, csv, sqlite, ...) render through sibling
widgets when those are available and fall back to plain text otherwise, so the
preview never errors just because an optional renderer is missing. Query the
result with `::tkutils::tkupreview::kind $pv`.

## See also

- [howto-browse-provider.md](howto-browse-provider.md)
- [howto-build-file-manager.md](howto-build-file-manager.md)
- Module doc: [`../tkupreview.md`](../tkupreview.md)
