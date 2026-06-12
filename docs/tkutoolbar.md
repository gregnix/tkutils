# tkutils::tkutoolbar

A toolbar holding buttons, toggles, dropdowns, separators and arbitrary embedded
widgets, addressed by caller-chosen ids. Theme-native (built-in `Toolbutton`
style, dark-theme safe). Pure Tk. The 0.1 positional API is a strict subset, so
old callers keep working unchanged.

## Construct

```tcl
set tb [::tkutils::tkutoolbar::widget .tb \
    ?-orient horizontal|vertical? ?-displaymode icon|text|both? \
    ?-spacing px? ?-padding px?]
```

## Items

```tcl
::tkutils::tkutoolbar::addButton   $tb id label command \
    ?-icon img? ?-tooltip s? ?-shortcut key? ?-compound side? \
    ?-displaymode m? ?-side left|right? ?ttk::button opts...?
::tkutils::tkutoolbar::addToggle   $tb id label varName \
    ?-icon img? ?-tooltip s? ?-command cmd? ?-onvalue v? ?-offvalue v? ?...?
::tkutils::tkutoolbar::addDropdown $tb id label \
    ?-icon img? ?-tooltip s? ?-menu {{label cmd} - {label cmd} ...}?
::tkutils::tkutoolbar::addSeparator $tb
::tkutils::tkutoolbar::addWidget    $tb id childWidget ?side?   ;# embed your own
```

`label`/`command` stay positional for `addButton`/`addToggle`; any further
`-option value` pairs are recognised (the toolbar options above) or forwarded to
the underlying ttk widget. `-shortcut` binds on the toplevel and is released
automatically when the toolbar is destroyed.

## Mutate / query

```tcl
::tkutils::tkutoolbar::setEnabled      $tb id 0|1
::tkutils::tkutoolbar::configureButton $tb id ?-option value ...?
::tkutils::tkutoolbar::setCallback     $tb id command
::tkutils::tkutoolbar::setDisplayMode  $tb icon|text|both     ;# whole toolbar
::tkutils::tkutoolbar::getDisplayMode  $tb
::tkutils::tkutoolbar::buttonWidget    $tb id                 ;# the widget path
::tkutils::tkutoolbar::items           $tb                    ;# ids in order
```

## Notes

- Tooltips are delegated to `tkutils::tkuballoon` (a runtime dependency).
- `icon` mode without an `-icon` falls back to text; `both` uses `-compound`.
- Errors carry `{TKUTILS TKUTOOLBAR <REASON>}`
  (`OPTION`, `ORIENT`, `DISPLAYMODE`, `NOITEM`, `NOTOOLBAR`).

## Launcher

```bash
tclsh bin/tkutoolbar.tcl
```
