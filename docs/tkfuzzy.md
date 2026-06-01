# tkutils::tkfuzzy

Incremental fuzzy filter. Built on `tclutils::tufuzzy`; an entry field filters a
list as you type. Items are kept when the pattern is a subsequence of them and
ranked by similarity.

## API
```tcl
set w [::tkutils::tkfuzzy::widget .w ?-height N?]
::tkutils::tkfuzzy::setItems     $w itemList
::tkutils::tkfuzzy::filter       $w pattern    ;# ranked matches (also updates list)
::tkutils::tkfuzzy::getMatches   $w
::tkutils::tkfuzzy::getSelection $w            ;# selected item or ""
```

## Launcher
```bash
tclsh bin/tkfuzzy.tcl items.txt    ;# one item per line
```
