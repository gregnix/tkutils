# Changelog

## 0.49.0 - 2026-10-28

Recommended pairing: tclutils 0.69.0 + tkutils 0.49.0 + ctrlutils 0.4
(`tkutablelist` CSV export needs `tucsv` 0.2 from tclutils 0.69.0).

Module versions: `tkutablelist` 0.5, `tkutlclip` 0.3, `tkutlsort` 0.3,
`tkutlstate` 0.4, `tkutlfind` 0.3, `tkutltree` 0.3, `tkutltools` 0.3,
`tkuical`, `tkuvcard`, `tkuldif`, `tkuini` 0.3, `tkunotes`, `tkueditor` 0.4, `tkubase64` 0.2,
`tkutical` 0.4, `tkutlfooter` 0.4; new
`tkutlfilter`, `tkutlgroup`, `tkutldrag`, `tkusysinfo` 0.1. When copying over an older
tree, delete `tkutils-0.48.0.tm`, `tkutablelist-0.4.tm`, `tkutlclip-0.2.tm`,
`tkutlsort-0.2.tm`, `tkutlstate-0.3.tm`, `tkutlfind-0.2.tm`,
`tkutltree-0.2.tm`, `tkutltools-0.2.tm`, `tkuical-0.2.tm`, `tkuvcard-0.2.tm`,
`tkuldif-0.2.tm`, `tkuini-0.2.tm`, `tkutical-0.3.tm`, `tkunotes-0.2.tm`,
`tkueditor-0.2.tm`, `tkubase64-0.1.tm`, `tkutlfooter-0.3.tm`.

- `tkutlclip`: `installBindings` had no effect; Tablelist's own `<<Copy>>`
  overwrote the clipboard. Binding now ends with `break`. `copyAll` skips
  hidden rows. New `-separator`; `copySelection` checks its options also with an
  empty selection. Tests `tkutlclip-1.3`–`2.4`.
- `tkutlstate`: state version 2 keeps column order, identifies columns by
  `-name` (or title) and stores multi-column sort. Version-1 states still
  restore. Autosave also on hide and sort. Tests `tkutlstate-4.1`–`4.4`.
- `tkutablelist`: row ids (`insert … id`, `setRows -ids`, `rowId`,
  `findId`, `selectedIds`, `selectIds`); `setRows` uses `insertlist` and
  keeps the sort order; header click via `tablelist::sortByColumn`,
  Shift+click adds sort columns; `selectRows` shows the first row; `toCsv`
  exports only viewable rows and visible columns (`-all`, `-formatted`,
  tucsv options); `saveCsv` writes UTF-8 (`-encoding`). Tests
  `tkutablelist-8.1`–`9.4`.
- `tkutlsort`: `-empty first|last` for `integer`, `real`, `num`; empty cells
  stay in place in both directions. Tests `tkutlsort-2.1`–`2.5`.
- `tkutlfind`: matches kept as row keys (right after sorting, deleted rows
  skipped); hidden rows skipped (`-hidden 1`); `next`/`prev` expand
  collapsed ancestors; `clear` restores earlier cell colours. Tests
  `tkutlfind-2.1`–`2.6`.
- `tkutltree`: `fromData` uses `insertchildlist`, returns the top-level
  keys; `-idfield`, `-expand none|all|N`, `-lazykey`; new `lazy`, `reveal`,
  `findId`. Tests `tkutltree-2.1`–`3.2`.
- New `tkutlfilter` (hide non-matching rows, `-where` per column, `later`),
  `tkutlgroup` (group rows into a tree with sums), `tkutldrag` (reorder rows
  with the mouse). Docs, man pages, demos, tests.
- `tkutltools` 0.3 loads the new modules and versions.
- New `tkusysinfo`: view of `tclutils::tusysinfo` (OS, hardware, monitors)
  plus Tk's screen data; copy, save as text or JSON. Needs tclutils
  0.69.0, so not in the umbrella. Doc, man, demo, tests.
- `tkuical`, `tkuvcard`: `save` wrote `\r\r\n` (CRLF text through a CRLF
  channel); now CRLF once. `tkuical`, `tkuvcard`, `tkuldif`, `tkuini`:
  `loadFile` and `save` use UTF-8 whatever the system encoding. Tests
  `tkuical-3.1`, `tkuvcard-3.1`, `tkuldif-3.1`, `tkuini-3.1`.
- `tkueditor`, `tkuldif` docs: strict encoding with `tuiconv` 0.2, binary
  attributes with `tuldif` 0.3.
- `tkuini`: needs `tuini` 0.2; the edit bar trims key and section and
  shows `{TCLUTILS TUINI VALUE}` as a message. Tests `tkuini-4.1`, `4.2`.
