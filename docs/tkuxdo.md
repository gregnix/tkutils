# tkutils::tkuxdo

Real keyboard and mouse input for end-to-end tests of a Tk application,
sent through the X server with **xdotool** (XTEST). Focus, the keyboard map,
key bindings, menu traversal and pointer clicks behave as for a user. Meant
for an X display of its own without a window manager, usually Xvfb. On a
desktop the input would go to whichever window has the focus, and `setup`
would change the keyboard map; so `available` is 0 when a window manager
runs (`unavailable` says why), unless `TKUXDO_DESKTOP=1` is set:

```bash
xvfb-run -a wish tests/xdo.test
```

```tcl
package require tkutils::tkuxdo
set X ::tkutils::tkuxdo
if {![${X}::available]} { … skip … }
${X}::setup -layout de                 ;# keys for ä ö ü ß €
${X}::focusWindow .
${X}::key ctrl+n                       ;# application shortcut
${X}::type {Grüße, 1.000,50 €}
${X}::key Tab shift+Tab Return Escape
${X}::click .buttons.primary
${X}::click .main.list -double 1 -x 40 -y 12
${X}::menuSelect . "Beleg/Zahlung erfassen…"   ;# F10, Right/Down, Return
${X}::choose .form.kunde {K1 – Müller}  ;# readonly combobox by keyboard
${X}::focusWidget .form.menge          ;# X focus to the window, Tk focus to w
```

`menuSelect` counts like Tk's keyboard traversal: separators and disabled
entries are skipped; a disabled target is an error. If an earlier entry ran a
modal dialog and left the focus on the menu bar, it is moved back first.

`choose combo value` opens the list with `Down`, waits until it is mapped,
moves to the value with `Down`/`Up`, takes it with `Return` and waits until
the list is closed. A pointer click on a readonly combobox opens or closes
the list depending on its state, and keys pressed before the list is mapped
go elsewhere; `choose` avoids both.

Modal dialogs: `dialog` hands a list of steps to
`tkutils::tkutest::answer`; they run once the dialog is mapped and focused:

```tcl
set t [${X}::dialog -title "Neue Position" {{type Schrauben} {key Tab} {type 1,5} {key Return}}]
fa::posNeu
::tkutils::tkutest::result $t
```

`clickButton label` inside the steps clicks a button of that dialog with the
pointer (by label or path tail), `chooseField name value` chooses in a
combobox field of a tkuform dialog, `clickField name` clicks into a field
of the dialog. A readonly combobox opens with `Down`, moves with `Down`/`Up` and takes the
choice with `Return`; a checkbutton toggles with `space`.

Every command waits for the X server and then processes Tk events, so the
next line of the test sees the effect. `focusWindow` and `menuSelect` avoid
Tk's `focus` and `menu`; `type`, `key` and `click` share their names with
tkutest, so import only one of the two namespaces.

## Commands

| command | does |
|---|---|
| `available`, `unavailable` | 1 if usable; else why not (`""` if usable) |
| `windowManager` | 1 if a window manager runs on the display |
| `setup ?-layout xkb?` | check the display, set the keyboard map (`setxkbmap`) |
| `focusWindow top` | give `top` the X focus |
| `focusWidget w` | X focus to the toplevel of `w`, Tk focus to `w` |
| `type text ?-delay ms?` | type `text` through the X server |
| `key keysym ...` | press keys one after another (`ctrl+s`, `Tab`, `Return`) |
| `click w ?-x? ?-y? ?-button n? ?-double 0/1?` | move the pointer to `w` and click |
| `menuSelect top path` | choose a menu entry by keyboard (F10, Right/Down, Return) |
| `choose combo value` | choose in a readonly combobox by keyboard |
| `dialog ?-title glob? ?-timeout ms? steps` | answer the next dialog with steps, returns a token |
| `clickButton label ?top?` | click a button of the dialog (or of `top`) |
| `chooseField name value`, `clickField name` | dialog steps for fields of a tkuform dialog |
| `pump ?ms?` | process Tk events for `ms` (default 150) |

A step in `dialog` is a command of this namespace with its arguments, e.g.
`{type Schrauben}` or `{clickButton OK}`.

Errors: `{TKUTILS TKUXDO <REASON>}` (DISPLAY, LAYOUT, XDOTOOL, MENU, VALUE,
USAGE, OPTION). X11 only; elsewhere `available` is 0. Not in the umbrella.
