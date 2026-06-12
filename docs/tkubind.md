# tkutils::tkubind

A thin layer over `bind` that abstracts the platform modifier (Control on
X11/Windows, Command on macOS) and stays out of the way while the user is
typing. `"Mod-s"` becomes `<Control-s>` or `<Command-s>`; the guard keeps global
shortcuts from stealing keys from entries, text widgets and tablelists. Pure Tk.

## Keys

```tcl
set id [::tkutils::tkubind::key "Mod-s" {saveFile} ?-toplevel .? ?-skipClasses {...}? ?-id name?]
::tkutils::tkubind::unbind $id
::tkutils::tkubind::accelerator "Mod-Shift-p"   ;# "Ctrl+Shift+P" / "@^P"
::tkutils::tkubind::isEditing                   ;# 1 while an edit widget has focus
::tkutils::tkubind::platform ?key?              ;# isMac / modKey / modSymbol
```

## Mouse

```tcl
::tkutils::tkubind::context     $widget {showMenu %X %Y}   ;# platform context button
::tkutils::tkubind::doubleClick $widget {onOpen %W}
```

## Groups

```tcl
::tkutils::tkubind::group define editKeys {{Mod-b {bold}} {Mod-i {italic}}}
::tkutils::tkubind::group enable  editKeys ?-toplevel .?
::tkutils::tkubind::group disable editKeys
::tkutils::tkubind::group toggle  editKeys
::tkutils::tkubind::group enabled editKeys      ;# 0|1
::tkutils::tkubind::group list
::tkutils::tkubind::getInfo ?bindings|groups|binding id?
::tkutils::tkubind::clear                        ;# remove every binding/group
```

## Notes

- `key` runs its script only when `isEditing`-style focus rules allow it, and
  never hijacks the native Ctrl+C/V/X/A inside edit or tablelist widgets.
- The action-registry coupling of the original uitoolkit module is intentionally
  omitted; it would return alongside a future `tkuaction`.
- Errors carry `{TKUTILS TKUBIND <REASON>}` (`GROUP`, `CMD`).

## Demo

```bash
tclsh examples/demo-tkubind.tcl
```
