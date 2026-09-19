# tkutils::tkuopts

Option checking for tkutils widgets and procs: merge the caller's options over
the defaults, and reject an option that does not exist — with the known ones
in the message.

```tcl
::tkutils::tkuopts::merge MOD defaults argv   ;# -> merged option/value list
```

- `MOD` — the upper-case module name (`TKUCALC`), used in the errorcode.
- `defaults` — option/value pairs, e.g. `[array get o]`.
- `argv` — the caller's options.

Errors:

| errorcode | message |
|---|---|
| `{TKUTILS <MOD> OPTION <opt>}` | `unknown option "-x"` / `Known: -a -b` |
| `{TKUTILS <MOD> OPTION}` | `missing value for option "-x"` |

## Why

Up to tkutils 0.44.0 (first build) 24 procs in 20 modules took their options
with `array set o $args` and swallowed every unknown option — a misspelt
`-onresult` simply did nothing. `tkutlfmt::column` had a check, but it ran
after the merge, when every given key already existed, so it could never fire
(measured 2026-09-19). All 24 sites now use:

```tcl
array set o {-onresult "" -history 0}
array set o [::tkutils::tkuopts::merge TKUCALC [array get o] $args]
```

Pure Tcl, no Tk. Not in the umbrella: the modules that need it require it
themselves.