- `tkuical`: `save` keeps the order of events and other components (to-dos
  were moved before the events). New `tests/roundtrip.test` with files in
  `tests/data/roundtrip`: `loadFile`, `save`, compare. Needs `tuical` and
  `tuvcard` 0.2 (last line with CRLF).
- `tkuvcard`: `setProperty` kept only TYPE (`PREF`, `LABEL` ... were lost);
  other parameters stay, TYPE values as a comma list. Test `tkuvcard-3.2`.
- `tkutical`: `-events`, `setEvents`, `getEvents` show appointments
  (tical 1.1+), series on each of their days. Tests `tkutical-3.1`, `3.2`.
- `tkusysinfo` doc: Tk screen and EDID monitors are not the same area.
- `tkunotes`: the Save button wrote no file (only `commit`); now it writes
  the JSON file and asks for one when there is none. Tags field separated
  by commas, a tag may hold a space (every word was a tag). Tests
  `tkunotes-1.4`, `3.1`, `3.2`.
- `tkueditor`: line ends `lf`, `crlf`, `cr` and `mixed`; a mixed file saved
  unchanged keeps every line end, after edits the most frequent one (one
  CRLF made the whole file CRLF, a lone CR became LF). Tests
  `tkueditor-9.1`–`9.3`.
- `tkunotes` 0.4: switching notes keeps the edits of the current note
  (they were lost unless Save was pressed). Tests `tkunotes-4.1`–`4.3`.
- `tkueditor` 0.4: Open and Save show a failed load or save in a message
  box and the status bar (was bgerror). Tests `tkueditor-6.1`, `6.2`.
- `tkutlstate`: a failed autosave sends `<<TkutlStateSaveFailed>>`, calls
  `-onerror` and is kept for `lastError` (was caught silently). Test
  `tkutlstate-5.1`.
- `tkuical`, `tkuvcard`, `tkuini`, `tkuldif`, `tkulauncher`: file I/O in
  `try`/`finally` (a read error left the channel open); `save` builds the
  text before it opens the file.
- `tkutlgroup`: `group` replaces the rows (`-replace 1`, default); a second
  call stacked the groups. `tkutlfilter`: a pending `later` is cancelled
  when the table is destroyed. `tkusysinfo::refresh`: an error shows in
  the status line. Tests `tkutlgroup-9.1`, `tkutlfilter-9.1`,
  `tkusysinfo-9.1`. Doc: `selectedIds` leaves out rows without an id.
- Tests run with `-encoding utf-8` through `tutestrun` 0.2
  (`tkutablelist-9.3` failed under Tcl 8.6 with cp1252).
- `tkubase64` 0.2: text is UTF-8 both ways (`€` failed under Tcl 9, `ö`
  became one byte). Needs `tubase64` 0.2. Test `tkubase64-1.5`.
- `tests/congruence-check.tcl`: finds modules of any version (was `-0.1.tm`
  only, so every module showed MISS); covers the new modules.
- `docs/guide/tkutils-modules.md` regenerated.
- `tkutlfooter` 0.4: the first update after `attach` is cancelled by
  `detach` and skipped when a table is gone (a destroyed table gave the
  background error `invalid command name`). Tests `tkutlfooter-9.1`, `9.2`.
- Apps `sqledit`, `knowledge`: `…` and `—` in strings written as `\u2026`,
  `\u2014` (Tcl 8.6 read them in the system encoding).

## 0.48.0 - 2026-10-27

Recommended pairing: tclutils 0.68.0 + tkutils 0.48.0 + ctrlutils 0.4.

Module versions: `tkulauncher` 0.3, `tkuload` 0.3. When copying over an
older tree, delete `tkutils-0.47.0.tm`, `tkulauncher-0.2.tm`,
`tkuload-0.2.tm`.

- `tkulauncher`: with `-scroll 1` the buttons are bound to the wheel when
  they are built; after `reload` new buttons had no wheel binding, and
  `tkulauncher-9.4` failed under load. Test `tkulauncher-9.5`.
- `tkuload`: exports `widgetByName`, `setValue`, `getValue`, `fill`,
  `collect` (was `build`, `buildFromFile`, `slot`). Test `tkuload-5.1`.
- `tkutablelist` header comment, doc, man: comes in via `tkufilelist`
  (was "NOT part of the umbrella").
- Tests `tkucanvaspng`, `tkuwinico`, `tkutl*`, `tkuopts`: find tclutils via
  `TCLUTILS_TM` or a sibling `tclutils*` (was sibling `tclutils` only).
- Examples without personal paths (`/srv/daten/docs`, `S:/projekte/daten`,
  `/home/user`): `tkupath`, `tkulauncher` (code comments, docs, man, tests),
  `demo-tkupreview`, search-replace-tool, `tools/check-modules`.

## 0.47.0 - 2026-10-20

Recommended pairing: tclutils 0.66.0 + tkutils 0.47.0 + ctrlutils 0.4
(0.47.0 still needs at least tclutils 0.64.0).

