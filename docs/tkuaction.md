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
::tkutils::tkuaction::setEnabled save 0|1 ?$w?     ;# greys every bound widget; with $w only that toplevel
::tkutils::tkuaction::setChecked wrap 0|1          ;# pressed look / iconChecked swap
::tkutils::tkuaction::getEnabled save ?$w?
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

## Bind menu entries

A menu row is not a widget, so `register` cannot grey it. `addMenuItem`
creates the command entry and registers that index. `setEnabled` then uses
`entryconfigure -state`. The index is stored as a number at bind time.

```tcl
::tkutils::tkuaction::addMenuItem    $menu save
::tkutils::tkuaction::registerMenu   save $menu ?index?   ;# already-created row
::tkutils::tkuaction::unregisterMenu save $menu ?index?
```

## Groups

```tcl
::tkutils::tkuaction::groupDefine imageLoaded {zoom_in zoom_out fit rotate}
::tkutils::tkuaction::groupSet    imageLoaded 0|1 ?$w?  ;# enable/disable the whole set
::tkutils::tkuaction::groupAdd    imageLoaded crop
::tkutils::tkuaction::groupList   ?name?
::tkutils::tkuaction::reset                          ;# drop all actions and groups
```

## Notes

- Registered widgets are reconfigured generically (`-state`, pressed state,
  `-image`). Menu command entries follow `setEnabled` through `addMenuItem`
  / `registerMenu`.
- Without `$w`, `setEnabled` / `getEnabled` / `groupSet` are process-global
  (0.1). With `$w`, only widgets and menu entries in that toplevel change. A
  child is resolved with `winfo toplevel`. Menu widgets are themselves
  toplevels, so the first non-Menu ancestor is used. A later two-argument
  `setEnabled` clears window overrides. `invoke` always uses the global flag.
- Errors carry `{TKUTILS TKUACTION <REASON>}`
  (`OPTION`, `NOACTION`, `NOGROUP`, `WINDOW`).

## Demo

```bash
tclsh examples/demo-tkuaction.tcl
```
