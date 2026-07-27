# HOWTO: build a file manager on the provider abstraction

This recipe assembles the whole Explorer framework: the `tkutils` widgets for the
view, a `tclutils` provider for the storage, and the `ctrlutils` controllers for
the behavior. The result browses any backend (local, ZIP, WebDAV), previews
files, and does capability-driven file operations -- without any of the pieces
knowing about the others beyond the provider interface.

## The three layers

    tclutils  tuprovider          the storage (Model)
    tkutils   tkufiletree/list/   the widgets (View)
              path/preview/tab
    ctrlutils cufileops/monitor/  the behavior (Controller)
              filter

## Skeleton

```tcl
package require Tk
package require tclutils::tuprovider
package require tkutils::tkufiletree
package require tkutils::tkufilelist
package require tkutils::tkupath
package require tkutils::tkupreview
package require ctrlutils

set prov [::tclutils::tuprovider open local]
set dir  [pwd]
```

## Layout: breadcrumb, tree, list, preview

```tcl
::tkutils::tkupath::widget .path -onnavigate {apply {p {goto $p}}}
pack .path -side top -fill x

ttk::panedwindow .pw -orient horizontal
::tkutils::tkufiletree::widget .pw.tree -provider $prov -root / -files 0 \
    -onselect {apply {p {goto $p}}}
ttk::frame .pw.mid
::tkutils::tkufilelist::widget .pw.mid.list -provider $prov -dir $dir \
    -onselect   {apply {e {onSelect $e}}} \
    -onactivate {apply {e {onActivate $e}}}
::tkutils::tkupreview::widget .pw.prev

.pw add .pw.tree -weight 1
.pw add .pw.mid  -weight 2
.pw add .pw.prev -weight 3
pack .pw.mid.list -fill both -expand 1
pack .pw -fill both -expand 1
```

## Navigation

```tcl
proc goto {d} {
    ::tkutils::tkufilelist::setDir .pw.mid.list $d
    ::tkutils::tkupath::setPath .path $d
    catch {::tkutils::tkufiletree::reveal .pw.tree $d}
}
proc onActivate {e} {
    if {[dict get $e type] eq "dir"} { goto [dict get $e path] }
}
proc onSelect {e} {
    if {[dict get $e type] eq "file"} {
        # map type -> preview kind here (see howto-preview-content.md)
        set text [encoding convertfrom utf-8 [$::prov get [dict get $e path]]]
        ::tkutils::tkupreview::text .pw.prev [dict get $e name] $text
    }
}
goto $dir
```

## Add behavior with the controllers

The controllers wire behavior onto the list you already built:

```tcl
# right-click file operations (New/Rename/Delete/Copy/Paste), capability-driven
::ctrlutils::cufileops::install main $prov .pw.mid.list {apply {{} {goto $::curdir}}}

# reload the list when the directory changes underneath us
::ctrlutils::cumonitor::install main $prov -interval 2000 \
    -onchange {apply {d {goto $d}}}

# a live filter box above the list
::ctrlutils::cufilter::widget .filter .pw.mid.list
pack .filter -side top -fill x -before .pw
```

`cufileops` reads the provider's `caps`, so a read-only backend (a ZIP) offers no
writing operations -- the menu never shows something that would fail. Copy/Paste
runs `get`+`put` at the app level, so it works **across** providers.

## Tabs and multiple providers

Give each tab its own provider (via `tkutab`) and Copy/Paste works between a ZIP
tab and a local tab, because `cufileops`'s clipboard remembers the source
provider:

```tcl
package require tkutils::tkutab
::tkutils::tkutab::widget .tabs -onnew {apply {{} {newTab [pwd]}}}
# each newTab builds its own tree/list/preview + provider in the tab frame,
# and installs its own cufileops/cumonitor/cufilter (keyed by the tab frame).
```

## What each layer contributes

- **Provider** (tclutils): where the bytes are. Swap it to browse a ZIP or WebDAV
  with no widget change.
- **Widgets** (tkutils): how it looks. Policy-free -- they show what they are
  handed and report selections.
- **Controllers** (ctrlutils): how it behaves. File ops, watching, filtering --
  wired onto the widgets, driven by the provider's caps.

Because the seams are the provider interface and the callbacks, you can replace
any one layer without touching the others.

## See also

- [howto-browse-provider.md](howto-browse-provider.md)
- [howto-preview-content.md](howto-preview-content.md)
- Provider framework guide in `tclutils` (`howto-provider-backend.md`,
  `howto-cross-provider-copy.md`)
- The `ctrlutils` repo README (controller layer)
