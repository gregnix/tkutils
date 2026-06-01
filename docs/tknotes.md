# tkutils::tknotes

A hierarchical notes widget: a tree of notes on the left, a title/tags/content
editor on the right, an action bar (New Root, New Child, Delete, Save) and a
search box. All note logic and JSON persistence come from the tclutils engine
`tunotes` (requires tclutils 0.30.0+); this widget only renders and edits.

## API
```tcl
set w [::tkutils::tknotes::widget .w ?-file notes.json? ?-toolbar 0?]
::tkutils::tknotes::addRoot   $w title content ?tags?       ;# -> id
::tkutils::tknotes::addChild  $w parentId title content ?tags?
::tkutils::tknotes::select    $w id
::tkutils::tknotes::commit    $w ?id?      ;# editor fields -> store
::tkutils::tknotes::delete    $w id ?cascade?
::tkutils::tknotes::move      $w id newParentId  ;# "" = root
::tkutils::tknotes::search    $w query     ;# -> ids
::tkutils::tknotes::load      $w file      ;# -> count
::tkutils::tknotes::save      $w ?file?
::tkutils::tknotes::store     $w           ;# the tunotes store (dict)
::tkutils::tknotes::count     $w
::tkutils::tknotes::current   $w
::tkutils::tknotes::treeWidget $w
```

## Launcher
```bash
tclsh bin/tknotes.tcl ?notes.json?
```

## Added in 0.24.0
```tcl
tknotes::expandAll   $w
tknotes::collapseAll $w
tknotes::tags        $w           ;# all distinct tags
tknotes::byTag       $w tag       ;# ids with a tag
tknotes::addTag      $w id tag    ;# refreshes view + editor
tknotes::removeTag   $w id tag
tknotes::subtree     $w id        ;# standalone store of a branch
tknotes::saveSubtree $w id file   ;# export branch to JSON
```
