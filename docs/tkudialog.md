# tkutils::tkudialog

Dialogs whose **message text is selectable and copyable** (Ctrl-C or the Copy
button) -- unlike `tk_messageBox`. A generic, extensible builder plus ready-made
variants. Pure Tk; no tclutils engine required.

## Generic / extensible
```tcl
# non-modal toplevel (embed or drive yourself)
::tkutils::tkudialog::build  $win ?-title t? ?-message m? ?-icon info|warning|error|question? \
                                 ?-detail d? ?-buttons {labels...}? ?-entry 0|1? ?-initial s?
# modal: builds, grabs, waits, returns the clicked button label
::tkutils::tkudialog::show    $win ?same options?
::tkutils::tkudialog::getText $win          ;# message text
::tkutils::tkudialog::getDetail $win
::tkutils::tkudialog::result  $win
::tkutils::tkudialog::copyText $win          ;# copies message (+detail), returns it
::tkutils::tkudialog::choose  $win label     ;# pick a button programmatically
```

## Ready-made variants
```tcl
::tkutils::tkudialog::showInfo    message ?options?   ;# returns OK
::tkutils::tkudialog::showWarning message ?options?
::tkutils::tkudialog::showError   message ?-detail d?
::tkutils::tkudialog::confirm     message ?options?   ;# 1 for Yes, else 0
::tkutils::tkudialog::input       ?-message m? ?-initial s?   ;# entered text or ""
```

Extend by passing your own `-buttons` and `-detail`, or build a non-modal dialog
with `build` and wire it up yourself.

## Launcher
```bash
tclsh bin/tkudialog.tcl
```

## Form dialog

```tcl
set vals [::tkutils::tkudialog::form $fieldspec ?-title T? ?-parent .?]
# -> values dict on OK, "" on Cancel
```

Embeds a `tkutils::tkuform` (see docs/tkuform.md) in a modal dialog with OK/Cancel.
Example:

```tcl
set v [::tkutils::tkudialog::form {
    {name title label "Title" type entry}
    {name prio  label "Prio"  type combo values {low normal high} default normal}
    {name done  label "Done"  type check}
} -title "New note"]
if {$v ne ""} { puts "title=[dict get $v title]" }
```
