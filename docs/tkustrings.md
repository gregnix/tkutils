# tkutils::tkustrings

Printable-strings viewer (like the Unix `strings` tool). Built on
`tclutils::tustrings`; lists the printable ASCII runs found in binary data.

## API
```tcl
set w [::tkutils::tkustrings::widget .w ?-height N?]
::tkutils::tkustrings::setData    $w bytes  ?-minlength N?   ;# returns count
::tkutils::tkustrings::loadFile   $w path   ?-minlength N?   ;# returns count
::tkutils::tkustrings::getStrings $w
```

## Launcher
```bash
tclsh bin/tkustrings.tcl somefile.bin
```
