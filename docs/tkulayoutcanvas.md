# tkutils::tkulayoutcanvas

Visual block layout designer on a Tk canvas. Place named blocks on a paper-sized
page in millimetres, snap to a grid, toggle visibility, and edit geometry in a
built-in side panel. Backend: `tclutils::tulayout`.

Designed for a **coarse** layout step (block positions and visibility). Fine
tuning (columns, fonts, PDF overlay) stays in the host application.

## API

```tcl
::tkutils::tkulayoutcanvas::widget $path ?options?
::tkutils::tkulayoutcanvas::configure $path ?-option value ...?
::tkutils::tkulayoutcanvas::cget $path -option
::tkutils::tkulayoutcanvas::getBlocks $path
::tkutils::tkulayoutcanvas::setBlocks $path $blocks
::tkutils::tkulayoutcanvas::select $path $blockId
::tkutils::tkulayoutcanvas::getCanvas $path
::tkutils::tkulayoutcanvas::redraw $path
::tkutils::tkulayoutcanvas::mergePreset $path $presetDict ?-keys {x y w show}?
```

### Options (creation and `configure`)

| Option | Default | Meaning |
|--------|---------|---------|
| `-paper` | `a4` | Paper name (`a4`, `a5`, `letter`) |
| `-orientation` | `portrait` | `portrait` or `landscape` |
| `-margin` | `20.0` | Page margin in mm (drawn as dashed rect) |
| `-gridmm` | `5.0` | Snap grid in mm |
| `-scale` | `3.0` | Pixels per mm on the canvas |
| `-blocks` | `{}` | Block dict (id → block) |
| `-definitions` | `{}` | Catalog dict: default label/size for each id |
| `-blockorder` | `{}` | Explicit draw/list order (else from definitions) |
| `-onchange` | `{}` | Callback: `cmd $path $blocks` after drag/edit |
| `-showgrid` | `1` | Draw mm grid |
| `-properties` | `1` | Show list + spinboxes panel |
| `-width` / `-height` | `640` / `480` | Initial canvas size |

### Interaction

- Click a block on the canvas or in the list to select it.
- Drag a block; coordinates snap to `-gridmm`.
- Auto-Y blocks (`y==0` or `lockedY 1`) show a grey dashed preview, keep `y` at
  `0`, and only move horizontally when dragged.
- Spinboxes and the **Visible** checkbutton update the block dict and fire
  `-onchange`.

### Minimal example

```tcl
package require tkutils::tkulayoutcanvas

set defs {
    title {label Title w 160 h 12}
    body  {label Body  w 160 h 50}
}
set blocks {
    title {label Title x 25 y 30 w 160 h 12 show 1}
    body  {label Body  x 25 y 55 w 160 h 50 show 1}
}

tkutils::tkulayoutcanvas::widget .lc -blocks $blocks -definitions $defs \
    -onchange {apply {{p b} {
        puts "layout changed: [dict size $b] blocks"
    }}}
pack .lc -fill both -expand 1
```

## Demo

```bash
wish examples/demo-tkulayoutcanvas.tcl
# or
wish bin/tkulayoutcanvas.tcl
```

## Tests

```bash
tclsh tests/tkulayoutcanvas.test
# headless: xvfb-run -a tclsh tests/tkulayoutcanvas.test
```

## Integration guide

See `docs/HANDOFF-layout-designer.md` for how a host app (e.g. a document editor)
wires presets, handoff files, and `mergeBlocks`.

## Error codes

`{TKUTILS TKULAYOUTCANVAS NOWIDGET|OPTION|EXISTS|BLOCK}`
