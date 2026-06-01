# tkutils::tkini

Two-pane INI viewer: sections on the left, key/value pairs of the selected
section on the right. The global section "" is shown as "(global)". Built on
tclutils::tuini (requires tclutils 0.32.0+).

```tcl
set w [::tkutils::tkini::widget .w]
::tkutils::tkini::loadText      $w iniText   ;# -> section count
::tkutils::tkini::loadFile      $w file
::tkutils::tkini::setData       $w data
::tkutils::tkini::sections      $w
::tkutils::tkini::selectSection $w section
::tkutils::tkini::currentSection $w
::tkutils::tkini::data          $w
::tkutils::tkini::sectionWidget $w
::tkutils::tkini::treeWidget    $w
```

## Editing (0.25.0)
Pass `-editable 1` (default) for an edit bar (Section/Key/Value + buttons).
Programmatic ops:
```tcl
tkini::setKey        $w section key value
tkini::removeKey     $w section key
tkini::addSection    $w section
tkini::removeSection $w section
tkini::toText        $w            ;# current document as INI text
tkini::save          $w file
```
