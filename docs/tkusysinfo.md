# tkutils::tkusysinfo

A view of `tclutils::tusysinfo`: operating system, CPU, memory, computer
model, disks and monitors as a tree, plus a "Screen" section from Tk
itself (size in pixels and millimetres, DPI, `tk scaling`, colour depth,
windowing system). Buttons: Refresh, Copy (text report to the clipboard),
Save (text or JSON). Plain Tk (`ttk::treeview`), no Tablelist.

Not in the `tkutils` umbrella: it needs `tclutils::tusysinfo` 0.1 from
tclutils 0.69.0, while the umbrella still works with tclutils 0.64.0.

```tcl
package require tkutils::tkusysinfo 0.1
```

## API

```tcl
set w [::tkutils::tkusysinfo::widget .si ?options?]
::tkutils::tkusysinfo::refresh $w                 ;# collect again -> info dict
::tkutils::tkusysinfo::data    $w                 ;# last info dict
::tkutils::tkusysinfo::report  $w ?-anonymize 0|1? ;# text report
::tkutils::tkusysinfo::json    $w                 ;# JSON
::tkutils::tkusysinfo::save    $w file ?-format text|json? ?-anonymize 0|1?
::tkutils::tkusysinfo::screen  win                ;# Tk screen data as a dict
```

| Option | Default | Meaning |
|--------|---------|---------|
| `-sections` | all | `tusysinfo` sections: `os cpu memory machine disks displays` |
| `-serials` | `0` | `1` shows serial numbers |
| `-timeout` | `10000` | limit in ms for one platform program |
| `-autoload` | `1` | collect when the widget is built |
| `-height` | `16` | visible rows |
| `-buttons` | `1` | `0` hides the button bar |

The info dict is the one from `tusysinfo::collect` with an extra key
`screen`. `report` is `tusysinfo::report` plus a "Screen (Tk)" section;
`json` includes `screen`.

## Usage

```tcl
package require Tk
package require tkutils::tkusysinfo
pack [::tkutils::tkusysinfo::widget .si] -fill both -expand 1
```

Without the slow macOS `system_profiler` call:

```tcl
::tkutils::tkusysinfo::widget .si -sections {os cpu memory}
```

## Notes

- Tk sees one screen: with several monitors `pixels` is the whole
  desktop of the X screen (Linux) or the main monitor (Windows, macOS).
  The monitors themselves come from their EDID under "Monitors".
- Collecting runs in the event loop of the caller; on macOS it takes a few
  seconds, the cursor shows `watch` meanwhile.

## Errors

Unknown option: `{TKUTILS TKUSYSINFO OPTION <opt>}` with the known ones
(`tkuopts`). Bad save format: `{TKUTILS TKUSYSINFO FORMAT}`. Errors of
`tusysinfo` pass through.
