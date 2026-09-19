# Changelog

## 0.44.0

Recommended pairing: tclutils 0.63.0 + tkutils 0.44.0 + ctrlutils 0.2.

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
  real desktop (reported from lxpro; reproduced with openbox, whose border and
  title bar put the content at +1+20). The placement itself was right in both.
  Measured under openbox, xfwm4 and without a window manager, Tcl/Tk 9.0.4 and
  8.6.14.

**Window-manager decoration (found in the third review, lxpro).** Most window
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

(lxpro reported +5, +28.) The offset cannot be computed in advance — openbox
places transient dialogs by their content but other toplevels by their
frame — so `tkudialog` now measures the dialog once it is mapped and moves it
by the difference, once. Offsets of 100 px or more are left alone: then the
window manager placed the dialog on purpose. Note from the measurement: the
`update idletasks` in `_place` already maps the new toplevel, so a `<Map>`
binding set afterwards never fired; the check is scheduled directly in that
case. Tests (`tkudialog.test`, and `cufileops.test` in ctrlutils) pass under
icewm, fluxbox, metacity, openbox, xfwm4 and without a window manager, on Tcl/Tk
9.0.4 and 8.6.14; without the correction, icewm shows the three failures
reported from lxpro. The test waits until the parent's position has settled
(at most 1 s): under fluxbox with Tk 8.6 the first dialog was otherwise placed
against the parent's pre-decoration position. `tkwait visibility` hung there
and is not used.

ctrlutils 0.2 passes `-parent` from its file operations; with the old
`cufileops` the Explorer's prompts stayed on the wrong monitor even with this
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
`bin/`, other modules, the Explorer, the address book) was checked against
the options the procs know: 274 calls, none with an unknown option.

### `tkufiletree`: `-provider` (found through the stricter options)

The Explorer always created its tree with `-provider $prov`. `tkufiletree`
had no such option: up to 0.1 `array set` swallowed it, and a ZIP or WebDAV
tab showed the **local** filesystem in its tree. With the option check the
call failed instead, and the Explorer did not start (reported from lxpro,
2026-09-19). `tkufiletree` 0.2 now takes `-provider` and lists and tests
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
