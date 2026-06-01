# tkutils::tkldif

LDIF entry viewer. Each entry is a tree node labelled with its dn, with one
child row per attribute value. Built on tclutils::tuldif (requires tclutils
0.31.0+).

```tcl
set w [::tkutils::tkldif::widget .w]
::tkutils::tkldif::loadText   $w ldifText   ;# -> entry count
::tkutils::tkldif::loadFile   $w file
::tkutils::tkldif::setEntries $w entries
::tkutils::tkldif::entries    $w
::tkutils::tkldif::count      $w
::tkutils::tkldif::treeWidget $w
```

## Editing (0.26.0)
`-editable 1` (default) shows an edit bar (Attr/Value + Set/Add/Del, Add/Del
Entry). All attribute rows incl. dn are editable. Programmatic ops:
```tcl
tkldif::addEntry   $w ?dn?                 ;# -> index
tkldif::removeEntry $w index
tkldif::addAttr    $w entryIndex attr value
tkldif::setAttr    $w entryIndex pairIndex attr value
tkldif::removeAttr $w entryIndex pairIndex
tkldif::toText     $w        ;# current entries as LDIF
tkldif::save       $w file
```
