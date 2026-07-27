# HOWTO: browse a provider in a tree and a list

`tkufiletree` (hierarchy) and `tkufilelist` (one directory's contents) both take
a `-provider`, so the same two widgets browse a local directory, a ZIP, or a
WebDAV collection -- only the provider differs. This recipe wires them together:
click a directory in the tree, see its contents in the list.

## The widgets

```tcl
package require Tk
package require tkutils::tkufiletree
package require tkutils::tkufilelist
package require tclutils::tuprovider

set prov [::tclutils::tuprovider open local]      ;# or: open zip /a.zip
```

## Tree on the left, list on the right

```tcl
ttk::panedwindow .pw -orient horizontal
::tkutils::tkufiletree::widget .pw.tree -provider $prov -root / -files 0 \
    -onselect {apply {p {onDir $p}}}
::tkutils::tkufilelist::widget .pw.list -provider $prov -dir /
.pw add .pw.tree -weight 1
.pw add .pw.list -weight 2
pack .pw -fill both -expand 1

proc onDir {path} {
    # a directory was picked in the tree -> show it in the list
    ::tkutils::tkufilelist::setDir .pw.list $path
}
```

`-files 0` on the tree shows directories only (navigation), while the list shows
files too. Selecting a directory in the tree calls `onDir`, which points the list
at it with `setDir`.

## Same widgets, a different backend

Nothing above mentions the local filesystem. To browse a ZIP instead, change one
line:

```tcl
package require tclutils::tuprovider::zip
set prov [::tclutils::tuprovider open zip /path/archive.zip]
```

The tree and list now walk the archive. That is the point of the provider
abstraction: the widgets never learn what kind of storage they show.

## Reacting to files in the list

```tcl
::tkutils::tkufilelist::widget .pw.list -provider $prov -dir / \
    -onactivate {apply {e {
        if {[dict get $e type] eq "dir"} {
            ::tkutils::tkufilelist::setDir .pw.list [dict get $e path]
        } else {
            puts "open file: [dict get $e path]"
        }
    }}}
```

## See also

- [howto-preview-content.md](howto-preview-content.md)
- [howto-build-file-manager.md](howto-build-file-manager.md)
- Module docs: [`../tkufiletree.md`](../tkufiletree.md),
  [`../tkufilelist.md`](../tkufilelist.md)
- Provider framework: `tclutils` guide `howto-browse-zip.md`
