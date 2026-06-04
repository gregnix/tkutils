# tkutils::tkujson

JSON tree viewer. Built on `tclutils::tujson::parseTyped` (tclutils 0.28.0+), so
objects, arrays and scalars are distinguished and shown as a nested tree in a
ttk::treeview (key column + value column).

## API
```tcl
set w [::tkutils::tkujson::widget .w ?-height N?]
::tkutils::tkujson::setJson   $w jsonText      ;# returns root node type
::tkutils::tkujson::loadFile  $w path
::tkutils::tkujson::getTree   $w               ;# typed tree {type value}
```

Objects show `object (N)`, arrays `array (N)`, scalars their value. Object keys
keep their order; array elements are labelled `[0]`, `[1]`, ...

## Launcher
```bash
tclsh bin/tkujson.tcl data.json
```
