# tkutils::tkutree

A thin `ttk::treeview` wrapper for hierarchical data: build a tree (optional
data columns and a scrollbar), insert nodes, load a nested structure in one
call, and read selection / text / values back.

## API

```tcl
set w [::tkutils::tkutree::widget .tr ?-columns ids? ?-headings texts? \
        ?-show spec? ?-height n? ?-command cmd?]
::tkutils::tkutree::insert    $w parent text ?-values list? ?-open bool? ?-id id?
::tkutils::tkutree::loadTree  $w nodes
::tkutils::tkutree::selection $w
::tkutils::tkutree::itemText  $w id
::tkutils::tkutree::children  $w ?id?
::tkutils::tkutree::treeview  $w        ;# the underlying ttk::treeview
```

`loadTree` takes a list of node dicts; keys per node: `text` (required),
`values`, `open`, `id`, `children` (a list of nodes). `-command` is called with
the selection list on `<<TreeviewSelect>>`.
