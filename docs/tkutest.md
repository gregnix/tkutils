# tkutils::tkutest

Drive a Tk user interface from a test, in the same interpreter: type, press
keys, click, choose from comboboxes and menus, and answer modal dialogs. Keys
and clicks are generated with `event generate`, so the application's own
bindings, validation and dialog code run as they do for a user.

```tcl
package require tkutils::tkutest
namespace import ::tkutils::tkutest::*

type .form.name {Rose, rot}           ;# key events per character
key .form.name <Return>                ;# one event
click .buttons.save                    ;# Enter, Motion, Press, Release
click .list -double 1                  ;# double click
select .form.art Rechnung              ;# readonly combobox + <<ComboboxSelected>>
check .form.aktiv 0                    ;# checkbutton off
menuInvoke .m "Datei/Firmendaten…"     ;# entry by its labels
treeSelect .main.list RE-2026-0001     ;# by text, value or -column
visible .buttons.primary               ;# completely inside its toplevel?
```

## Modal dialogs

A modal dialog waits in `vwait` until it is closed, so the test cannot act
after opening it. `answer` registers a handler **before** the action; it runs
inside the dialog's event loop once a new toplevel with a matching title is
mapped:

```tcl
set t [answer -title "Neuer Kunde" -fields {kundennr K1 name {Quarz KG}}]
fa::kundeNeu                       ;# opens the form, returns after OK
result $t                          ;# {window .tkudialog3 title {Neuer Kunde} button OK}
```

| option | meaning |
|---|---|
| `-title glob` | title of the dialog to wait for (default `*`) |
| `-fields dict` | tkuform fields to fill (entries are cleared and typed, combos selected, checkbuttons set) |
| `-button id` | tkudialog button id (`ok`, `cancel`, `yes` …), a button label or a path tail; `""` presses nothing |
| `-script cmd` | called with the dialog path, e.g. to type into an input dialog |
| `-timeout ms` | how long to wait for the dialog (default 5000) |

Several `answer` calls queue up and handle one dialog each, in order: a form
and the error message it leads to, for example. `result` returns what the
handler did or raises its error (`TIMEOUT` if no such dialog appeared);
`pending` lists the tokens not handled yet — at the end of a test it should be
empty.

`answerFile ?-title glob? ?-timeout ms? path` answers Tk's file dialog: the
file name is typed into its name field and taken with Return.

Posted menus, combobox lists and tooltips (override-redirect windows) are no
dialogs: `toplevels`, `waitWindow` and `answer -title *` skip them.

## Unexpected dialogs

`guard ?-after ms?` (default 8000) watches for a modal dialog that no
handler takes. After that time it records its title and text, sends Escape
and, if that does not close it, destroys it; so a test fails instead of
hanging. `unexpected` returns the recorded `{title text}` pairs and clears
them, `unguard` stops watching.

## Typing

ASCII characters are sent as KeyPress/KeyRelease. A character the active
keyboard map has no key for (an umlaut on a US map, the euro sign) is
inserted at the insert cursor, as an input method would. For real keyboard
input through the X server use `tkutils::tkuxdo`.

## Waiting

`wait script ?-timeout ms?` processes events until the expression is true;
`waitWindow ?-title glob? ?-after list?` returns the first new toplevel.
Both raise `{TKUTILS TKUTEST TIMEOUT}`.

## Commands

| command | does |
|---|---|
| `type w text` | key events per character into `w` (focus first) |
| `key w sequence` | one event, e.g. `<Return>`, `<Control-s>` |
| `clear w` | empty an entry, combobox or text widget |
| `click w ?-x? ?-y? ?-button n? ?-double 0/1?` | Enter, Motion, Press, Release; centre by default |
| `select combo value` | set a combobox and send `<<ComboboxSelected>>`; `VALUE` if no choice |
| `check w ?value?` | set a checkbutton on (1) or off (0) by clicking it if needed |
| `menuInvoke menu path` | invoke an entry by its labels, `"Datei/Öffnen…"` |
| `treeItem tree text ?-column c?` | item id by text, a value or one column; `ITEM` if none |
| `treeSelect tree text ?-column c?` | as `treeItem`, then show, select and focus it |
| `findButton top label` | a button below `top` by its `-text` or path tail |
| `fill form fields` | fill a tkuform: entries cleared and typed, combos selected, checkbuttons set |
| `visible w` | 1 if `w` is mapped and lies completely inside its toplevel |
| `answer ?options?` | handler for the next dialog, returns a token (see above) |
| `answerFile ?-title? ?-timeout? path` | answer Tk's file dialog with `path` |
| `result token ?-timeout ms?` | what the handler did, or its error |
| `pending` | tokens not handled yet |
| `guard ?-after ms?`, `unguard` | watch for, and stop watching for, unexpected dialogs |
| `unexpected` | `{title text}` of the dialogs `guard` closed; clears the list |
| `wait expr ?-timeout ms?` | process events until `expr` is true |
| `waitWindow ?-title glob? ?-after list? ?-timeout ms?` | the first new toplevel |
| `toplevels` | mapped toplevels without menus, combobox lists and tooltips |

Errors: `{TKUTILS TKUTEST <REASON>}` (TIMEOUT, VALUE, MENU, ITEM, BUTTON,
FORM, TOKEN, OPTION). Not in the umbrella: a test requires it directly.
