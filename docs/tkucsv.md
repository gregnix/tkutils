# tkutils::tkucsv

CSV table viewer. Built on `tclutils::tucsv`; rows are shown in a ttk::treeview.

## API
```tcl
set w [::tkutils::tkucsv::widget .w ?-height N? ?-header 0|1?]
::tkutils::tkucsv::setData  $w csvText ?-delimiter C? ?...?   ;# options pass to tucsv::parse
::tkutils::tkucsv::loadFile $w path    ?...?
::tkutils::tkucsv::getRows  $w                                ;# all rows (incl. header)
```
With `-header 1` (default) the first row is used as column headings.

## Launcher
```bash
tclsh bin/tkucsv.tcl data.csv
```
