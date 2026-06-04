# tkutils::tkunotes

A hierarchical notes widget: a tree of notes on the left, a title/tags/content
editor on the right, an action bar (New Root, New Child, Delete, Save) and a
search box. All note logic and JSON persistence come from the tclutils engine
`tunotes` (requires tclutils 0.30.0+); this widget only renders and edits.

## API
```tcl
set w [::tkutils::tkunotes::widget .w ?-file notes.json? ?-toolbar 0?]
::tkutils::tkunotes::addRoot   $w title content ?tags?       ;# -> id
::tkutils::tkunotes::addChild  $w parentId title content ?tags?
::tkutils::tkunotes::select    $w id
::tkutils::tkunotes::commit    $w ?id?      ;# editor fields -> store
::tkutils::tkunotes::delete    $w id ?cascade?
::tkutils::tkunotes::move      $w id newParentId  ;# "" = root
::tkutils::tkunotes::search    $w query     ;# -> ids
::tkutils::tkunotes::load      $w file      ;# -> count
::tkutils::tkunotes::save      $w ?file?
::tkutils::tkunotes::store     $w           ;# the tunotes store (dict)
::tkutils::tkunotes::count     $w
::tkutils::tkunotes::current   $w
::tkutils::tkunotes::treeWidget $w
```

## Launcher
```bash
tclsh bin/tkunotes.tcl ?notes.json?
```

## Added in 0.24.0
```tcl
tkunotes::expandAll   $w
tkunotes::collapseAll $w
tkunotes::tags        $w           ;# all distinct tags
tkunotes::byTag       $w tag       ;# ids with a tag
tkunotes::addTag      $w id tag    ;# refreshes view + editor
tkunotes::removeTag   $w id tag
tkunotes::subtree     $w id        ;# standalone store of a branch
tkunotes::saveSubtree $w id file   ;# export branch to JSON
```
