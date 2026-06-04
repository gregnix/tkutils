# tkutils::tktodo

A task-list widget for iCalendar **VTODO** components, built on
`tclutils::tuical`. Shows summary, due date, priority and percent-complete in a
`ttk::treeview`; in editable mode the done state of a task can be toggled.

```tcl
set w [tktodo::widget .t ?-editable 1? ?-onchange {}?]
pack $w -fill both -expand 1

tktodo::loadText .t $ics        ;# parse iCal text + extract all VTODOs
tktodo::setTodos .t $comps      ;# or hand a list of VTODO components
tktodo::count .t                ;# number of tasks
tktodo::todos .t                ;# current components (changes included)
tktodo::toggle .t ?index?       ;# flip done state of selected / given task
```

Toggling a task to done sets `STATUS:COMPLETED`, `PERCENT-COMPLETE:100` and a
`COMPLETED` timestamp; toggling back restores `NEEDS-ACTION`, `PERCENT-COMPLETE:0`
and removes `COMPLETED`. In editable mode, Space and double-click also toggle.
The `-onchange` script is called as `{*}$cmd $path` after a change, so an app can
persist (e.g. `tuical::toIcs [tktodo::todos .t]` then PUT via `tudav`).
