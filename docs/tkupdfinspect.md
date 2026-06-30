# tkutils::tkupdfinspect

Read-only PDF structure inspector widget: a two-pane frame with a structure tree
on the left and a read-only detail pane on the right. The structure is read
through `tclutils::tupdf`; the widget never modifies the file. Pure Tk/ttk;
namespace `::tkutils::tkupdfinspect`.

## API
```tcl
set w [::tkutils::tkupdfinspect::widget .w ?-width N? ?-height N?]  ;# -> frame path
::tkutils::tkupdfinspect::loadFile    $w path   ;# inspect file, fill tree -> path
::tkutils::tkupdfinspect::currentFile $w        ;# last loaded file ("" if none)
::tkutils::tkupdfinspect::summary     $w        ;# cached summary dict from last load
::tkutils::tkupdfinspect::treeWidget  $w        ;# path of the structure tree
::tkutils::tkupdfinspect::textWidget  $w        ;# path of the read-only detail text
```

## Widget options

`widget` returns the frame `$path` it creates (a `ttk::frame` holding a
horizontal `ttk::panedwindow`: structure tree on the left, detail text on the
right). `-width` and `-height` (default `64` x `24`) size the detail text widget
in characters and lines.

## Structure tree

`loadFile` reads the file via `tclutils::tupdf` and populates the tree with the
top-level nodes `Document`, `Metadata`, `Trailer`, `ZUGFeRD`, and
`Objects (N)`, the last expanding to one `obj <id>` child per object. Selecting
a node renders its detail into the right-hand pane. After a load the `Document`
node is selected automatically, so the summary is shown immediately.
`currentFile` returns the loaded path and `summary` returns the summary dict
that was cached during the load, without re-reading the file.

## Read-only and errors

The detail pane is not editable and nothing is ever written back to the file.
For non-PDF input, `tclutils::tupdf` raises `{TCLUTILS TUPDF FORMAT}`;
`loadFile` lets that error surface so the caller can report it.

```tcl
package require tkutils::tkupdfinspect
set w [::tkutils::tkupdfinspect::widget .ins]
pack $w -fill both -expand 1
if {[catch {::tkutils::tkupdfinspect::loadFile $w invoice.pdf} err opts]} {
    if {[lrange [dict get $opts -errorcode] 0 1] eq {TCLUTILS TUPDF}} {
        tk_messageBox -message "Not a readable PDF: $err"
    }
}
```
