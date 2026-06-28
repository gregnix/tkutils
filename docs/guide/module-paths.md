# Module paths — loading tclutils / tkutils

Both libraries ship Tcl modules (`.tm`) under `lib/tm/<pkg>/`. There are three
ways to make them discoverable.

## 1. Installed in a standard location → nothing to do
If the modules sit where Tcl already searches, this is enough:
```tcl
package require tkutils::tkuform
package require tclutils::tucsv
```

## 2. A few modules ad-hoc → `tcl::tm::path add`
When you only need some modules from an arbitrary directory:
```tcl
tcl::tm::path add /path/to/tkutils/lib/tm
package require tkutils::tkuform
```

## 3. Relocatable / multiple locations → environment variable
```sh
export TCLUTILS_TM=/path/to/tclutils/lib/tm
export TKUTILS_TM=/path/to/tkutils/lib/tm
```

## What the bundled apps do
The apps under `apps/` source `apps/_lib/paths.tcl`. `::tkupaths::add` tries,
for each package, the locations below and adds only the ones that **exist**.
Order is priority (env wins — `tm::path add` prepends, so candidates are added
in reverse):

1. `TCLUTILS_TM` / `TKUTILS_TM` (override)
2. `[file dirname [info library]]/<pkg>/lib/tm` — next to the Tcl install (Linux **and** Windows)
3. `/usr/local/share/tcltk/<pkg>/lib/tm` — system-wide (Unix)
4. `$XDG_DATA_HOME`/`~/.local/share/tcltk/<pkg>/lib/tm` — per user (XDG)
5. `<repo-parent>/<pkg>/lib/tm` — side-by-side source checkout

A genuinely missing package then surfaces **loudly** via `package require` —
that is the intended signal, not the resolver.
