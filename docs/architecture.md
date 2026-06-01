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
tkutils::tkhexedit
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

- tkcsv  -> ttk::treeview, backend (in use): tclutils::tucsv
- tkdiff -> text widget, backend (in use): tclutils::tudiff
- tkmd   -> ttk::treeview, backend (in use): tclutils::tumd
- tkjson -> ttk::treeview, backend (in use): tclutils::tujson::parseTyped (0.28.0+)
- tkcal -> text view, backend (in use): tclutils::tucal
- tkeditor -> text widget, backend (in use): tclutils::common (file I/O)
- tkzip -> ttk::treeview, backend (in use): tclutils::tuzip
- tkfuzzy -> entry + listbox, backend (in use): tclutils::tufuzzy
- tkxml (optional) -> ttk::treeview, backend: tDOM (external)
- tksqlite (optional) -> listbox + ttk::treeview, backend: sqlite3 (external)
- tkdialog -> toplevel dialogs, backend: pure Tk (copyable message text)
- tkbase64 -> text panes, backend (in use): tclutils::tubase64
- tkstrings -> listbox, backend (in use): tclutils::tustrings
- tktoolbar -> ttk::frame of buttons, backend: pure Tk
- tkstatus -> ttk::frame status bar, backend: pure Tk
- tknotes -> ttk::treeview + editor, backend (in use): tclutils::tunotes
- tkform -> ttk form controls, backend: pure Tk
- tktablelist (optional) -> Tablelist megawidget, backend (in use): tclutils::tucsv
- `tkical` - iCalendar event viewer (on tclutils::tuical).
- `tkldif` - LDIF entry viewer (on tclutils::tuldif).
- `tkini` - INI viewer (on tclutils::tuini).
- `tkvcard` - vCard contact viewer (on tclutils::tuvcard).