Module versions: `tkufiledialog` 0.2; `tkutlsort`, `tkutlclip`, `tkutlfind`,
`tkutltree`, `tkutltools` 0.2; `tkutlfooter`, `tkutlfmt`, `tkutlstate` 0.3
(they now load `tablelist_tile`, see below). When copying over an older tree,
delete the old files (`tkufiledialog-0.1.tm`, `tkutl*-0.1.tm`,
`tkutl*-0.2.tm`), otherwise both versions sit side by side.

- `tkufiledialog`: a double-click on a file returned `""` -- `_onActivate`
  closed the dialog without setting the result. It goes through `_finishOk`
  now, like OK and Return. Test `tkufiledialog-1.4a`.
- One Tablelist variant: `tablelist_tile`. The `tkutl*` helpers required the
  classic `tablelist`, `tkutablelist` the themed one, and Tablelist refuses
  both in one process: `tkutils` followed by `tkutltools` failed with
  `can't set "usingTile"`. The helpers now load `tablelist_tile` unless the
  application already has one of the two (then they use it); apps
  (tkdevtools, knowledge), examples, tests, docs and man pages load
  `tablelist_tile`. Tests `tkutltools-2.1`/`-2.2` load both orders in a
  child process.
- Tests: `stack`, `tkumdview`, `tkupdfinspect`, `tkuwinico` skip without a
  display (all.tcl reported "no summary", exit 1). `tkumonthcanvas.test`
  finds tical in a flat checkout too (before: all 13 tests skipped).
- `tools/congruence-check.tcl`: modules of any version (was fixed `-0.1.tm`,
  four false "missing").
- README: 53 umbrella widgets, `tkutltools` loads `tkutltree` too,
  `tkutablelist` comes in via `tkufilelist`, 77 demos / 25 launchers, module
  file names, pairing. `tkuload` header comment names `tkutils::tkuload`.
  tkdevtools README: tclutils 0.64.0 or newer.

- Option errors in ten modules (`tkuaction` define, `tkuballoon`, `tkuform`,
  `tkukeynav`, `tkulayoutcanvas`, `tkumarquee`, `tkuscrolledframe`,
  `tkutablelist`, `tkutoolbar`, `tkuvalidate`) follow `tkuopts`: errorcode
  `{TKUTILS <MOD> OPTION <opt>}` (was without the option), message
  `unknown option "<opt>"` and a line `Known:` with the valid options (was
  `unknown option '<opt>'`). Tests adjusted, `tkuform-3.7` new.
- `docs/tkupath.md`, `tkupath.n`: the example no longer calls `setPath` in the
  callback -- the bar updates itself before calling it.

## 0.46.0

Recommended pairing: tclutils 0.64.0 + tkutils 0.46.0 + ctrlutils 0.3
(`tkdevtools` needs tclutils 0.64.0 for `tustr::graphemes`, `tudate::zones`).

### `tkupath` 0.3: drive and UNC paths (2026-10-07)

On Windows the breadcrumb of `S:/projekte/daten` read `/ > S: > projekte > daten`
and clicking `projekte` sent `/S:/projekte` -- a path on the current drive, so a
file manager landed on `C:`. The drive (or `//server/share`) is now the first
segment and every target a real path (`S:/`, `S:/projekte`); backslashes count
as `/`. Unix paths are unchanged. Tests `tkupath-2.1` to `2.5`.

### `tkupreview` 0.2: texts through msgcat (2026-10-07)

The messages the widget writes itself (preview unavailable, cannot open,
render failed) go through `msgcat` when loaded, like `tkudialog` 0.3. An
application sets its language in `::tkutils`. Test `tkupreview-2.1`.

### `tkufiletree`: hidden files on Windows (2026-10-03)

With `-showhidden 1` dot files were listed twice on Windows (`*` matches them
there too), and the tree failed with `ITEM_EXISTS`. Duplicates are dropped.
Tests: `tkufiletree-1.7`; `tkulauncher` tests no longer assume `sh` or Unix
interpreter names.

### `tkdevtools`: package copies and platform probes (2026-10-04)

New tools: "Package shadows" (every copy of a package, a second copy of the
same version marked; `tupkgfinder` 0.2), "Paths" (file commands and
`tupath::clean`, Windows and Unix rules), "glob", "Programs" (`auto_execok`,
PATH, PATHEXT), "Encoding profiles" (strict / replace / tcl8), "Font aliases"
and "Number format" (`format %.Nf` next to `tunum::format`).

### `tkulauncher`: backslashes for `start` (2026-10-04)

On Windows the program and the `/D` working directory are handed to
`cmd /c start` with backslashes; `start` read a `/` in them as a switch.
Tests: `tkulauncher-10.3a`; 8.6 waits for the child up to 10 s; the 20.x
tests restore `HOME`; `tkutablelist-4.4` lays out the rows before it
searches for one and says so if it finds none.

