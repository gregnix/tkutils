# tkutils::tkuload

Build a live Tk UI from a `.tkd` design (as produced by tkudesigner) and bind
values to its named widgets. Pure Tk; namespace `::tkuload`. Loads the render
engine `tkutils::tkurender` on demand.

## Build
```tcl
set ui [::tkuload::build         $parent $spec]   ;# spec = a .tkd dict
set ui [::tkuload::buildFromFile $parent $path]   ;# read the .tkd from disk
```
Returns a dict with `root` (the container the UI was built into), `byId`
(node id -> widget), `byType` (type -> list of widgets) and `byName` (handle
name -> widget, for nodes that were named in the designer). `$parent` must be
an existing widget.

## Values
Address controls by their designer name:
```tcl
::tkuload::widgetByName $ui name              ;# the control widget
::tkuload::setValue     $ui name value        ;# -> 1 set, 0 unknown name
::tkuload::getValue     $ui name              ;# -> value ("" if none)
::tkuload::fill         $ui {name value ...}  ;# set many (unknown skipped)
::tkuload::collect      $ui ?{name ...}?      ;# -> dict; default = all named
```
`setValue`/`getValue` dispatch on the resolved control class -- entry, ttk
entry/combobox/spinbox, text, listbox, tablelist, checkbutton, and tkutils
megawidgets (e.g. `tkunumentry`) through their inner entry -- neutralising
`-state`/`-validate` around the write so readonly and key-validated fields
round-trip.

## Embedding
A loaded UI is just widgets under `$parent`; no editor is attached, so no
selection or designer bindings are installed. Host code wires its own
behaviour, e.g.:
```tcl
bind [$tbl bodypath] <Double-1> {...}
```

## Errors
Carry `{TKULOAD <REASON>}`: `PARENT` (no such parent widget), `NONAME`
(`widgetByName` on an unknown name). `setValue` on an unknown name returns `0`
rather than erroring, so `fill` tolerates partial data.
