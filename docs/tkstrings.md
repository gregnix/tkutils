# tkutils::tkstrings

Printable-strings viewer (like the Unix `strings` tool). Built on
`tclutils::tustrings`; lists the printable ASCII runs found in binary data.

## API
```tcl
set w [::tkutils::tkstrings::widget .w ?-height N?]
::tkutils::tkstrings::setData    $w bytes  ?-minlength N?   ;# returns count
::tkutils::tkstrings::loadFile   $w path   ?-minlength N?   ;# returns count
::tkutils::tkstrings::getStrings $w
```

## Launcher
```bash
tclsh bin/tkstrings.tcl somefile.bin
```