### `tkudialog-0.2.tm` removed (2026-10-03)

0.3 is compatible for plain labels, and `package require tkutils::tkudialog 0.2`
loaded 0.3 anyway. Doc and man list `result`, `getText`, `getDetail`,
`copyText` again.

### `tests/all.tcl` uses `tclutils::tutestrun` (2026-10-03)

Same behaviour, one copy for all three libraries. Needs tclutils 0.64.0.

### `tkugeometry` 0.1 — remember window geometry (2026-10-03)

`track`, `restore`, `save` over `tusettings` (own file `geometry.ini`). A
position no longer on the screen is centred. Needs tclutils 0.64.0.

### `tkuunits` 0.1 — screen distances (2026-10-03)

`toPixels`, `fromPixels`, `convert` between px, pt, mm, cm and inch over
`winfo fpixels`. For label and print previews.

### `tkdevtools` on library functions (2026-10-03)

Tables via `tkutablelist`; graphemes, printable check, zone list, units and
package sources from `tustr`, `tudate`, `tkuunits`, `tupkgfinder`. New
"Copy report" (`tuappinfo::buildReport`). Starts under Tcl 9 again
(`tcl_precision` is unset there).

### `tkufiledialog` 0.1 — open / save / directory (2026-10-02)

Modal chooser on `tkupath` + `tkufilelist` (explorer look). Local provider by
default; optional `-provider`. API: `open`, `save`, `directory`. Options:
`-parent`, `-title`, `-initialdir`, `-filetypes`, `-multiple`, `-showhidden`,
`-initialfile`, `-defaultextension`. First stand — not a full file manager.

### `tkutablelist` 0.4 — default `-exportselection 0` (2026-10-03)

The new default (selection stays when menus take PRIMARY) changes observable
behaviour for callers that relied on Tk’s usual export. Module version is
therefore **0.4**; opt in to the old behaviour with `-exportselection 1`.
`tkutablelist-0.3.tm` is the unchanged 0.3 again. `package require
tkutils::tkutablelist 0.3` still loads 0.4 (same major 0); only `-exact 0.3`
gets the old one.

### `tkdevtools`: non-ASCII literals as `\u` escapes (2026-10-03)

`·`, `×`, `—`, `→` showed as `Â·` etc. under Tcl 8.6 with iso8859-1/cp1252
script encoding.

### Tests / runner (2026-10-03)

- `tkudialog.test` 1.11: `focus -force` + 3 s failsafe (Xvfb without WM).
- `tkucalc.test` 4.5: `\u00d7` via `[list …]` (script encoding on 8.6).
- `tkupreview.test`: locate sibling `tclutils` tm tree (needs `tucsv`).
- `tests/all.tcl`: per-file wall-clock limit (`TKUTILS_TESTGRENZE`, default 120 s).

## 0.45.0

Recommended pairing: tclutils 0.63.0+ + tkutils 0.45.0 + ctrlutils 0.3.

### `tkudialog` 0.3 — keyboard, structured buttons, msgcat (2026-10-02)

- Return / KP_Enter → `-default` (first button if unset); Escape → `-cancel`
  (No/Cancel when present). Default button uses ttk `-default active`.
- `-buttons` accepts `Label` or `{id Label}`; `result`/`show` return the **id**
  (plain labels keep id == label for 0.2 callers).
- Titles/labels (`OK`, `Yes`, `Copy`, …) via `msgcat` when available.
- Modal dialogs restore previous focus and grab.
- `-detailcollapsed`, `-width`, `-maxheight`; `_msgHeight` estimates wrap lines.
- `confirm` / `input` / `form` use stable ids (`yes`/`no`, `ok`/`cancel`).

### `tkutablelist` 0.3 — `-exportselection` (default 0)

First shipping of the option under the 0.3 number; corrected to **0.4** above.

## 0.44.0

Recommended pairing: tclutils 0.63.0 + tkutils 0.44.0 + ctrlutils 0.2.

### `tkupreview` 0.1 — CSV via Tablelist (2026-09-24)

`csv` shows a `tkutablelist` when Tablelist is installed (`tablelist_tile`),
else `tkucsv` (ttk::treeview), else plain text. Kind stays `csv` for the
table views. Extra parser args (`-delimiter`) are unchanged. `-header 0|1`
is taken by the table (headings), not by `tucsv`.

`tkutablelist::loadCsv -header 0` names columns 1..n and keeps the first
row as data.

### `tkuaction` 0.2 — Enable per window and menu entries (2026-09-24)

`setEnabled save 0 $w` greys registered widgets in that toplevel only.
Without `$w` every bound widget, as in 0.1; a global call also clears
window overrides so the two-argument form stays the default. A child
widget is resolved with `winfo toplevel`. `getEnabled` and `groupSet`
take the same optional window. Unknown window:
`{TKUTILS TKUACTION WINDOW}`. `invoke` still uses the global flag.

