# tkutils::tkutemplate

Editor for document templates: place blocks on the page, edit their
attributes and table columns, preview the result as a PDF. Built on
`tkutils::tkulayoutcanvas` (placing), `tclutils::tulayout` (merging) and
`tclutils::tuopen` (opening the preview). The preview uses `pdf4tcltemplate`
from pdf4tcllib, which is loaded only when a preview is asked for.

A template is the dict `pdf4tcltemplate` draws:

```tcl
paper a4  margin 20  size 10
theme {accent {0.15 0.30 0.20}}
blocks {
    address {x 20 y 50 w 85 size 11 list 1}
    items   {type table x 20 y 108 w 170 cols {{key pos title Pos w 12} {key text title Item}}}
    note    {x 20 y 0 w 170 gap 8}
}
```

`tkulayoutcanvas` knows only `x y w h show`. The editor gives it those,
takes back what was dragged or typed there, and merges it with
`tulayout::mergeLayout` (keys `x y w show`), so type, font size, text,
columns and the rest are never lost. The `h` the canvas shows is an
estimate from the type and the sample data; it is not written back.

## API

```tcl
set te [::tkutils::tkutemplate::widget .te ?options?]
::tkutils::tkutemplate::getTemplate $te
::tkutils::tkutemplate::setTemplate $te $template
::tkutils::tkutemplate::setSample $te $data
::tkutils::tkutemplate::select $te $blockId
::tkutils::tkutemplate::addBlock $te $id ?type?          ;# text pairs table image rule
::tkutils::tkutemplate::deleteBlock $te $id
::tkutils::tkutemplate::moveBlock $te $id up|down
::tkutils::tkutemplate::setBlock $te $id key value ?key value ...?
::tkutils::tkutemplate::loadFile $te $file
::tkutils::tkutemplate::saveFile $te $file
::tkutils::tkutemplate::preview $te ?file?               ;# -> PDF file
```

`setBlock` checks what it sets (numbers, booleans, `type`, `page`, `align`,
colour as a theme name or `r g b`) and raises `{TKUTILS TKUTEMPLATE VALUE}`
otherwise. An empty value removes the attribute, except `type` and `cols`.
A block that becomes a table gets two columns, an image a height.

`moveBlock` changes the order, which matters: a block with `y 0` follows
the block before it.

### Options

| Option | Default | Meaning |
|--------|---------|---------|
| `-template` | `{blocks {}}` | the template to edit |
| `-sample` | `{}` | data for the preview, keyed like the data of `pdf4tcltemplate` |
| `-onchange` | `{}` | `cmd $path $template` after every change |
| `-scale` | `2.5` | pixels per mm on the canvas |
| `-gridmm` | `5` | snap grid in mm |
| `-font` / `-fontbold` | `{}` | fonts for the preview; default: pdf4tcllib's TrueType faces |
| `-width` / `-height` | `560` / `640` | canvas size |

### The window

- Toolbar: **Add block** (by type), **Delete**, **Up**, **Down**, **Load…**,
  **Save…**, **Preview**.
- Left: the page (`tkulayoutcanvas`) with the block list, x/y/w and
  visibility.
- Right, three tabs:
  - **Block** -- id (Return renames), type, size, bold, colour, align,
    leading, gap, page, field, list, labelw, h, zebra, text. A field is taken on
    Return or when it loses the focus; a bad value rings, shows the
    message under the editor and is undone.
  - **Columns** -- the columns of a table block: key, title, w, align;
    add, delete, up, down.
  - **Page** -- paper, margin, top, bottom, font size, the colours `accent`
    and `muted`.

### Preview

`preview` draws the template with `-sample` into a PDF and returns the file
(a temp file when none is given); the button opens it with the system
viewer. A block without sample data shows a stand-in -- its id, a label/value
pair, three table rows with the column keys -- so every block is visible.
Without pdf4tcllib or without pdf4tcl the editor works, and `preview`
raises `{TKUTILS TKUTEMPLATE PREVIEW}` -- also when something goes wrong
while drawing; a temp file it made is removed again.

### Files

`saveFile` writes the template as Tcl, one block per line, so it reads well
in an editor and in a diff. `loadFile` reads it back; the result equals the
saved template.

## Launcher

```bash
wish bin/tkutemplate.tcl ?template.tcl?
```

## Demo

```bash
wish examples/demo-tkutemplate.tcl
```

## Tests

```bash
xvfb-run -a tclsh tests/tkutemplate.test
```

The preview tests need pdf4tcllib (sibling checkout or `PDF4TCLLIB_TM`)
and pdf4tcl (`TCLLIBPATH`), one of them `pdftotext`; without them they are
skipped. With pdf4tcllib but without pdf4tcl, a test checks that `preview`
reports `{TKUTILS TKUTEMPLATE PREVIEW}`.

## Error codes

`{TKUTILS TKUTEMPLATE OPTION|EXISTS|NOWIDGET|BLOCK|VALUE|FILE|PREVIEW}`
