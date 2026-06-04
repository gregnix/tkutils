# tkutils::tkutoolbar

A horizontal toolbar holding buttons, toggles, separators and arbitrary embedded
widgets, addressed by caller-chosen ids. Pure Tk.

## API
```tcl
set tb [::tkutils::tkutoolbar::widget .tb]
::tkutils::tkutoolbar::addButton    $tb id label command ?ttk::button opts?
::tkutils::tkutoolbar::addToggle    $tb id label varName ?opts?
::tkutils::tkutoolbar::addSeparator $tb
::tkutils::tkutoolbar::addWidget    $tb id childWidget   ;# embed your own widget
::tkutils::tkutoolbar::setEnabled   $tb id 0|1
::tkutils::tkutoolbar::buttonWidget $tb id               ;# the widget path
::tkutils::tkutoolbar::items        $tb                  ;# ids in order
```

## Launcher
```bash
tclsh bin/tkutoolbar.tcl
```
