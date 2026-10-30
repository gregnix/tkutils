# tkutils::tkuvcard

vCard contact viewer. Each card is a tree node labelled with its FN; each
property is a child row (Value + a Type hint from any TYPE parameter). Built on
tclutils::tuvcard (requires tclutils 0.32.0+).

```tcl
set w [::tkutils::tkuvcard::widget .w]
::tkutils::tkuvcard::loadText   $w vcfText   ;# -> contact count
::tkutils::tkuvcard::loadFile   $w file
::tkutils::tkuvcard::setCards   $w cards
::tkutils::tkuvcard::cards      $w
::tkutils::tkuvcard::count      $w
::tkutils::tkuvcard::treeWidget $w
```

## Editing (0.25.0)
Pass `-editable 1` (default) for an edit bar (Name/Value/Type + buttons; all
properties incl. FN are now shown as editable rows). Programmatic ops:
```tcl
tkuvcard::addCard        $w ?fn?                       ;# -> index
tkuvcard::removeCard     $w cardIndex
tkuvcard::addProperty    $w cardIndex name value ?type?
tkuvcard::setProperty    $w cardIndex propIndex name value ?type?
tkuvcard::removeProperty $w cardIndex propIndex
tkuvcard::toText         $w           ;# current contacts as vCard text
tkuvcard::save           $w file
```

`type` is a comma-separated list of TYPE values (`"CELL, VOICE"`); `""`
means no TYPE. `setProperty` keeps the other parameters of the line
(`PREF`, `LABEL`, `VALUE` ...) and, when `type` equals the current TYPE
values, those as they were (since 0.3; up to 0.2 every parameter but TYPE
was lost).

Files: `loadFile` reads and `save` writes UTF-8, whatever the system
encoding (since 0.3). `save` writes the text of `toText` unchanged, with
CRLF line ends (up to 0.2 it wrote `\r\r\n`).
A failed write leaves the old file and no open channel: the text goes to a
temporary file first (`tclutils::common::replaceFile`, tkutils 0.49.0).

## Photo pane

The widget shows a photo pane to the right of the tree. When a contact is
selected, its `PHOTO` is rendered: inline PNG/GIF photos appear as a thumbnail
(via `tuvcard::photo` + `tkutils::tkuimage`), URI photos are shown as text, and
formats Tk cannot decode (e.g. JPEG without the Img extension) show a note.
The `-photosize` option (default 120) sets the thumbnail box in pixels.