Menu command entries follow the same Enable: `addMenuItem $menu save`
creates the row and registers its index; `setEnabled` greys it (also
per window). `registerMenu` / `unregisterMenu` cover an existing row.
Menu widgets are themselves toplevels; Enable uses the first non-Menu
ancestor so a menubar cascade follows the window.

### `tkurender` 0.2 / `tkuload` 0.2 — Placeholder slot (2026-09-23)

New catalogue type `placeholder` (options `text`, `role`, `width`, `height`):
a named frame the host fills after `tkuload::slot`. Public API, therefore a
minor bump of both modules. tkudesigner shows the type in the Widget group.

72 man pages (was written as 71 in an earlier note).

### `tkudialog` 0.2 — dialogs open over their window

Measured 2026-09-19: with the parent at 900,600, `show -parent .p` opened the
dialog at 431,466 — the middle of the screen — and `wm transient` was empty.
`-parent` was accepted but never used. On a second monitor that is the wrong
screen.

- `-parent w` now makes the dialog transient to the toplevel of `w` and centres
  it over that window (`build`, `show`, the ready-made variants, `input`,
  `form`). Without `-parent` the parent is the toplevel with the keyboard
  focus, else `.` — as with `tk_messageBox`.
- Transient only to a viewable parent (a dialog transient to a withdrawn
  toplevel stays invisible under some window managers). A `-parent` that does
  not exist is an error, `{TKUTILS TKUDIALOG PARENT <w>}`.
- Kept on the screen only when the parent lies completely on the screen Tk
  reports. Tk reports one screen — on Windows the primary monitor — so a
  parent on a second monitor lies outside it, and clamping would pull the
  dialog back to the primary one. The rule (`_geometry`) is tested for that
  case with made-up coordinates; two real monitors were not measured.
- Unknown options are an error listing the known ones,
  `{TKUTILS TKUDIALOG OPTION <opt>}`. Up to 0.1 `array set` swallowed them:
  `build -parnet .p` built the dialog without a parent, and `form` with a typo
  opened and waited.
- 12 new tests; against 0.1 nine fail (and `form` hangs on the typo). The
  placement tests compare the dialog with where the parent's content really
  is, measured at the same moment — not with the requested `+x+y`. A first
  draft did the latter: green under Xvfb without a window manager, red on a
  real desktop (reproduced with openbox, whose border and
  title bar put the content at +1+20). The placement itself was right in both.
  Measured under openbox, xfwm4 and without a window manager, Tcl/Tk 9.0.4 and
  8.6.14.

