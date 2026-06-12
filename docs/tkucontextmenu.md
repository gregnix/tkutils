# tkutils::tkucontextmenu

Generic right-click context menus: build them declaratively, attach them to
widgets, and show them on the platform context button (Button-3 on X11/Windows,
Button-2 / Control-click on macOS). Supports command/check/radio entries,
cascades, accelerators, icons and dynamic update handlers. Pure Tk.

## Build

```tcl
set m [::tkutils::tkucontextmenu::create .m ?-tearoff 0|1? ?-items {...}? ?-dynamic 0|1?]
::tkutils::tkucontextmenu::addItem      .m label ?-command cmd? ?-accelerator a? ?-state s? ?-icon img?
::tkutils::tkucontextmenu::addCheckItem .m label ?-variable v? ?-command cmd? ?-onvalue x? ?-offvalue y?
::tkutils::tkucontextmenu::addRadioItem .m label -variable v -value val ?-command cmd?
::tkutils::tkucontextmenu::addSeparator .m
::tkutils::tkucontextmenu::addSubmenu   .m label $submenu
```

## Attach / show / mutate

```tcl
::tkutils::tkucontextmenu::attach  .m $widget ?-button 2|3?
::tkutils::tkucontextmenu::detach  .m $widget
::tkutils::tkucontextmenu::show    .m x y
::tkutils::tkucontextmenu::enable  .m label
::tkutils::tkucontextmenu::disable .m label
::tkutils::tkucontextmenu::setCallback      .m label command
::tkutils::tkucontextmenu::setUpdateHandler .m handler   ;# for -dynamic menus
::tkutils::tkucontextmenu::destroyMenu      .m
```

## Spec builders

```tcl
::tkutils::tkucontextmenu::createFromSpec .m {
    {"New"  {newDoc}  -accelerator "Ctrl+N"}
    -
    {check "Bold" -variable ::bold}
    {radio "Left"  -variable ::align -value left}
    {submenu "Sort" {
        {"Ascending"  {sortAsc}}
        {"Descending" {sortDesc}}
    }}
}
::tkutils::tkucontextmenu::createStandardEdit .e \
    ?-cutcmd c? ?-copycmd c? ?-pastecmd c? ?-selectall c? ?-undo c? ?-redo c?
```

## Notes

- Submenus in a spec use the explicit `submenu` keyword (parallel to
  `check`/`radio`); the old ambiguous `{label {nested}}` form is gone.
- Instance state is cleaned up on `<Destroy>`, so destroying the menu by any
  means (including plain `destroy`) releases its bindings.
- Errors carry `{TKUTILS TKUCONTEXTMENU NOMENU}`.

## Demo

```bash
tclsh examples/demo-tkucontextmenu.tcl
```
