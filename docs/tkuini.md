# tkutils::tkuini

Two-pane INI viewer: sections on the left, key/value pairs of the selected
section on the right. The global section "" is shown as "(global)". Built on
tclutils::tuini (requires tclutils 0.32.0+).

```tcl
set w [::tkutils::tkuini::widget .w]
::tkutils::tkuini::loadText      $w iniText   ;# -> section count
::tkutils::tkuini::loadFile      $w file
::tkutils::tkuini::setData       $w data
::tkutils::tkuini::sections      $w
::tkutils::tkuini::selectSection $w section
::tkutils::tkuini::currentSection $w
::tkutils::tkuini::data          $w
::tkutils::tkuini::sectionWidget $w
::tkutils::tkuini::treeWidget    $w
```

## Editing (0.25.0)
Pass `-editable 1` (default) for an edit bar (Section/Key/Value + buttons).
Programmatic ops:
```tcl
tkuini::setKey        $w section key value
tkuini::removeKey     $w section key
tkuini::addSection    $w section
tkuini::removeSection $w section
tkuini::toText        $w            ;# current document as INI text
tkuini::save          $w file
```

Files: `loadFile` reads and `save` writes UTF-8 with LF, whatever the
system encoding (since 0.3).
A failed write leaves the old file and no open channel: the text goes to a
temporary file first (`tclutils::common::replaceFile`, tkutils 0.49.0).

With tclutils `tuini` 0.2, `setKey` and `addSection` raise
`{TCLUTILS TUINI VALUE}` for what INI cannot hold (a line break in a value,
`=` in a key, ...); the data stay unchanged. The edit bar trims key and
section name and shows such an error as a message instead.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tkuini::count path                             ;# return the number of entries currently shown
```
