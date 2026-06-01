# tkutils::tkzip

ZIP archive browser. Built on `tclutils::tuzip`; lists archive members in a
ttk::treeview (name, uncompressed size, compressed size, method).

## API
```tcl
set w [::tkutils::tkzip::widget .w ?-height N?]
::tkutils::tkzip::openFile       $w zipfile   ;# returns member count
::tkutils::tkzip::getEntries     $w           ;# list of dicts (tuzip::entries)
::tkutils::tkzip::selectedMember $w           ;# selected name or ""
```

## Launcher
```bash
tclsh bin/tkzip.tcl archive.zip
```
