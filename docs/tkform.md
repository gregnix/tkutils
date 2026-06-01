# tkutils::tkform

A declarative form widget. Build a labelled form from a field spec and collect
the values as a dict. Pure Tk.

## Field spec
A list of field dicts. Keys: `name` (required), `label`, `type`
(`entry|password|check|combo|spin|text`, default `entry`), `default`,
`values` (combo), `from`/`to` (spin), `height` (text).

## API
```tcl
set w [::tkutils::tkform::widget .w $fieldspec]
::tkutils::tkform::values     $w            ;# -> dict name -> value
::tkutils::tkform::get        $w name
::tkutils::tkform::set        $w name value
::tkutils::tkform::setValues  $w dict        ;# unknown keys ignored
::tkutils::tkform::fieldNames $w
::tkutils::tkform::widgetOf   $w name        ;# the control widget
```

## Launcher
```bash
tclsh bin/tkform.tcl
```
