# tkutils::tkudiff

Line diff viewer. Built on `tclutils::tudiff`; shows the structured diff with
deleted lines highlighted red and inserted lines green.

## API
```tcl
set w [::tkutils::tkudiff::widget .w ?-width N? ?-height N?]
::tkutils::tkudiff::setTexts  $w oldText newText ?...?   ;# options pass to tudiff::text
::tkutils::tkudiff::loadFiles $w oldFile newFile ?...?
::tkutils::tkudiff::getOps    $w                          ;# list of {op token}
```

## Launcher
```bash
tclsh bin/tkudiff.tcl old.txt new.txt
```
