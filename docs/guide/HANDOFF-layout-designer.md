# Layout designer — handoff for utils maintainers and host-app integrators

This document describes how to adopt `tclutils::tulayout` and
`tkutils::tkulayoutcanvas` as the **generic** coarse layout designer, and how a
host application (e.g. a document editor) should consume it.

## Package layout

| Package | Role | Tk? |
|---------|------|-----|
| `tclutils::tulayout` | mm/px, snap, block validation, preset merge | no |
| `tkutils::tkulayoutcanvas` | Canvas megawidget + property panel | yes |

Both follow the usual utils conventions: `lib/tm/...`, `tests/*.test`, `docs/*.md`,
`man/mann/*.n`, English API/docs, error codes `TCLUTILS TULAYOUT *` /
`TKUTILS TKULAYOUTCANVAS *`.

## Maintainer checklist (utils repo)

1. **Umbrella** — `package require` in `tclutils-*.tm` / `tkutils-*.tm`; bump
   `package provide` version.
2. **CHANGELOG** — prepend entry for the release.
3. **README** — module table row + demo/launcher mention.
4. **docs/module-status.md** (tclutils) and **docs/architecture.md** (tkutils).
5. **Tests** — `tclsh tests/tulayout.test`; `tclsh tests/tkulayoutcanvas.test`
   (use `xvfb-run` when headless).
6. **Demo** — `wish examples/demo-tkulayoutcanvas.tcl`.

No change to lieferschein or other host apps is required for a utils release.

## Two-stage workflow (recommended)

```
┌─────────────────────┐     preset dict      ┌──────────────────────┐
│ tkulayoutcanvas     │ ──────────────────►  │ Host app main GUI      │
│ (coarse: x,y,w,show)│     mergeBlocks      │ (fine: columns, PDF,  │
└─────────────────────┘                      │  fonts, spinboxes)     │
                                             └──────────────────────┘
```

- **Stage 1 (designer):** block positions, widths, visibility — no PDF, no
  pdfium.
- **Stage 2 (host):** existing preview/renderer; `mergeBlocks` applies only
  `{x y w show}` so live document fields (fonts, table columns, …) are preserved.

## Block model

```tcl
# blocks: id -> dict
header {label Header x 20 y 30 w 170 h 15 show 1}
table  {label Table  x 20 y 0  w 170 h 40 show 1 lockedY 1}
```

- Origin: top-left, units: **mm**.
- `y == 0` or `lockedY 1` → auto vertical flow in the renderer; designer shows a
  preview slot but keeps `y` at `0`.
- `mergeBlocks` / `mergeLayout` default keys: `{x y w show}` — **not** `h`, `y`
  for auto blocks, or renderer-specific keys.

## Host application integration

### 1. Dependencies

```tcl
lappend auto_path .../tclutils/lib/tm .../tkutils/lib/tm
package require tclutils::tulayout 0.1
package require tkutils::tkulayoutcanvas 0.1
```

Or depend on umbrella `tclutils` / `tkutils` after the release that includes
these modules.

### 2. Block catalog (`-definitions`)

The host owns semantic block ids and default sizes:

```tcl
set defs {
    kopf     {label Kopf     w 170 h 15}
    tabelle  {label Tabelle  w 170 h 40 lockedY 1}
    fusszeile {label Fußzeile w 170 h 10}
}
```

Pass `-definitions $defs` and current `-blocks` from the document layout.

### 3. Standalone designer window

```tcl
proc openLayoutDesigner {parent blocksVar defs onSave} {
    set top .layoutDesigner
    if {[winfo exists $top]} { raise $top; return }

    toplevel $top
    wm title $top "Layout designer"

    set lc [tkutils::tkulayoutcanvas::widget $top.lc \
        -blocks [set $blocksVar] -definitions $defs -paper a4 -gridmm 5]

    ttk::frame $top.bar
    ttk::button $top.bar.ok -text "Apply" -command [list apply {{top lc blocksVar onSave} {
        set ::$blocksVar [tkutils::tkulayoutcanvas::getBlocks $lc]
        uplevel #0 $onSave
        destroy $top
    }} $top $lc $blocksVar $onSave]]
    ttk::button $top.bar.cancel -text "Cancel" -command [list destroy $top]
    pack $top.bar.ok $top.bar.cancel -side right -padx 4
    pack $top.bar -fill x -padx 8 -pady 4
    pack $top.lc -fill both -expand 1 -padx 8 -pady 8
}
```

### 4. Preset storage

Store a **blocks** dict (or full layout with `blocks` key) under an app-specific
settings key, e.g. `layout_preset_lieferschein`.

```tcl
# Save preset from designer
set preset [dict create blocks [tkutils::tkulayoutcanvas::getBlocks .lc]]
$store settingSet $db layout_preset_lieferschein $preset

# New document — merge preset into defaults
set preset [$store settingGet $db layout_preset_lieferschein ""]
if {$preset ne ""} {
    set doc [tclutils::tulayout::mergeLayout $doc $preset]
}
```

### 5. Thin domain wrapper (optional)

Host apps may keep a tiny `myapp::layout` module that only re-exports paper sizes
and default block catalogs, delegating math to `tulayout`:

```tcl
namespace eval ::myapp::layout {
    namespace path ::tclutils::tulayout
    namespace export mergeBlocks mergeLayout pageSize
    proc definitions {doctype} { ... }  ;# app-specific catalog
}
```

Avoid duplicating `mmToPx`, `snap`, or `mergeBlocks` in the host.

### 6. Process handoff (optional)

For a separate `wish` designer process, write the blocks dict to a temp file and
read it back on OK — same as any Tcl dict serialisation. `mergeBlocks` on return
is still required so renderer-only keys survive.

## What not to put in utils

- Document-type enums, SQLite settings, PDF/pdfium preview
- Table column editors, font spinboxes
- Renderer-specific height estimation (host passes `h` in block dict or computes in
  fine GUI)

## Testing strategy

| Layer | Command |
|-------|---------|
| Engine | `tclsh tests/tulayout.test` |
| Widget | `tclsh tests/tkulayoutcanvas.test` |
| Host | App tests that `mergeLayout` preserves extra keys |

## API stability

Version `0.1` — public API as documented in `docs/tulayout.md` and
`docs/tkulayoutcanvas.md`. Bump minor on compatible additions; document breaking
changes in CHANGELOG.

## Files added in this delivery

```
tclutils/lib/tm/tclutils/tulayout-0.1.tm
tclutils/tests/tulayout.test
tclutils/docs/tulayout.md
tclutils/man/mann/tulayout.n

tkutils/lib/tm/tkutils/tkulayoutcanvas-0.1.tm
tkutils/tests/tkulayoutcanvas.test
tkutils/docs/tkulayoutcanvas.md
tkutils/docs/HANDOFF-layout-designer.md   ;# this file
tkutils/man/mann/tkulayoutcanvas.n
tkutils/examples/demo-tkulayoutcanvas.tcl
tkutils/bin/tkulayoutcanvas.tcl
```
