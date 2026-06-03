# tkutils::tkeditor

Simple text editor widget: an editable text area with file load/save, search and
modified tracking. File I/O uses the tclutils common helpers.

## API
```tcl
set w [::tkutils::tkeditor::widget .w ?-width N? ?-height N? ?-wrap mode?]
::tkutils::tkeditor::setText     $w text       ;# replace buffer (clears modified)
::tkutils::tkeditor::getText     $w
::tkutils::tkeditor::loadFile    $w path
::tkutils::tkeditor::saveFile    $w ?path?      ;# path optional if loaded from file
::tkutils::tkeditor::currentFile $w
::tkutils::tkeditor::find        $w needle ?-from idx? ?-nocase?   ;# index or ""
::tkutils::tkeditor::findAll     $w needle ?-nocase?               ;# list of indices
::tkutils::tkeditor::findNext    $w needle ?-nocase?               ;# select+see next, wraps
::tkutils::tkeditor::replace     $w needle repl ?-all? ?-nocase? ?-from idx?  ;# count
::tkutils::tkeditor::highlightAll $w needle ?-nocase? ?-tag NAME?  ;# tag matches, count
::tkutils::tkeditor::clearHighlight $w ?-tag NAME?
::tkutils::tkeditor::gotoLine    $w n            ;# move cursor to line n, scroll into view
::tkutils::tkeditor::cursor      $w              ;# current "line.col"
::tkutils::tkeditor::readonly    $w ?bool?       ;# get/set read-only (setText still works)
::tkutils::tkeditor::isModified  $w
```

## Search and replace

`find` returns the first match index from `-from` (default `1.0`); `findAll`
returns every match. `findNext` is the interactive variant: it searches forward
from the cursor, wraps to the top, selects the hit, moves the insert mark past
it and scrolls it into view, so calling it repeatedly walks through the matches.
`replace` changes the first match (or every match with `-all`) in a single undo
step and returns how many it replaced; the scan resumes past each replacement,
so a replacement that contains the needle is not re-matched. `highlightAll` tags
all matches (default tag `match`, restyle it via the text widget) and
`clearHighlight` removes them.

## Launcher
```bash
tclsh bin/tkeditor.tcl notes.txt
```

## Context menu (right click)

Right-clicking the text area opens an edit menu with Undo, Redo, Cut, Copy,
Paste, Delete and Select All (the selection items are enabled only when there is
a selection). The menu is extensible:

```tcl
::tkutils::tkeditor::menuWidget     $w            ;# the menu widget, to customize
::tkutils::tkeditor::addMenuItem    $w label cmd  ;# append a command entry
::tkutils::tkeditor::addMenuSeparator $w
::tkutils::tkeditor::selectAll      $w
```