**Window-manager decoration (found in the third review).** Most window
managers put a toplevel's *frame* at the position given to `wm geometry
+x+y`, so the content lands lower right by border and title bar. The dialog
computed where its content should be and passed that as `+x+y` — under such
window managers it sat off-centre. Measured with the dialog content centre
against the parent's content centre:

| window manager | before | after |
|---|---|---|
| icewm | +5, +23 | 0, −1 |
| fluxbox | +1, +22 | 0, −1 |
| metacity | 0, +36 | 0, −1 |
| openbox | 0, −1 | 0, −1 |
| xfwm4 (undecorated here), none | 0, −1 | 0, −1 |

A decorated desktop measured +5, +28. The offset cannot be computed in advance — openbox
places transient dialogs by their content but other toplevels by their
frame — so `tkudialog` now measures the dialog once it is mapped and moves it
by the difference, once. Offsets of 100 px or more are left alone: then the
window manager placed the dialog on purpose. Note from the measurement: the
`update idletasks` in `_place` already maps the new toplevel, so a `<Map>`
binding set afterwards never fired; the check is scheduled directly in that
case. Tests (`tkudialog.test`, and `cufileops.test` in ctrlutils) pass under
icewm, fluxbox, metacity, openbox, xfwm4 and without a window manager, on Tcl/Tk
9.0.4 and 8.6.14; without the correction, icewm shows the three failures.
The test waits until the parent's position has settled
(at most 1 s): under fluxbox with Tk 8.6 the first dialog was otherwise placed
against the parent's pre-decoration position. `tkwait visibility` hung there
and is not used.

ctrlutils 0.2 passes `-parent` from its file operations; with the old
`cufileops` those prompts stayed on the wrong monitor even with this
`tkudialog`.

### Tests independent of the environment

Without `TCLUTILS_TM` in the environment, `tkulauncher.test` reported 86 skips
and 11 failures, `tkufilelist.test` 6 skips, and `tkudhash.test` aborted —
the files looked for tclutils through the environment only. They now use the
sibling discovery of CONVENTIONS §11.2. Where the old code turned a failed
module load into a skipped "tk" constraint, a new unconstrained test
(`tkulauncher-0.0`, `tkufilelist-0.0`) fails instead when Tk is present but
the module does not load; against an unreachable `TCLUTILS_TM` it is red, not
silent. The 11 `tkulauncher` cases that need the module now carry its
constraint, so a run without a display skips them instead of failing.

Measured 2026-09-19 without any module path in the environment, under
`xvfb-run` without a window manager and again under icewm (75 test files,
each with a summary): Tcl/Tk 9.0.4 — 752 passed, 31 skipped; Tcl/Tk 8.6.14 —
736 passed, 47 skipped; 0 failed, `all.tcl` exit 0 in all four runs. Before, 8.6 ended with exit 1: `stack.test` could not load the
tclutils umbrella without tcllib (fixed in tclutils 0.63.0).

### Unknown options are errors everywhere (`tkuopts` 0.1)

24 procs in 20 modules took their options with `array set o $args` and
swallowed every unknown option -- a misspelt `-onresult` simply did nothing.
`tkutlfmt::column` had a check, but it ran AFTER the merge, when every given
key already existed, so it could never fire (measured: `column $t 0 number
-decimalz 3` returned without error). The new helper module `tkuopts` merges
the options and rejects an unknown one with `{TKUTILS <MOD> OPTION <opt>}` and
`Known: ...`; all 24 sites use it. CONVENTIONS.md §5 now says so.

The modules changed behaviour (a call with a wrong option that used to pass
now raises), so each is counted up once:
`tkucalc` 0.2, `tkucalendar` 0.2, `tkudavbrowser` 0.2, `tkufilelist` 0.2, `tkufiletree` 0.2, `tkufilterbar` 0.2, `tkuical` 0.2, `tkuini` 0.2, `tkulauncher` 0.2, `tkuldif` 0.2, `tkunotes` 0.2, `tkupath` 0.2, `tkustatus` 0.2, `tkutab` 0.2, `tkutablelist` 0.3, `tkutical` 0.3, `tkutlfmt` 0.2, `tkutodo` 0.2, `tkutree` 0.2, `tkuvcard` 0.2.

Before the change every call site in tkutils and ctrlutils (apps, examples,
`bin/`, other modules) was checked against
the options the procs know: 274 calls, none with an unknown option.

### `tkufiletree`: `-provider` (found through the stricter options)

A tree created with `-provider $prov` hit an option `tkufiletree`
did not have: up to 0.1 `array set` swallowed it, and a ZIP or WebDAV
tab showed the **local** filesystem in its tree. With the option check the
call failed instead (2026-09-19). `tkufiletree` 0.2 now takes `-provider` and lists and tests
directories through it; without it, nothing changes. Provider paths are not
passed through `file normalize` (that would make "/x" into "C:/x" on
Windows). New tests with a provider whose paths do not exist locally
(`tkufiletree-9.*`); with the provider branch disabled they fail.

My check of all call sites before the change had missed this: it cut each
call at the first "]", and `-provider` came after `-root [_treeRoot $prov]`.
The claim "274 calls, none with an unknown option" was wrong.

### `tests/all.tcl` says where the modules come from

Before the tests run, the runner prints which file each library resolves to
(tkutils, tclutils) -- found without loading anything -- and which module-path
variables are set. An old file beside a new one shows as `(also: <version>)`.
(Idea 5; on 2026-09-19 a green run depended on a `TCL9_0_TM_PATH` in the
shell, and old `.tm` files lay beside new ones after unpacking a zip.)

Own trees first: when the tree is already listed in `TCL8_6_TM_PATH` /
`TCL9_0_TM_PATH` behind a directory with an installed copy of the same version
(e.g. `site-tcl`), `tcl::tm::path add` does nothing and the installed copy
wins -- the suite then tests that copy, not the tree (reproduced with Tcl 8.6:
`TCL8_6_TM_PATH=<tree>:<site-tcl>`). The runner now removes its own trees from
those variables for the test processes and puts them in front in its own
interpreter, so the banner shows what the tests load. A test file started
directly, without the runner, is still exposed to this.

### `tests/all.tcl` fails when a test fails

The runner looked only at each file's exit code, and tcltest exits 0 even when
tests fail — the suite reported success with red tests in it (review of
2026-09-19). It now reads every file's `Total … Failed N` line and exits 1 for
failed tests, a missing summary, or an error. Counter-checked with a file that
has a failing test and one that writes no summary.

### Every module has a description and a category

8 modules had neither a `# Description:` nor a `# Category:` header line, so
`tools/check-modules.tcl` and its GUI showed empty columns for them (`tkucalc`, `tkucalendar`, `tkufilelist`, `tkulauncher`, `tkupath`, `tkupreview`, `tkutab`, `tkuwinico`).
Added, with categories from the existing list. `tests/headers.test` (new)
fails when a module lacks either line (counter-checked by removing one).

