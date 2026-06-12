# tkutils::tkuballoon

Balloon help (tooltips) for any widget. A short text pops up in a small,
theme-native balloon after a hover delay and disappears on leave, click or
motion away. One shared popup is reused, so idle balloons cost nothing.
Per-widget state is released automatically on `<Destroy>`. Pure Tk.

## API

```tcl
::tkutils::tkuballoon::add   $w "Save the file" ?-delay ms? ?-wraplength px?
::tkutils::tkuballoon::clear $w                       ;# detach the balloon
::tkutils::tkuballoon::configure ?-delay ms? ?-wraplength px?   ;# global defaults
::tkutils::tkuballoon::cget option                   ;# read a default
::tkutils::tkuballoon::enable                         ;# globally on
::tkutils::tkuballoon::disable                        ;# globally off (hides any)
```

`-delay` (default 600 ms) and `-wraplength` (default 320 px) are captured per
widget at `add` time; later `configure` changes apply to subsequent `add`s.

## Notes

- Used internally by `tkutils::tkutoolbar` for its `-tooltip` option, so there is
  one balloon implementation across the library.
- Errors carry `{TKUTILS TKUBALLOON <REASON>}`
  (`OPTION`, `VALUE`, `NOWIDGET`).

## Demo

```bash
tclsh examples/demo-tkuballoon.tcl
```
