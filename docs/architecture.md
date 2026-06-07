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

Entry widgets and bars (pure Tk unless noted):

- tkudateentry -> entry + drop-down calendar picker, backend: pure Tk (clock)
- tkutimeentry -> HH:MM[:SS] spinbox entry, backend: pure Tk
- tkunumentry -> validated numeric entry (decimals, min/max), backend: pure Tk
- tkutags -> removable chips + input with suggestions, backend: pure Tk
- tkusearchbar -> debounced search bar (+ optional filter), backend: pure Tk
- tkufilterbar -> per-column filter bar (one entry/column, ANDed substrings), backend: pure Tk
- tkutree -> ttk::treeview wrapper (load nested data, selection), backend: pure Tk
- tkuimage -> image fit/scale/thumbnail + zoom/scroll viewer, backend: pure Tk (imgtools optional)
- tkutodo -> iCalendar VTODO task list (toggle done, due/priority/%), backend (in use): tclutils::tuical
- tkudavbrowser -> read-only CalDAV/CardDAV collection browser, backend (in use): tclutils::tudav
- tkudavaccount -> DAV account form + connection test (PROPFIND), backend (in use): tclutils::tudav

Canvas / PNG (optional engines):

- tkcanvaspng -> export a live Tk canvas to PNG, backend (in use): tclutils::tupngdraw (Glyphs for `-fontmap`)
- tkutical -> month calendar on a canvas (prev/next/today, week numbers, day selection), backend: tical
- tkmonthcanvas -> canvas calendar month/quarter/year (themes, week numbers, today/weekend/holiday states, selection), backend: tical
