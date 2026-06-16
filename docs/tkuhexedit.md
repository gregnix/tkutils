# tkutils::tkuhexedit

## Name

`tkutils::tkuhexedit` - small Tcl/Tk hex viewer/editor widget.

## Synopsis

```tcl
package require tkutils::tkuhexedit

set w [::tkutils::tkuhexedit::widget .hex]
pack $w -fill both -expand 1

::tkutils::tkuhexedit::loadFile $w file.bin
::tkutils::tkuhexedit::gotoOffset $w 0x100
::tkutils::tkuhexedit::findHex $w {50 4B 03 04}
::tkutils::tkuhexedit::patchHex $w 0x100 {00 FF}
::tkutils::tkuhexedit::saveFile $w
```

## Description

The widget displays binary data as offset, hexadecimal bytes and printable ASCII.
It provides a compact GUI for inspection and small length-preserving patches.

`patchHex` replaces existing bytes. It does not insert or delete bytes.

## Public procedures

```tcl
widget path ?options?
loadFile path filename
saveFile path ?filename?
setData path bytes
getData path
gotoOffset path offset
findText path pattern ?start?
findHex path hex ?start?
patchHex path offset hex
render path ?offset?
```

## Options for widget

```text
-width        text widget width
-height       text widget height
-bytesperline bytes per rendered line, default 16
```

## Limits

- Not a full binary editor.
- No insert/delete mode.
- No large-file streaming yet; data is kept in memory.
- Requires Tk and therefore a graphical display.

## See also

`tclutils::tubin`, `tclutils::tuhexdump`, `tclutils::common` (required).

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tkuhexedit::findText path pattern ?start?      ;# search the buffer and select the first match
tkuhexedit::getData path                       ;# return the current edit buffer as raw bytes
tkuhexedit::render path ?startOffset?          ;# redraw the hex and ASCII columns from the current buffer
tkuhexedit::setData path data                  ;# replace the edit buffer with raw bytes DATA
```
