# tkutils::tkxml

XML tree viewer. Shows an XML document as a nested tree (element names plus their
attributes / text). Parsing is done by **tDOM**.

> Optional widget. tDOM is an external dependency and is *not* part of tclutils,
> so tkxml is not loaded by the tkutils umbrella. Ensure tdom is installed, then
> `package require tkutils::tkxml`.

## API
```tcl
set w [::tkutils::tkxml::widget .w ?-height N?]
::tkutils::tkxml::setXml   $w xmlText    ;# returns root element name
::tkutils::tkxml::loadFile $w path
::tkutils::tkxml::getRoot  $w
```

## Launcher
```bash
tclsh bin/tkxml.tcl document.xml
```
