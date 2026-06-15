# tkutils::tkutlfind

Incremental find with match highlighting for a `tablelist` widget. Unlike a
filter (which hides non-matching rows), `tkutlfind` highlights the matching
cells and lets you step through them with next/prev. Complements
`tkutils::tkufilterbar`. Library-neutral.

## Package

```tcl
package require tkutils::tkutlfind 0.1
```

Requires `Tk` and `tablelist`.

## Commands

```tcl
::tkutils::tkutlfind::find    tbl query ?options?   ;# -> match count, highlights
::tkutils::tkutlfind::next    tbl                   ;# -> {row col} | {}
::tkutils::tkutlfind::prev    tbl                   ;# -> {row col} | {}
::tkutils::tkutlfind::matches tbl                   ;# -> list of {row col}
::tkutils::tkutlfind::clear   tbl
```

`next`/`prev` cycle through the matches (wrapping), scrolling each into view
(`seecell`) and activating its row.

## Options (find)

| Option         | Default     | Meaning                                      |
|----------------|-------------|----------------------------------------------|
| `-columns`     | all visible | columns to search                            |
| `-mode`        | `substring` | `substring`, `exact`, `glob`, `regexp`       |
| `-nocase`      | `1`         | case-insensitive matching                    |
| `-highlightbg` | `#ffe9a8`   | background for matching cells                |
| `-highlightfg` | `{}`        | optional foreground for matching cells       |

## Usage

```tcl
package require Tk
package require tablelist
package require tkutils::tkutlfind

# search box that highlights as you type
entry .e -textvariable q
bind .e <KeyRelease> { ::tkutils::tkutlfind::find .t $q }
bind .e <Return>     { ::tkutils::tkutlfind::next .t }

# F3 / Shift-F3 to step through matches
bind . <F3>       { ::tkutils::tkutlfind::next .t }
bind . <Shift-F3> { ::tkutils::tkutlfind::prev .t }
```

Search only one column with a regular expression:

```tcl
::tkutils::tkutlfind::find .t {^A.*t$} -mode regexp -columns 0
```

## Notes

- Matching uses the **displayed** values (`getformatted`), so it finds what the
  user sees (e.g. formatted numbers from `tkutlfmt`).
- Re-run `find` after sorting/filtering, since row indices change.
- `clear` restores the cells' original background (and foreground if set).

## Error codes

`-errorcode {TKUTILS TKUTLFIND <REASON>}` (`MODE`, `OPTION`).