`tools/md2man.tcl` is the same file as in tclutils (it now finds sub-modules;
no change for tkutils; 72 pages with `tkuopts`). `tools/check-modules.tcl` is now the same file as in tclutils (it gained the
sub-module handling there); for tkutils, which has no sub-modules, report and
manifest are unchanged.

### One version per module

`tests/versions.test` (new, also in tclutils and ctrlutils) checks that the
version in the file name, in `package provide` and in `variable version`
agree. `tkuimage` said `variable version 0.1` in `tkuimage-0.2.tm`; aligned.
Nothing reads the variable, so only the information was wrong. Old files next
to new ones (e.g. `tkudialog-0.1.tm` beside `-0.2.tm`) are what
`tools/check-modules.tcl` reports as multi-version; this test does not look
for them.

### Documentation

- `tkupreview.md`: `kind` reports what is shown. After a fallback to plain
  text — `html` without `tcllitehtml`, or `json`/`xml`/`ini` whose viewer
  cannot show the content — it is `text` (measured).
- README: the optional table lists the tablelist helpers `tkutl*`;
  `tkutltools` loads all of them except `tkutltree` (read from its source).
- README: the core table lists the 50 widgets the umbrella loads (it said 41
  and missed `tkufilelist`, `tkupath`, `tkupreview`, `tkutab`, `tkulauncher`,
  `tkucalc`, `tkucalendar`, `tkudhash`, `tkuwheel`). `tkuwinico` moved from
  "optional" to the core table — the umbrella has loaded it since 0.43.0.
- `docs/guide/tkutils-modules.md` regenerated with
  `check-modules -manifest md` (71 modules).
- `tkufilelist.md` documents `selectedEntries`, `tkufiletree.md`
  `volumesRoot` (both reported by `check-docman`).
- `apps/apps.md` lists `launcher/` and `tdbc-sqlite-editor/`. Apps that are
  not committed yet (e.g. `adressbuch/`) are not listed.

## 0.43.0

- `tkuwinico` 0.1 — build Windows `.ico` files from Tk images. The module renders
  the individual sizes and hands PNG payloads to `tclutils::tuico`, which
  assembles the container; transparency survives the whole path.
  - `fromSvg` renders **every size from the vector**
    (`-format {svg -scaletowidth N}`), so each step is crisp rather than
    resampled. Tk 9 has SVG built in; under Tk 8.6 the `tksvg` package provides
    the same photo format.
  - `fromPhoto` scales one square raster image with Tk's integer
    `-zoom`/`-subsample`. That is nearest-neighbour sampling and gets ragged at
    16 pixels — documented as such, with `fromSvg` as the recommendation.
  - `fromPhotos` packs caller-rendered images, one per size, scaling nothing.
  - `defaultSizes` returns `{256 128 64 48 32 16}`.
  - Errors use `errorCode {TKUTILS TKUWINICO <REASON>}`.
  - 13 tests, headless under Xvfb, green on Tk 9.0.4 — including an alpha
    round-trip check and a resolution check on the extracted payload.
- Example `make-icon.tcl`: turns an SVG or PNG into an `.ico` from the command
  line.

Requires tclutils 0.61.0 for `tclutils::tuico` 0.1.

## 0.42.2

- Apps `tkdevtools` and `tkudesigner` now expose a `::app::buildApp` entry proc
  guarded by the usual `argv0` check, so they package with
  `build-app -launch '::app::buildApp .'` like every other app — the earlier
  `-bootstrap tkutils` workaround is no longer needed for any bundled app.
- Their `--shot` screenshot mode uses Img's `window` photo format
  (`img::window`) instead of ImageMagick's `import` — self-contained,
  cross-platform, and free of an external tool. It falls back to `import` only
  when `img::window` is unavailable.
- `tkdevtools` gains a **Graphemes** reference tab: it segments an input string
  into grapheme clusters (combining marks, emoji skin-tone / ZWJ sequences,
  flags) and shows each cluster with its component code points, making the
  code-point-vs-cluster gap visible (a simplified UAX #29 segmenter, ready to
  defer to a native core grapheme command once one ships).
- Recommended pairing: tclutils 0.60.0 + tkutils 0.42.2.

## 0.42.1

- README updated to 0.42.0 / 41 core widgets; recommended pairing is now
  tclutils 0.59.0 + tkutils 0.42.0.
- Restored `tests/stack.test` (loads tclutils + tkutils in one interpreter and
  exercises a widget against its engine); referenced in the README but the file
  had been missing.
- `tkudhash` added to the umbrella and given a man page.

## 0.42.0

Changes since 0.41.0.

- `tkuwheel` 0.2: new `-dynamic 0|1` option for `redirect`. With `-dynamic 1` a
  `<Configure>` hook on the root re-applies the wheel binding (coalesced via
  `after idle`) to descendants that are **added after the call** -- e.g. a
  designer palette whose tool buttons are created at runtime. `unbind` stops the
  dynamic re-application.
