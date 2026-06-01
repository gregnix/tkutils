# tkutils::tkbase64

Base64 encode/decode panel. Built on `tclutils::tubase64`. An input area, an
output area, and Encode/Decode buttons.

## API
```tcl
set w [::tkutils::tkbase64::widget .w ?-width N? ?-height N?]
::tkutils::tkbase64::setInput  $w text
::tkutils::tkbase64::encode    $w        ;# input -> Base64, returns output
::tkutils::tkbase64::decode    $w        ;# input -> plain, returns output
::tkutils::tkbase64::getInput  $w
::tkutils::tkbase64::getOutput $w
```

## Launcher
```bash
tclsh bin/tkbase64.tcl
```
