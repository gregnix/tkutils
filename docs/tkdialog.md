# tkutils::tkdialog

Dialogs whose **message text is selectable and copyable** (Ctrl-C or the Copy
button) -- unlike `tk_messageBox`. A generic, extensible builder plus ready-made
variants. Pure Tk; no tclutils engine required.

## Generic / extensible
```tcl
# non-modal toplevel (embed or drive yourself)
::tkutils::tkdialog::build  $win ?-title t? ?-message m? ?-icon info|warning|error|question? \
                                 ?-detail d? ?-buttons {labels...}? ?-entry 0|1? ?-initial s?
# modal: builds, grabs, waits, returns the clicked button label
::tkutils::tkdialog::show    $win ?same options?
::tkutils::tkdialog::getText $win          ;# message text
::tkutils::tkdialog::getDetail $win
::tkutils::tkdialog::result  $win
::tkutils::tkdialog::copyText $win          ;# copies message (+detail), returns it
::tkutils::tkdialog::choose  $win label     ;# pick a button programmatically
```

## Ready-made variants
```tcl
::tkutils::tkdialog::showInfo    message ?options?   ;# returns OK
::tkutils::tkdialog::showWarning message ?options?
::tkutils::tkdialog::showError   message ?-detail d?
::tkutils::tkdialog::confirm     message ?options?   ;# 1 for Yes, else 0
::tkutils::tkdialog::input       ?-message m? ?-initial s?   ;# entered text or ""
```

Extend by passing your own `-buttons` and `-detail`, or build a non-modal dialog
with `build` and wire it up yourself.

## Launcher
```bash
tclsh bin/tkdialog.tcl
```

## Form dialog

```tcl
set vals [::tkutils::tkdialog::form $fieldspec ?-title T? ?-parent .?]
# -> values dict on OK, "" on Cancel
```

Embeds a `tkutils::tkform` (see docs/tkform.md) in a modal dialog with OK/Cancel.
Example:

```tcl
set v [::tkutils::tkdialog::form {
    {name title label "Title" type entry}
    {name prio  label "Prio"  type combo values {low normal high} default normal}
    {name done  label "Done"  type check}
} -title "New note"]
if {$v ne ""} { puts "title=[dict get $v title]" }
```
