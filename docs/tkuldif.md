# tkutils::tkuldif

LDIF entry viewer. Each entry is a tree node labelled with its dn, with one
child row per attribute value. Built on tclutils::tuldif (requires tclutils
0.31.0+).

```tcl
set w [::tkutils::tkuldif::widget .w]
::tkutils::tkuldif::loadText   $w ldifText   ;# -> entry count
::tkutils::tkuldif::loadFile   $w file
::tkutils::tkuldif::setEntries $w entries
::tkutils::tkuldif::entries    $w
::tkutils::tkuldif::count      $w
::tkutils::tkuldif::treeWidget $w
```

## Editing (0.26.0)
`-editable 1` (default) shows an edit bar (Attr/Value + Set/Add/Del, Add/Del
Entry). All attribute rows incl. dn are editable. Programmatic ops:
```tcl
tkuldif::addEntry   $w ?dn?                 ;# -> index
tkuldif::removeEntry $w index
tkuldif::addAttr    $w entryIndex attr value
tkuldif::setAttr    $w entryIndex pairIndex attr value
tkuldif::removeAttr $w entryIndex pairIndex
tkuldif::toText     $w        ;# current entries as LDIF
tkuldif::save       $w file
```
