# tkutils::tkuzip

ZIP archive browser. Built on `tclutils::tuzip`; lists archive members in a
ttk::treeview (name, uncompressed size, compressed size, method).

## API
```tcl
set w [::tkutils::tkuzip::widget .w ?-height N?]
::tkutils::tkuzip::openFile       $w zipfile   ;# returns member count
::tkutils::tkuzip::getEntries     $w           ;# list of dicts (tuzip::entries)
::tkutils::tkuzip::selectedMember $w           ;# selected name or ""
```

## Launcher
```bash
tclsh bin/tkuzip.tcl archive.zip
```
