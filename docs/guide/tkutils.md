# tkutils — overview

Pure Tcl/Tk widget and utility library. Each widget/module ships as a `.tm`
under `lib/tm/tkutils/` in the `tkutils::<module>` namespace.

## Where things live
- **Module docs**: `docs/<module>.md` (one file per module, top level).
- **General guides**: `docs/guide/` (this folder) —
  [`module-paths.md`](module-paths.md) (loading modules),
  [`architecture.md`](architecture.md) (design/structure),
  [`HANDOFF-layout-designer.md`](HANDOFF-layout-designer.md).
- **Man pages**: `man/mann/<module>.n`.
- **Tests**: `tests/<module>.test` (run via `tests/all.tcl`).
- **Apps**: `apps/` — standalone programs built on the library
  (see [`../../apps/apps.md`](../../apps/apps.md)).

## Loading modules
See [`module-paths.md`](module-paths.md). In short: installed in a standard
location → `package require tkutils::<module>`; otherwise
`tcl::tm::path add <dir>` or set `TKUTILS_TM`.

## Conventions
Naming, error and test rules are in `../../CONVENTIONS.md`. Per-module hygiene
(TEST/DOC/MAN) is checked by `tools/check-modules.tcl`.
