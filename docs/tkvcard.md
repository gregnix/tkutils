# tkutils::tkvcard

vCard contact viewer. Each card is a tree node labelled with its FN; each
property is a child row (Value + a Type hint from any TYPE parameter). Built on
tclutils::tuvcard (requires tclutils 0.32.0+).

```tcl
set w [::tkutils::tkvcard::widget .w]
::tkutils::tkvcard::loadText   $w vcfText   ;# -> contact count
::tkutils::tkvcard::loadFile   $w file
::tkutils::tkvcard::setCards   $w cards
::tkutils::tkvcard::cards      $w
::tkutils::tkvcard::count      $w
::tkutils::tkvcard::treeWidget $w
```

## Editing (0.25.0)
Pass `-editable 1` (default) for an edit bar (Name/Value/Type + buttons; all
properties incl. FN are now shown as editable rows). Programmatic ops:
```tcl
tkvcard::addCard        $w ?fn?                       ;# -> index
tkvcard::removeCard     $w cardIndex
tkvcard::addProperty    $w cardIndex name value ?type?
tkvcard::setProperty    $w cardIndex propIndex name value ?type?
tkvcard::removeProperty $w cardIndex propIndex
tkvcard::toText         $w           ;# current contacts as vCard text
tkvcard::save           $w file
```

## Photo pane

The widget shows a photo pane to the right of the tree. When a contact is
selected, its `PHOTO` is rendered: inline PNG/GIF photos appear as a thumbnail
(via `tuvcard::photo` + `tkutils::tkimage`), URI photos are shown as text, and
formats Tk cannot decode (e.g. JPEG without the Img extension) show a note.
The `-photosize` option (default 120) sets the thumbnail box in pixels.
