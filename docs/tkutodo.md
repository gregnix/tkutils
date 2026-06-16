# tkutils::tkutodo

A task-list widget for iCalendar **VTODO** components, built on
`tclutils::tuical`. Shows summary, due date, priority and percent-complete in a
`ttk::treeview`; in editable mode the done state of a task can be toggled.

```tcl
set w [tkutodo::widget .t ?-editable 1? ?-onchange {}?]
pack $w -fill both -expand 1

tkutodo::loadText .t $ics        ;# parse iCal text + extract all VTODOs
tkutodo::setTodos .t $comps      ;# or hand a list of VTODO components
tkutodo::count .t                ;# number of tasks
tkutodo::todos .t                ;# current components (changes included)
tkutodo::toggle .t ?index?       ;# flip done state of selected / given task
```

Toggling a task to done sets `STATUS:COMPLETED`, `PERCENT-COMPLETE:100` and a
`COMPLETED` timestamp; toggling back restores `NEEDS-ACTION`, `PERCENT-COMPLETE:0`
and removes `COMPLETED`. In editable mode, Space and double-click also toggle.
The `-onchange` script is called as `{*}$cmd $path` after a change, so an app can
persist (e.g. `tuical::toIcs [tkutodo::todos .t]` then PUT via `tudav`).

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tkutodo::treeWidget path                       ;# return the internal ttk::treeview widget path (for custom bindings or styling)
```
