# tkutils::tkuform

A declarative form widget. Build a labelled form from a field spec and collect
the values as a dict. Pure Tk.

## Field spec
A list of field dicts. Keys: `name` (required), `label`, `type`
(`entry|password|check|combo|spin|text`, default `entry`), `default`,
`values` (combo), `state` (combo: `normal|readonly`, default `normal`),
`from`/`to` (spin), `height` (text).

## API
```tcl
set w [::tkutils::tkuform::widget .w $fieldspec ?-padding P? ?-columns N?]
::tkutils::tkuform::values     $w            ;# -> dict name -> value
::tkutils::tkuform::get        $w name
::tkutils::tkuform::setField   $w name value ;# set one field
::tkutils::tkuform::setValues  $w dict        ;# unknown keys ignored
::tkutils::tkuform::fieldNames $w
::tkutils::tkuform::widgetOf   $w name        ;# the control widget
::tkutils::tkuform::showField  $w name 0|1    ;# hide / show a field (0.2)
::tkutils::tkuform::showOnly   $w names       ;# show these, hide the rest (0.2)
::tkutils::tkuform::isShown    $w name        ;# 1 if shown (0.2)
```

A hidden field keeps its value and its place; showing it again puts it back
where it was. The launcher editor uses this to show only the fields of the
chosen entry type.

The setter is `setField` (not `set`) so it does not shadow the Tcl `set`
builtin.

## Layout

`-padding P` sets the frame padding (default 8). `-columns N` (default 1) lays
the fields out in N side-by-side label+control column pairs, flowing
left-to-right then top-down; `N=1` reproduces the original single-column layout
exactly. `text`-type fields always take their own full-width row.

```tcl
::tkutils::tkuform::widget .w $fieldspec -columns 2
```

## Errors

Carry `{TKUTILS TKUFORM <REASON>}`: `OPTION` (unknown widget option), `VALUE`
(bad `-columns`), `SPEC` (field missing `name`), `TYPE` (unknown field type),
`NOFIELD` (get/setField/widgetOf on an unknown field). A spec error leaves no
partially-built widget behind.

## Launcher
```bash
tclsh bin/tkuform.tcl
```
