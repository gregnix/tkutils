# Architecture

`tkutils` is deliberately separate from `tclutils`.

```text
tclutils
    pure Tcl backend utilities
    no Tk dependency
    usable in tclsh, CI, servers and scripts

tkutils
    Tk user interfaces
    may depend on Tcl/Tk display facilities
    can reuse tclutils backends
```

Planned layering:

```text
tkutils::tkuhexedit
    GUI for binary inspection
    backend (in use): tclutils::tubin / tclutils::tuhexdump

tkutils::odfinspect
    GUI for ODF container inspection
    backend idea: tclutils::tuodf / tclutils::tuzip

tkutils::pdfinspect
    GUI for PDF structure inspection
    backend idea: tclutils::tupdf

tkutils::mdview
    GUI for Markdown navigation/preview
    backend idea: tclutils::tumd
```

- tkucsv  -> ttk::treeview, backend (in use): tclutils::tucsv
- tkudiff -> text widget, backend (in use): tclutils::tudiff
- tkumd   -> ttk::treeview, backend (in use): tclutils::tumd
- tkujson -> ttk::treeview, backend (in use): tclutils::tujson::parseTyped (0.28.0+)
- tkucal -> text view, backend (in use): tclutils::tucal
- tkueditor -> text widget, backend (in use): tclutils::common (file I/O)
- tkuzip -> ttk::treeview, backend (in use): tclutils::tuzip
- tkufuzzy -> entry + listbox, backend (in use): tclutils::tufuzzy
- tkuxml (optional) -> ttk::treeview, backend: tDOM (external)
- tkusqlite (optional) -> listbox + ttk::treeview, backend: sqlite3 (external)
- tkudialog -> toplevel dialogs, backend: pure Tk (copyable message text)
- tkubase64 -> text panes, backend (in use): tclutils::tubase64
- tkustrings -> listbox, backend (in use): tclutils::tustrings
- tkutoolbar -> ttk::frame of buttons, backend: pure Tk
- tkustatus -> ttk::frame status bar, backend: pure Tk
- tkunotes -> ttk::treeview + editor, backend (in use): tclutils::tunotes
- tkuform -> ttk form controls, backend: pure Tk
- tkutablelist (optional) -> Tablelist megawidget, backend (in use): tclutils::tucsv
- `tkuical` - iCalendar event viewer (on tclutils::tuical).
- `tkuldif` - LDIF entry viewer (on tclutils::tuldif).
- `tkuini` - INI viewer (on tclutils::tuini).
- `tkuvcard` - vCard contact viewer (on tclutils::tuvcard).
