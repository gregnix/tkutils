# tkutils::tkuxml

XML tree viewer. Shows an XML document as a nested tree (element names plus their
attributes / text). Parsing is done by **tDOM**.

> Optional widget. tDOM is an external dependency and is *not* part of tclutils,
> so tkuxml is not loaded by the tkutils umbrella. Ensure tdom is installed, then
> `package require tkutils::tkuxml`.

## API
```tcl
set w [::tkutils::tkuxml::widget .w ?-height N?]
::tkutils::tkuxml::setXml   $w xmlText    ;# returns root element name
::tkutils::tkuxml::loadFile $w path
::tkutils::tkuxml::getRoot  $w
```

## Launcher
```bash
tclsh bin/tkuxml.tcl document.xml
```
