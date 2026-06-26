# tkutils::tkutlfooter

A footer row for a `tablelist` widget, realised as a second single-row
tablelist below the main table ("header at the bottom" look). The footer mirrors
the main table's column widths, order and alignment, keeps horizontal scrolling
in sync, and can compute auto-sums. Library-neutral — no references to any
application.

## Package

```tcl
package require tkutils::tkutlfooter 0.1
```

Requires `tablelist`. Horizontal scroll sync chains the main table's
`-xscrollcommand` (no `scrollutil` needed). `autosum`/`autoagg` use
`tclutils::tunum` for number parsing when available (falls back to a built-in
parser otherwise).

## Commands

```tcl
::tkutils::tkutlfooter::attach  tblMain tblFoot ?-autowire 1?
::tkutils::tkutlfooter::update  tblMain tblFoot
::tkutils::tkutlfooter::setvals tblFoot {val0 val1 ...}
::tkutils::tkutlfooter::autosum tblMain tblFoot ?-columns {1 2}? ?-label "SUM:"? ?-format "%.2f"?
::tkutils::tkutlfooter::detach  tblMain tblFoot
```

## Quick Start

```tcl
package require Tk
package require tablelist
package require tkutils::tkutlfooter

tablelist::tablelist .t -columns {0 "Article" left 0 "Price" right} -stretch all
tablelist::tablelist .f -showlabels 0 -height 1
pack .t -fill both -expand 1
pack .f -fill x

.t insert end {Apple 1,50}
.t insert end {Pear  2,00}
.t insert end {Cherry 4,20}

::tkutils::tkutlfooter::attach  .t .f
::tkutils::tkutlfooter::autosum .t .f -columns {1} -label "Sum:" -format "%.2f"
```

The footer now shows `Sum:` and `7.70`, and stays aligned with the main table
when columns are resized, reordered or scrolled.

Since 0.2 the footer also clones the main table's `-titlecolumns`, hidden
columns and `-stretch` policy, and the horizontal-scroll coupling *chains* the
main table's existing `-xscrollcommand` instead of replacing it. This means a
table that already has its own scrollbar (e.g. inside a wrapper) keeps that
scrollbar working while the footer stays aligned -- including under frozen
title columns.

## attach

Configures `tblFoot` as a label-less, non-selectable single footer row, clones
the main table's columns, and wires up the sync bindings. With `-autowire 1`
(default) horizontal scrolling is coupled by chaining the main table's
`-xscrollcommand`: the footer is moved to the same position and the table's
original scroll command (e.g. a scrollbar's `set`) is then invoked, so a
pre-existing scrollbar keeps working.

## update

Re-applies the main table's column order, widths, alignment and stretch to the
footer. Called automatically on `<<TablelistColumnResized>>`,
`<<TablelistColumnMoved>>` and `<Configure>`; call it manually after
programmatic column changes if needed.

## setvals

Writes explicit values into the footer row (indexed by column).

```tcl
::tkutils::tkutlfooter::setvals .f {Total 8,70}
```

## autosum

Computes column sums over the main table and writes the formatted totals into
the footer. Column 0 receives `-label`. Only the columns in `-columns` are
summed (default: all). Number parsing uses `tclutils::tunum` when available.

```tcl
::tkutils::tkutlfooter::autosum .t .f -columns {1 3} -label "Σ" -format "%.2f"
```

`autosum` is display-only — it does not maintain a data model; re-run it after
the table's data changes.

## autoagg

Like `autosum`, but with a per-column aggregate function. `-columns` is a
`{col func col func ...}` list; `func` is one of `sum`, `avg`, `min`, `max`,
`count` (all rows) or `countnum` (numeric rows). Numeric results use `-format`;
counts are integers. Column 0 receives `-label`.

```tcl
::tkutils::tkutlfooter::autoagg .t .f \
    -columns {1 sum 2 avg 3 max} -label "Σ" -format "%.2f"
```

## detach

Removes the sync bindings and restores the original scroll wiring.

## Error codes

Errors are raised with `-errorcode {TKUTILS TKUTLFOOTER <REASON>}`.

## PDF export

`pdf4tcltable` (in `pdf4tcllib`) can render the footer into a PDF: pass the
footer widget as `-footer`, e.g.
`::pdf4tcllib::tablelist::render $pdf .t $x $y -footer .f`.
