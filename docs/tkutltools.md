# tkutils::tkutltools

Umbrella for the tablelist extension family. Requiring this one package pulls in
`tablelist` (external) plus all `tkutl*` helpers and their shared
`tclutils::tunum` number backend.

## Package

```tcl
package require tkutils::tkutltools 0.1
```

It is kept **separate** from the main `tkutils` umbrella, which by design loads
only modules with pure-Tk/tclutils dependencies. `tablelist` is external, so
require `tkutltools` only where tablelist is available.

## Loads

| Module | Purpose |
|--------|---------|
| `tkutils::tkutlsort`   | type-aware column sorting (num/currency via tunum) |
| `tkutils::tkutlfmt`    | per-column display formatting |
| `tkutils::tkutlclip`   | copy rows to clipboard (TSV/CSV) |
| `tkutils::tkutlfooter` | synced footer + autosum/autoagg |
| `tkutils::tkutlfind`   | incremental find + highlight |
| `tkutils::tkutlstate`  | save/restore column layout |
| `tkutils::tkutltree`   | nested data ↔ multi-column tree |
| `tclutils::tunum`      | shared number parse/sum backend |

## Usage

```tcl
package require Tk
package require tkutils::tkutltools

# all tkutl* commands are now available
tablelist::tablelist .t -columns {0 Article left 0 Price right}
::tkutils::tkutlsort::column .t 1 num
::tkutils::tkutlfmt::column  .t 1 currency
::tkutils::tkutlclip::installBindings .t
```

See the individual module docs for details.
