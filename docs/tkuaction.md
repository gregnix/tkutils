# tkutils::tkuaction

Action abstraction: define a UI action once -- label, command, icon,
accelerator, enabled/checked state -- and register any number of widgets against
it. A single `setEnabled` / `setChecked` / `invoke` then keeps every registered
widget in sync. This module is the **model**; rendering stays in the widgets, so
there is no duplicated toolbar/menu code. Pure Tk.

## Define / query

```tcl
::tkutils::tkuaction::define save -label "Save" -command {saveDoc} \
    ?-accelerator "Ctrl+S"? ?-icon img? ?-iconChecked img? ?-tooltip s? \
    ?-checkable 0|1? ?-enabled 0|1? ?-checked 0|1? ?-compound side?
::tkutils::tkuaction::exists save                 ;# 0|1
::tkutils::tkuaction::get    save ?key?           ;# whole dict or one field
::tkutils::tkuaction::names                        ;# all action names
::tkutils::tkuaction::delete save
```

A tooltip is derived from the label (plus accelerator) when not given.

## State (the heart)

```tcl
::tkutils::tkuaction::setEnabled save 0|1          ;# greys out every bound widget
::tkutils::tkuaction::setChecked wrap 0|1          ;# pressed look / iconChecked swap
::tkutils::tkuaction::getEnabled save
::tkutils::tkuaction::getChecked wrap
::tkutils::tkuaction::toggle     wrap
::tkutils::tkuaction::invoke     save              ;# runs command if enabled; toggles if checkable
```

## Bind widgets

```tcl
::tkutils::tkuaction::register   save $widget       ;# usually done by the widget
::tkutils::tkuaction::unregister save $widget
```

`tkutils::tkutoolbar::addAction $tb save` creates a button from the action and
registers it for you, so toolbar buttons track `setEnabled`/`setChecked`.

## Groups

```tcl
::tkutils::tkuaction::groupDefine imageLoaded {zoom_in zoom_out fit rotate}
::tkutils::tkuaction::groupSet    imageLoaded 0|1   ;# enable/disable the whole set
::tkutils::tkuaction::groupAdd    imageLoaded crop
::tkutils::tkuaction::groupList   ?name?
::tkutils::tkuaction::reset                          ;# drop all actions and groups
```

## Notes

- Registered widgets are reconfigured generically (`-state`, pressed state,
  `-image`); menu-entry binding is a future extension.
- Errors carry `{TKUTILS TKUACTION <REASON>}`
  (`OPTION`, `NOACTION`, `NOGROUP`).

## Demo

```bash
tclsh examples/demo-tkuaction.tcl
```
