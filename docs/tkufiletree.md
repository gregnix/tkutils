# tkutils::tkufiletree

A lazy file-system tree built on `tkutils::tkutree`. Shows a directory
hierarchy under a root; subdirectories are read from disk only when expanded
(no full walk). Files can be filtered by glob patterns, and activating a file
fires a callback with its full path. Tk 8.6+ and 9.x.

## API

```tcl
::tkutils::tkufiletree::widget       path ?options?
::tkutils::tkufiletree::setRoot      path dir
::tkutils::tkufiletree::refresh      path
::tkutils::tkufiletree::refreshDir   path dir     ;# re-populate one already-open node
::tkutils::tkufiletree::up           path        ;# re-root to parent dir
::tkutils::tkufiletree::selectedPath path        ;# full path or ""
::tkutils::tkufiletree::root         path        ;# current root dir or ""
::tkutils::tkufiletree::reveal       path target  ;# expand+select a path
::tkutils::tkufiletree::treeview     path        ;# raw ttk::treeview
```

`reveal` expands the directory chain down to `target` (a path under the root),
selects it and scrolls it into view, populating ancestors as needed. If the
exact target is not a node (e.g. excluded by the filter), the deepest existing
ancestor — its folder — is selected instead. It returns 1 when the exact target
was selected, else 0, and never raises. Together with `root` and `setRoot` this
lets a host application keep the tree pointing at — and highlighting — whatever
it just opened elsewhere. `up` re-roots to the parent directory (also bound to
`BackSpace`) and reveals the previous root.

`refreshDir` re-reads a single directory node that is already present in the
tree and re-populates its children (trying both `$dir` and its normalized form),
leaving it open. Use it after the contents of one directory change on disk --
e.g. a paste that creates a new subfolder -- so the new child appears as a
navigable node without rebuilding the whole tree. It returns 1 if the node
existed and was refreshed, 0 otherwise, and never raises. `refresh` (no dir)
rebuilds from the root instead.

### Options (widget)

- `-root dir` — starting directory (default: current directory).
- `-filter {pat ...}` — glob patterns; only matching files are shown
  (directories are always shown). Empty = all files. Case-insensitive.
- `-files 0|1` — show files at all (default 1; 0 = directories only).
- `-showhidden 0|1` — include dot-entries (default 0).
- `-onactivate cmd` — called with the full path when a file is activated
  (double-click or Return).
- `-onselect cmd` — called with the full path on selection change.
- `-height n` — visible rows (default 16).
- `-isolatekeys 0|1` — when 1, drop the toplevel from the tree's bindtags so a
  host application's global key bindings do not also fire while the tree has
  focus (default 0). Keyboard navigation, expand/collapse and `BackSpace`
  (go up) stay local to the tree.

Item ids are the normalized full paths, so `selectedPath` and the callbacks
hand back ready-to-use paths.

## Example

```tcl
package require tkutils::tkufiletree
set t [::tkutils::tkufiletree::widget .t \
          -root [pwd] -filter {*.png *.jpg *.gif *.bmp} \
          -onactivate {apply {p {puts "open: $p"}}}]
pack $t -fill both -expand 1
```

## Demo

```bash
tclsh examples/demo-tkufiletree.tcl ?startdir?
```