- `tkuwheel` 0.2: horizontal tilt-wheel support on X11. `-orient x` and
  `-orient both` now also bind `<Button-6>`/`<Button-7>` (Tk 8.7+; wrapped in
  `catch`, so Tk 8.6 skips them cleanly). The 0.1 API is unchanged; existing
  calls behave exactly as before. Tests 17 total (16 + 1 tilt-skip on 8.6).

## 0.41.0

Changes since 0.40.0.

- `tkueditor` 0.2: optional toolbar (`tkutoolbar` + `tkuicon` icons, with a text
  fallback when SVG is unavailable) carrying Open, Save, Undo, Redo, Cut, Copy
  and a find box, and an optional status bar (`tkustatus`) showing the modified
  flag, encoding, line-ending style and Ln/Col. Both default on; turn them off
  with `-toolbar 0` / `-statusbar 0`.
- `tkueditor` encoding-aware load/save via `tclutils::tuiconv` (default utf-8,
  so a document behaves identically under Tcl 8.6 and 9.x). Line endings are
  detected on load, normalised to LF in the buffer and restored on save.
- `tkueditor` new API (the 0.1 API is unchanged): `-toolbar`, `-statusbar`,
  `-encoding`, `-eol` options plus `encoding`, `eol`, `toolbarWidget`,
  `statusbarWidget`, `setStatus`, `refreshStatus`. The toolbar's Undo/Redo and
  Cut/Copy follow the undo stack and the selection; loading a file leaves the
  cursor at the start. The `bin/tkueditor.tcl` launcher now uses the built-in
  toolbar and status bar and keeps its find/replace bar.

## 0.40.0

Changes since 0.28.0. The widget set grew substantially and the original core
widgets were renamed to the `tku*` prefix for namespace hygiene. Runs on Tk 8.6
and Tk 9.x.

- Prefix rename: the initial core widgets `tk*` were renamed to `tku*`
  (`tkhexedit` -> `tkuhexedit`, `tkform` -> `tkuform`, `tktoolbar` ->
  `tkutoolbar`, etc.). The umbrella now lists 39 widgets.
- Shared GUI helpers / behaviours: `tkuaction` (action objects + accelerators),
  `tkuballoon` (tooltips), `tkubind` (binding helpers), `tkucontextmenu`,
  `tkukeynav` (keyboard navigation), `tkumarquee` (canvas rubber-band select),
  `tkulabeled`, `tkuvalidate`, `tkutree`.
- New widgets: `tkufilterbar`, `tkusearchbar`, `tkutags`, `tkutodo`, and the
  entry widgets `tkudateentry`, `tkutimeentry`, `tkunumentry`.
- WebDAV widgets: `tkudavaccount`, `tkudavbrowser`.
- `tkutoolbar` 0.2 (action integration, tooltip delegation to `tkuballoon`).
- `tkuimage` 0.2: image viewer widget with `view`, fit/zoom, `zoomLevel` and a
  `-onchange` callback; lazy imgtools detection and display-size clamping.
- Optional widgets (not in the umbrella, external dependency or specialised):
  `tkcanvaspng`, `tkmonthcanvas`, `tkuicon` (tksvg), `tkuscrolledframe`
  (scrollutil), `tkusqlite` (sqlite3), `tkutablelist` (Tablelist), `tkutical`,
  `tkuxml` (tDOM).
- Per-module `test` / `doc` / `man`; `tcltest` suite green on Tk 8.6 and Tk 9.x
  (optional widgets skip cleanly when their dependency is absent).
- Recommended pairing: tclutils 0.53.0 + tkutils 0.40.0.

## 0.28.0

Initial public release.

- Tk GUI widgets built on the pure-Tcl engines in `tclutils`; kept separate so
  console/server/CI use never requires Tk. Runs on Tk 8.6 and Tk 9.x.
- 20 core widgets in the umbrella package: tkhexedit, tkcsv, tkdiff, tkmd,
  tkjson, tkcal, tkeditor, tkzip, tkfuzzy, tkbase64, tkstrings, tknotes, tkical,
  tkldif, tkini, tkvcard, plus the shared GUI helpers tkdialog, tkform,
  tktoolbar, tkstatus.
- Editing in the record viewers (tkini, tkvcard, tkldif, tkical, tknotes) with
  `-editable 0` for read-only use.
- Optional widgets (not in the umbrella, external dependency): tktablelist
  (Tablelist), tkxml (tDOM), tksqlite (sqlite3).
- README widget catalogue, per-widget docs and man pages, runnable demos and
  CLI launchers.
- `tcltest` suite including `tests/stack.test` (tclutils + tkutils in one
  interpreter); green on Tk 8.6 and Tk 9.x (optional widgets skip cleanly when
  their dependency is absent).
- Recommended pairing: tclutils 0.41.0 + tkutils 0.28.0.
