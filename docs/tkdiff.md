# tkutils::tkdiff

Line diff viewer. Built on `tclutils::tudiff`; shows the structured diff with
deleted lines highlighted red and inserted lines green.

## API
```tcl
set w [::tkutils::tkdiff::widget .w ?-width N? ?-height N?]
::tkutils::tkdiff::setTexts  $w oldText newText ?...?   ;# options pass to tudiff::text
::tkutils::tkdiff::loadFiles $w oldFile newFile ?...?
::tkutils::tkdiff::getOps    $w                          ;# list of {op token}
```

## Launcher
```bash
tclsh bin/tkdiff.tcl old.txt new.txt
```
