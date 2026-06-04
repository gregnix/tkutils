# tkutils::tkubase64

Base64 encode/decode panel. Built on `tclutils::tubase64`. An input area, an
output area, and Encode/Decode buttons.

## API
```tcl
set w [::tkutils::tkubase64::widget .w ?-width N? ?-height N?]
::tkutils::tkubase64::setInput  $w text
::tkutils::tkubase64::encode    $w        ;# input -> Base64, returns output
::tkutils::tkubase64::decode    $w        ;# input -> plain, returns output
::tkutils::tkubase64::getInput  $w
::tkutils::tkubase64::getOutput $w
```

## Launcher
```bash
tclsh bin/tkubase64.tcl
```
