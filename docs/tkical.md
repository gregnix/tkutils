# tkutils::tkical

iCalendar event viewer. Shows the VEVENTs of an iCalendar document in a table
(Summary, Start, End, Location). Built on tclutils::tuical (requires tclutils
0.31.0+).

```tcl
set w [::tkutils::tkical::widget .w]
::tkutils::tkical::loadText      $w icsText   ;# -> event count
::tkutils::tkical::loadFile      $w file
::tkutils::tkical::setComponents $w comps
::tkutils::tkical::events        $w
::tkutils::tkical::count         $w
::tkutils::tkical::treeWidget    $w
```

## Editing (0.26.0)
`-editable 1` (default) shows an edit bar (Summary/Start/End/Location +
Set/Add/Delete). On save the events are written back into the calendar; its
other properties and non-event components are preserved. Programmatic ops:
```tcl
tkical::addEvent           $w ?summary?          ;# -> index
tkical::removeEvent        $w index
tkical::setField           $w index field value  ;# field: summary|start|end|location
tkical::setEventProperty   $w index name value ?params?
tkical::addEventProperty   $w index name value ?params?
tkical::removeEventProperty $w index name
tkical::toText             $w        ;# current calendar as iCalendar text
tkical::save               $w file
```
