# tkutils::tktoolbar

A horizontal toolbar holding buttons, toggles, separators and arbitrary embedded
widgets, addressed by caller-chosen ids. Pure Tk.

## API
```tcl
set tb [::tkutils::tktoolbar::widget .tb]
::tkutils::tktoolbar::addButton    $tb id label command ?ttk::button opts?
::tkutils::tktoolbar::addToggle    $tb id label varName ?opts?
::tkutils::tktoolbar::addSeparator $tb
::tkutils::tktoolbar::addWidget    $tb id childWidget   ;# embed your own widget
::tkutils::tktoolbar::setEnabled   $tb id 0|1
::tkutils::tktoolbar::buttonWidget $tb id               ;# the widget path
::tkutils::tktoolbar::items        $tb                  ;# ids in order
```

## Launcher
```bash
tclsh bin/tktoolbar.tcl
```
