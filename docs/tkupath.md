# tkutils::tkupath

A breadcrumb path bar. Shows a path as a row of clickable segments:
`/home/greg/docs` becomes `[/] [home] [greg] [docs]`. Clicking a segment fires a
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
    -onnavigate {apply {p {::tkutils::tkupath::setPath .bar $p ; puts "go $p"}}}
pack .bar -fill x

::tkutils::tkupath::setPath .bar /home/greg/docs
```

Clicking `greg` fires the callback with `/home/greg`; the caller decides what
navigation means (change a directory listing, re-root a tree) and typically
calls `setPath` again to reflect the new location.

## See also

`tkufiletree`, `tkufilelist`, `tkutab`
