# tkutils::tkcsv

CSV table viewer. Built on `tclutils::tucsv`; rows are shown in a ttk::treeview.

## API
```tcl
set w [::tkutils::tkcsv::widget .w ?-height N? ?-header 0|1?]
::tkutils::tkcsv::setData  $w csvText ?-delimiter C? ?...?   ;# options pass to tucsv::parse
::tkutils::tkcsv::loadFile $w path    ?...?
::tkutils::tkcsv::getRows  $w                                ;# all rows (incl. header)
```
With `-header 1` (default) the first row is used as column headings.

## Launcher
```bash
tclsh bin/tkcsv.tcl data.csv
```
