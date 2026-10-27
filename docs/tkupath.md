# tkutils::tkupath

A breadcrumb path bar. Shows a path as a row of clickable segments:
`/srv/daten/docs` becomes `[/] [srv] [daten] [docs]`. Clicking a segment fires a
callback with the path up to and including that segment, so a file manager can
navigate to any ancestor in one click. Tk 8.6+ and 9.x.

## API

```tcl
::tkutils::tkupath::widget  path ?options?
::tkutils::tkupath::setPath path p     ;# show p as segments
::tkutils::tkupath::getPath path       ;# the currently shown path
```

## Options

- `-onnavigate` script, appended the clicked path -- run when a segment is
  clicked.
- `-rootlabel`  label shown for the root segment (default `/`).

## Use

```tcl
package require tkutils::tkupath

::tkutils::tkupath::widget .bar \
    -onnavigate {apply {p { puts "go $p" }}}
pack .bar -fill x

::tkutils::tkupath::setPath .bar /srv/daten/docs
```

Clicking `daten` shows `/srv/daten` in the bar and then fires the callback with
`/srv/daten`; the caller decides what navigation means (change a directory
listing, re-root a tree). The bar has already updated itself, so the callback
does not need `setPath` -- only a navigation that ends somewhere else (a
redirect, a failed change) calls `setPath` with the real location.

## Windows paths

A drive path shows the drive as the first segment, a UNC path the share;
backslashes count as `/`. The targets are real paths:

| path | segments | targets |
|:--|:--|:--|
| `S:/projekte/daten` | `S:` `projekte` `daten` | `S:/` `S:/projekte` `S:/projekte/daten` |
| `//srv/share/x` | `//srv/share` `x` | `//srv/share/` `//srv/share/x` |

Up to 0.2 the root `/` was put in front of every target (`/S:/projekte`), which
Windows reads as a path on the current drive. Since 0.3.

## See also

`tkufiletree`, `tkufilelist`, `tkutab`
