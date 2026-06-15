# tkutils::tkutlclip

Copy `tablelist` rows to the clipboard as TSV or CSV — the common
"Ctrl+C copies the selection as spreadsheet-pasteable text" behaviour that
tablelist itself does not provide. Library-neutral.

## Package

```tcl
package require tkutils::tkutlclip 0.1
```

Requires `Tk` and `tablelist`. Uses `tclutils::tucsv` for CSV quoting when
available (falls back to a built-in quoter otherwise).

## Commands

```tcl
::tkutils::tkutlclip::copySelection   tbl ?options?
::tkutils::tkutlclip::copyAll         tbl ?options?
::tkutils::tkutlclip::asText          tbl rows ?options?
::tkutils::tkutlclip::installBindings tbl ?options?
```

`tbl` is the tablelist widget. `copySelection`/`copyAll` return the number of
rows copied; `asText` returns the built string without touching the clipboard.

## Options

| Option       | Default   | Meaning                                            |
|--------------|-----------|----------------------------------------------------|
| `-format`    | `tsv`     | `tsv` or `csv`                                     |
| `-header`    | `0`       | prepend column titles as the first line            |
| `-formatted` | `1`       | use displayed values (`getformatted`) vs raw cells |
| `-columns`   | `visible` | `visible` (skip hidden columns) or `all`           |

## Usage

```tcl
package require Tk
package require tablelist
package require tkutils::tkutlclip

tablelist::tablelist .t -columns {0 Article left 0 Qty right 0 Price right}
# ... insert rows ...

# Ctrl+C copies the selected rows as TSV
::tkutils::tkutlclip::installBindings .t

# Copy everything as CSV with a header row
::tkutils::tkutlclip::copyAll .t -format csv -header 1
```

Get the text without using the clipboard:

```tcl
set tsv [::tkutils::tkutlclip::asText .t {0 1 2} -header 1]
```

## Notes

- TSV replaces embedded tabs/newlines with spaces so pasted cells stay aligned.
  Use CSV when cells may contain those characters and you need them preserved.
- `installBindings` binds `<<Copy>>` on the tablelist body, so it coexists with
  normal text-entry copy in edited cells.

## Error codes

`-errorcode {TKUTILS TKUTLCLIP <REASON>}` (`OPTION`, `FORMAT`, `COLUMNS`).
