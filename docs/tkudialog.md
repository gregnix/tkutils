# tkutils::tkudialog

Dialogs whose **message text is selectable and copyable** (Ctrl-C or the Copy
button) -- unlike `tk_messageBox`. A generic, extensible builder plus ready-made
variants. Pure Tk; no tclutils engine required.

## Generic / extensible
```tcl
# non-modal toplevel (embed or drive yourself)
::tkutils::tkudialog::build  $win ?-title t? ?-message m? ?-icon info|warning|error|question? \
                                 ?-detail d? ?-buttons {labels...}? ?-entry 0|1? ?-initial s? \
                                 ?-parent w?
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
::tkutils::tkudialog::input       ?-title t? ?-message m? ?-initial s? ?-parent w?   ;# entered text or ""
```

Extend by passing your own `-buttons` and `-detail`, or build a non-modal dialog
with `build` and wire it up yourself. The ready-made variants pass any further
options (such as `-parent`) through to `show`.

## Parent and placement (0.2)

`-parent w` makes the dialog belong to the toplevel of `w`: it is transient to
it and opens centred over it. Without `-parent` the parent is the toplevel that
has the keyboard focus, else `.` — as with `tk_messageBox`. Pass `-parent`
whenever the calling window is known; it is the only reliable answer on a
machine with several monitors.

Up to 0.1 `-parent` was accepted but not used: no `wm transient`, and every
modal dialog opened in the middle of the screen (measured 2026-09-19: parent at
900,600, dialog at 431,466). With the application on a second monitor, the
dialog appeared on the other one.

Details of the placement:

- The dialog is made transient only to a **viewable** parent — a dialog
  transient to a withdrawn toplevel stays invisible under some window managers.
- A `-parent` that does not exist is an error, `{TKUTILS TKUDIALOG PARENT <w>}`.
- The dialog is kept on the screen (all four sides) only when the parent lies
  completely on the screen Tk reports. **Tk reports one screen**: on Windows
  that is the primary monitor, so a parent on a second monitor lies outside it.
  Clamping there would pull the dialog back to the primary monitor, so it is
  centred over the parent without clamping; a dialog wider than its parent may
  then overhang that monitor. The rule is `_geometry` and is tested for this
  case with made-up coordinates — two real monitors were not measured.

## Options are checked (0.2)

An unknown option is an error that lists the known ones, with
`{TKUTILS TKUDIALOG OPTION <opt>}`:

```
unknown option "-parnet"
Known: -title -message -icon -detail -buttons -entry -initial -parent
```

Up to 0.1 `array set` swallowed it — `build .d -parnet .p` built the dialog
without a parent, and `form` with a typo opened and waited as if nothing were
wrong.

## Launcher
```bash
tclsh bin/tkudialog.tcl
```

## Form dialog

```tcl
set vals [::tkutils::tkudialog::form $fieldspec ?-title T? ?-parent w?]
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
