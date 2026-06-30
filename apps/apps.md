# tkutils — apps

Standalone programs built on tkutils/tclutils. Each app has its own folder
(source, tests, optionally examples).

| App | Purpose |
|---|---|
| `tkudesigner/`        | visual GUI designer (.tkd) + loader demos |
| `csv-editor/`         | CSV editor (tkutablelist) |
| `notes-app/`          | notes app (tclutils::tunotes) |
| `sqlite-editor/`      | SQLite browser/editor (form and sheet views) |
| `search-replace-tool/`| search/replace across files |
| `tkdevtools/`| Tcl/Tk developer toolbox: colors, characters, fonts, units, timezones, cursors, relief/anchor, keysym probe, ttk theme & style browser, regexp & format/scan testers, encodings, virtual events, bitmaps, widget explorer, pack/grid playgrounds, clock-format codes |

## Module paths
Every app sources `_lib/paths.tcl` (`::tkupaths::add`), which locates the
tclutils/tkutils modules (existence-checked): an env override plus platform
defaults, otherwise repo-relative. Details and the full candidate list:
[`../docs/guide/module-paths.md`](../docs/guide/module-paths.md).

So the apps run without a manual `export`, provided the modules sit in one of
the standard locations; with `TCLUTILS_TM`/`TKUTILS_TM` set, that wins.
