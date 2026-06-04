# tkutils::tkuform

A declarative form widget. Build a labelled form from a field spec and collect
the values as a dict. Pure Tk.

## Field spec
A list of field dicts. Keys: `name` (required), `label`, `type`
(`entry|password|check|combo|spin|text`, default `entry`), `default`,
`values` (combo), `from`/`to` (spin), `height` (text).

## API
```tcl
set w [::tkutils::tkuform::widget .w $fieldspec]
::tkutils::tkuform::values     $w            ;# -> dict name -> value
::tkutils::tkuform::get        $w name
::tkutils::tkuform::set        $w name value
::tkutils::tkuform::setValues  $w dict        ;# unknown keys ignored
::tkutils::tkuform::fieldNames $w
::tkutils::tkuform::widgetOf   $w name        ;# the control widget
```

## Launcher
```bash
tclsh bin/tkuform.tcl
```
