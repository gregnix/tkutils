# tkutils::tkutlfmt

Per-column display formatting for a `tablelist` widget, via tablelist's
`-formatcommand`. The underlying cell value stays unchanged, so sorting and
filtering still operate on the raw number while the user sees a grouped /
currency / percent / date string. Pairs with `tkutils::tkutlsort`.
Library-neutral.

## Package

```tcl
package require tkutils::tkutlfmt 0.1
```

Requires `Tk` and `tablelist`. Uses `tclutils::tunum` to parse raw values when
present (falls back to a built-in parser).

## Commands

```tcl
::tkutils::tkutlfmt::column  tbl col type ?options?
::tkutils::tkutlfmt::columns tbl {col type ?{options}? ...}
```

## Format types

| type       | example (raw → shown)        |
|------------|------------------------------|
| `integer`  | `1234567` → `1.234.567`      |
| `number`   | `1234.5`  → `1.234,50`       |
| `currency` | `1234.5`  → `1.234,50 €`     |
| `percent`  | `0.125`   → `12,5 %`         |
| `date`     | `1717200000` → `01.06.2024`  |

Numeric types are right-aligned automatically (override with `-align`).

## Options

| Option        | Default | Applies to        | Meaning                              |
|---------------|---------|-------------------|--------------------------------------|
| `-locale`     | `eu`    | numeric           | `eu` (`.`/`,`) or `us` (`,`/`.`)     |
| `-decimals`   | type    | number/currency/% | decimal places                       |
| `-group`      | locale  | numeric           | thousands separator                  |
| `-decimal`    | locale  | numeric           | decimal separator                    |
| `-symbol`     | `€`     | currency          | currency symbol                      |
| `-symbolpos`  | `post`  | currency          | `pre` or `post`                      |
| `-align`      | auto    | all               | `right`/`left`/`center`              |
| `-informat`   | `{}`    | date              | `clock scan` format (else auto/epoch)|
| `-outformat`  | `%Y-%m-%d` | date           | `clock format` format               |

## Usage

```tcl
package require Tk
package require tablelist
package require tkutils::tkutlfmt

tablelist::tablelist .t -columns {0 Article left 0 Price right 0 Share right 0 Date left}
# raw values: Price=1234.5  Share=0.125  Date=epoch
.t insert end [list Apple 1234.5 0.125 1717200000]

::tkutils::tkutlfmt::column .t 1 currency
::tkutils::tkutlfmt::column .t 2 percent
::tkutils::tkutlfmt::column .t 3 date -outformat "%d.%m.%Y"
```

Bulk form (optional brace-grouped options per column):

```tcl
::tkutils::tkutlfmt::columns .t {
    1 currency {-symbol $ -symbolpos pre -locale us}
    2 percent
    3 date {-outformat %d.%m.%Y}
}
```

## Notes

- Store **raw numbers** in the cells (e.g. `1234.5`, not `"1.234,50 €"`); the
  formatter renders them and `tkutlsort`/native sort compares them numerically.
- Non-numeric / non-date cells are passed through unchanged.

## Error codes

`-errorcode {TKUTILS TKUTLFMT <REASON>}` (`TYPE`, `OPTION`, `LOCALE`).
