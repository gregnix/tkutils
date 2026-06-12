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
- tkutoolbar -> ttk::frame of buttons/toggles/dropdowns, backend: pure Tk; tooltips via tkutils::tkuballoon, optional actions via tkutils::tkuaction
- tkuballoon -> shared override-redirect popup, backend: pure Tk (tooltips for any widget)
- tkucontextmenu -> tk menu + tk_popup, backend: pure Tk (command/check/radio/cascade, spec builder)
- tkubind -> wrappers over bind, backend: pure Tk (platform Mod key, accelerators, isEditing guard, groups)
- tkuaction -> action registry/model, backend: pure Tk (register widgets; setEnabled/setChecked/invoke propagate)
- tkukeynav -> wrappers over bind + tk_focusNext/Prev, backend: pure Tk (Tab/Shift-Tab traversal, Return-to-next-field form helper)
- tkulabeled -> ttk::frame + label + control composite, backend: pure Tk (types entry/combo/spin/check/text; `value` get/set)
- tkuvalidate -> per-widget validation feedback, backend: pure Tk; predicates from tclutils::tuvalidate, message via tkutils::tkuballoon
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

Icons (optional engine):

- tkuicon (optional) -> SVG/PNG icons as Tk photo images; generates the named icon set from tclutils::tusvg, backend: tksvg (Tk 8.6) / native SVG (Tk 9)
- tkuscrolledframe (optional) -> scrollable frame container, backend: scrollutil (tklib); thin wrapper over scrollarea + scrollableframe
