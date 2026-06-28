# tkudesigner — examples

Designs (`.tkd`) built with tkudesigner, each paired with a runnable demo that
loads it through `tkutils::tkuload` and binds values by name.

| Design | Demo | Shows |
|---|---|---|
| `modern_adressbuch.tkd`       | `demo-modern.tcl`            | form layout + `byName` value binding (fill / collect) |
| `line_items_editor.tkd`       | `demo-host-positions.tcl`    | table: select a row → edit → recompute sums |
| `modern_faktura_complete.tkd` | `demo-host.tcl`, `demo-load.tcl` | flagship form: load + fill header/sums by name, read back |

## Running

Modules are located automatically (see `apps/_lib/paths.tcl`); no environment
setup is needed when tclutils/tkutils are installed or sit beside this checkout.

```sh
wish example/demo-modern.tcl           # form; prints the collected values
wish example/demo-host-positions.tcl   # table editing, wired host-side
wish example/demo-host.tcl             # load + fill by name; prints a round-trip readback
wish example/demo-load.tcl ?file.tkd?  # instantiate a design (default: modern_faktura_complete)
```

Open any design in the editor:

```sh
wish tkudesigner.tcl                   # then File ▸ Open the .tkd
```

Verified on Tcl/Tk 8.6 and 9.0.
