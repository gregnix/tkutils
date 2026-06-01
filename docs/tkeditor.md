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
::tkutils::tkeditor::isModified  $w
```

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
