# tkutils::tkueditor

Text editor widget: an editable text area with file load/save, search, modified
tracking, an optional toolbar and an optional status bar. Encoding-aware file
I/O goes through `tclutils::tuiconv` and defaults to utf-8; line endings are
normalised to LF in the buffer and restored on save.

## API
```tcl
set w [::tkutils::tkueditor::widget .w ?-width N? ?-height N? ?-wrap mode? \
          ?-toolbar bool? ?-statusbar bool? ?-encoding ENC? ?-eol lf|crlf?]
::tkutils::tkueditor::setText     $w text       ;# replace buffer (clears modified)
::tkutils::tkueditor::getText     $w
::tkutils::tkueditor::loadFile    $w path ?-encoding ENC?
::tkutils::tkueditor::saveFile    $w ?path? ?-encoding ENC? ?-eol lf|crlf?
::tkutils::tkueditor::currentFile $w
::tkutils::tkueditor::encoding    $w ?ENC?       ;# get/set encoding for load/save
::tkutils::tkueditor::eol         $w ?lf|crlf?   ;# get/set line-ending style for save
::tkutils::tkueditor::find        $w needle ?-from idx? ?-nocase?   ;# index or ""
::tkutils::tkueditor::findAll     $w needle ?-nocase?               ;# list of indices
::tkutils::tkueditor::findNext    $w needle ?-nocase?               ;# select+see next, wraps
::tkutils::tkueditor::replace     $w needle repl ?-all? ?-nocase? ?-from idx?  ;# count
::tkutils::tkueditor::highlightAll $w needle ?-nocase? ?-tag NAME?  ;# tag matches, count
::tkutils::tkueditor::clearHighlight $w ?-tag NAME?
::tkutils::tkueditor::gotoLine    $w n            ;# move cursor to line n, scroll into view
::tkutils::tkueditor::cursor      $w              ;# current "line.col"
::tkutils::tkueditor::readonly    $w ?bool?       ;# get/set read-only (setText still works)
::tkutils::tkueditor::isModified  $w
```

## Widget options

`-width`, `-height` and `-wrap` configure the underlying text widget as before.
`-toolbar` and `-statusbar` (both default `1`) decide whether the toolbar and
status bar are built; set them to `0` for a bare editor. `-encoding` (default
`utf-8`) and `-eol` (default `lf`) set the initial encoding and line-ending
style used by `loadFile`/`saveFile`.

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

## Encoding and line endings

File I/O is encoding-aware via `tclutils::tuiconv`. The default encoding is
`utf-8`, so a document loads and saves identically under Tcl 8.6 (whose channels
otherwise default to the system encoding -- cp1252 on Windows, latin-1
elsewhere) and Tcl 9 (utf-8). Override per call with `-encoding`, or set it for
the editor with `encoding $w ENC`; the value is remembered and reused on save.

Because `tuiconv` does no end-of-line translation, the editor handles it
itself. On load the file's style is detected, the buffer is normalised to LF
(what a Tk text widget expects), and the original style is remembered. On save
the buffer is converted back to that style. Read or change it with
`eol $w ?lf|crlf?`, or override a single save with `saveFile $w path -eol crlf`.

```tcl
::tkutils::tkueditor::loadFile $w doc.txt -encoding cp1252  ;# load a legacy file
::tkutils::tkueditor::encoding $w utf-8                      ;# convert on next save
::tkutils::tkueditor::saveFile $w doc.txt -eol crlf          ;# write Windows line ends
```

## Toolbar

When `-toolbar` is on, the editor builds a `tkutils::tkutoolbar` above the text
area with Open, Save, Undo, Redo, Cut, Copy, a search entry and a Find button.
Open and Save use the standard file dialogs; the search entry (and the Find
button) run `findNext`. Icons come from `tkutils::tkuicon`; without SVG support
(tksvg on Tk 8.6, native on Tk 9) the buttons fall back to their text labels.

```tcl
set tb [::tkutils::tkueditor::toolbarWidget $w]   ;# the tkutoolbar ("" if disabled)
::tkutils::tkutoolbar::addButton $tb run "Run" $cmd -tooltip "Run"   ;# add your own
```

## Status bar

When `-statusbar` is on, the editor builds a `tkutils::tkustatus` below the text
area. The main (left) message is free for the application; `loadFile`/`saveFile`
put the file name there. Named fields on the right show the modified flag, the
encoding, the line-ending style (LF/CRLF) and the cursor position (Ln/Col),
updated automatically as the cursor, selection or modified state change.

```tcl
::tkutils::tkueditor::statusbarWidget $w          ;# the tkustatus ("" if disabled)
::tkutils::tkueditor::setStatus       $w "Ready"  ;# set the main message
::tkutils::tkueditor::refreshStatus   $w          ;# recompute pos/mod/enc/eol fields
```

## Launcher
```bash
tclsh bin/tkueditor.tcl notes.txt
```

## Context menu (right click)

Right-clicking the text area opens an edit menu with Undo, Redo, Cut, Copy,
Paste, Delete and Select All (the selection items are enabled only when there is
a selection). The menu is extensible:

```tcl
::tkutils::tkueditor::menuWidget     $w            ;# the menu widget, to customize
::tkutils::tkueditor::addMenuItem    $w label cmd  ;# append a command entry
::tkutils::tkueditor::addMenuSeparator $w
::tkutils::tkueditor::selectAll      $w
```

## Dependencies

`tclutils::tuiconv` (encoding-aware I/O). When the toolbar or status bar is
enabled, `tkutils::tkutoolbar`, `tkutils::tkustatus` and, for icons,
`tkutils::tkuicon` (which uses `tclutils::tusvg`) are loaded as well.
