# tkutils::tkumdview

Markdown viewer widget: a two-pane frame with a headings outline on the left and
a rendered preview on the right, with back/forward and search above. The
document is parsed by `tclutils::tumd` (`parse`, `inline`), so the preview, the
outline and `toHtml` always agree, and the viewer needs no browser. Pure
Tk/ttk; namespace `::tkutils::tkumdview`. Needs `tclutils::tumd` 0.3.

## API
```tcl
set w [::tkutils::tkumdview::widget .w ?option value ...?]   ;# -> frame path
::tkutils::tkumdview::loadFile    $w path            ;# read utf-8 file, render -> char count
::tkutils::tkumdview::setMarkdown $w md ?-dir dir?   ;# set text, render -> char count
::tkutils::tkumdview::getMarkdown $w                 ;# current document source
::tkutils::tkumdview::currentFile $w                 ;# file shown, "" after setMarkdown
::tkutils::tkumdview::headings    $w                 ;# outline of the current document
::tkutils::tkumdview::toHtml      $w ?option ...?    ;# HTML (options of tumd::toHtml)
::tkutils::tkumdview::follow      $w href            ;# act as a click on a link
::tkutils::tkumdview::back        $w                 ;# previous document -> 1/0
::tkutils::tkumdview::forward     $w                 ;# next document -> 1/0
::tkutils::tkumdview::find        $w pattern         ;# mark hits -> count
::tkutils::tkumdview::findNext    $w ?-backwards?    ;# next hit -> index
::tkutils::tkumdview::zoom        $w ?delta|reset?   ;# font size step -> step
::tkutils::tkumdview::tocWidget   $w                 ;# path of the outline list
::tkutils::tkumdview::textWidget  $w                 ;# path of the preview text widget
```

## Widget options

| option | default | meaning |
|---|---|---|
| `-width`, `-height` | `72`, `26` | size of the preview in characters and lines |
| `-toolbar` | `1` | back, forward and the search field above the panes |
| `-findlabel` | `Find:` | label of the search field |
| `-linkcommand` | | called with the target of a link that is no anchor and no Markdown file |

An unknown option raises `{TKUTILS TKUMDVIEW OPTION name}`.

## What is rendered

- headings (`#` and setext), paragraphs, hard line breaks
- lists, nested (deeper margin, bullets `•`, `◦`, `▪`), start number of a
  numbered list, task items as `☐` and `☑`, continuation lines
- block quotes (grey margin), also with lists and code inside
- fenced and indented code on a grey background
- GitHub tables (below), horizontal rules
- bold, italic, both, strikethrough, inline code, links, bare URLs, entities
- images (PNG, GIF and what Tk reads) relative to the document; otherwise the
  alt text in brackets
- footnotes: a small number in the text, the notes at the end, linked both
  ways

## Links

A click on a link:

- `#id` scrolls to the heading with that id (as `tumd` makes it) or to a
  footnote (`#fn-1`, `#fnref-1`);
- a `.md` or `.markdown` file, relative to the document, opens in the viewer,
  with `#id` scrolled to; back and forward return;
- anything else (a URL, another file as full path) goes to `-linkcommand`,
  or, without it, to `tclutils::tuopen::launch` if that package is there.

`follow` does the same from a script and returns `anchor`, `file`,
`external` or `""` (anchor not found). A missing `.md` file raises
`{TKUTILS TKUMDVIEW LINK}`. For text given with `setMarkdown`, `-dir` is the
folder for relative links and images (default: the current directory).
`loadFile` and `setMarkdown` start a new history; following links adds to it.

## Outline, search and keys

The left pane lists the document's headings. Selecting an entry scrolls the
preview to it; when the preview is scrolled, the outline marks the heading at
its top.

The search field marks every hit (case ignored) and goes to the first one
below the top of the view; Return goes to the next, Shift+Return to the
previous, Escape empties the field. The counter shows `hit/hits`.

| key | in the preview or outline |
|---|---|
| Ctrl+F | to the search field |
| Alt+Left, Alt+Right | back, forward |
| Ctrl+plus, Ctrl+minus, Ctrl+0 | larger, smaller, normal font |
| Ctrl+mouse wheel | larger, smaller |

`zoom` changes the fonts of all viewers in the application (named fonts
`mdvBase`, `mdvBold`, `mdvMono`, `mdvH1` ...) and keeps the view where it was.

## Tables

A table is a header row, a separator row and body rows:

```markdown
| Status | Meaning   | Amount |
|:-------|:---------:|-------:|
| paid   | `ok`      |   1,00 |
| open   | *later*   |  10,00 |
```

Columns are laid out with tab stops measured from the cell text in the
fonts actually used, so they line up with proportional fonts too. The
separator row sets the alignment (`:--` left, `:-:` centre, `--:` right).
The header is bold on a grey background, body rows alternate a light
background, inline markup works inside cells, and `\|` is a literal pipe.
Table lines do not wrap; the preview has a horizontal scrollbar for wide
tables. Lines with pipes but no separator row stay a paragraph. Each table
gets its own tag (`tbl1`, `tbl2`, ...) carrying its tab stops; the shared
tags are `table`, `thead` and `trowalt`.

## Tags

Text tags of the preview, for restyling through `textWidget`: `h1` ... `h6`,
`para`, `li`, `pre`, `quote`, `hr`, `code`, `strong`, `em`, `strongem`,
`del`, `link`, `sup`, `imgalt`, `table`, `thead`, `trowalt`, `found`,
`foundcur`. Margins come from tags named `m<left>_<left2>_<quote>`.

```tcl
package require tkutils::tkumdview
set w [::tkutils::tkumdview::widget .v -findlabel Suchen:]
pack $w -fill both -expand 1
::tkutils::tkumdview::loadFile $w README.md
set html [::tkutils::tkumdview::toHtml $w -page 1]   ;# same document, as a page
```
