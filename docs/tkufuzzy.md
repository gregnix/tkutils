# tkutils::tkufuzzy

Incremental fuzzy filter. Built on `tclutils::tufuzzy`; an entry field filters a
list as you type. Items are kept when the pattern is a subsequence of them and
ranked by similarity.

## API
```tcl
set w [::tkutils::tkufuzzy::widget .w ?-height N?]
::tkutils::tkufuzzy::setItems     $w itemList
::tkutils::tkufuzzy::filter       $w pattern    ;# ranked matches (also updates list)
::tkutils::tkufuzzy::getMatches   $w
::tkutils::tkufuzzy::getSelection $w            ;# selected item or ""
```

## Launcher
```bash
tclsh bin/tkufuzzy.tcl items.txt    ;# one item per line
```
