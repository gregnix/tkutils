# tkutils::tkugeometry

Remember a toplevel's size, position and zoom state between runs. Stored per
app through `tclutils::tusettings` in its own file
(`<config dir>/<app>/geometry.ini`), so an app that saves its own settings
dict at exit cannot overwrite it. Pure Tk + tclutils, Tcl/Tk 8.6+ / 9.x.

## Commands

```tcl
::tkutils::tkugeometry::track   w app ?-key k? ?-default geo?  ;# restore now, save on destroy
::tkutils::tkugeometry::restore w app ?-key k? ?-default geo?  ;# -> geometry applied, "" if none
::tkutils::tkugeometry::save    w app ?-key k?                 ;# -> geometry stored
::tkutils::tkugeometry::key     w                              ;# "." -> main, ".dlg" -> dlg
```

```tcl
tkugeometry::track . etikettendruck -default 900x650
tkugeometry::track .vorschau etikettendruck
```

`track` puts an own bindtag in front of the window's bindtags, so the app's
`<Destroy>` bindings stay as they are. `-default` (a size such as `800x600`
or a full geometry) is used when nothing is stored yet.

## Kept on the screen

A stored position that is no longer on the screen -- the second monitor is
gone, the resolution shrank -- is not used: the window keeps its size, shrunk
to the screen if needed, and is centred. "On the screen" means the top strip
of the window (title bar region) lies within Tk's virtual root: on X11 all
monitors as one rectangle, on Windows the virtual desktop. A gap between
monitors of different size is not seen.

The zoom state is stored as `zoomed` and restored where Tk has it
(`wm state zoomed` on Windows/macOS, `wm attributes -zoomed` on X11).

## Errors

`{TKUTILS TKUGEOMETRY WINDOW}` (not an existing toplevel); bad app names and
unreadable files raise the `tusettings` errors.
