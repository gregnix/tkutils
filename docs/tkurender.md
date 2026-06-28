# tkutils::tkurender

Shared render core for the tkudesigner GUI designer and the tkuload spec
loader: a widget catalogue, an in-memory design model, `deserialize`, and a
live ttk render engine. Pure Tk/ttk; namespace `::tkurender`. This is not a
widget -- it is the engine both frontends build on.

## Model
`newModel` starts a fresh design (a single `root` frame). Nodes are added under
a parent and addressed by an opaque id.
```tcl
::tkurender::newModel
set id [::tkurender::addNode type parentId ?record?]   ;# -> node id
::tkurender::deleteNode $id
```
The model lives in the array `::tkurender::D` (keys `root`, `nodes`, `kids`,
`parent`, `wpath,<id>`, `sel`, `embedded`); treat it as engine-owned state.

## Node accessors
```tcl
::tkurender::nodeType   $id
::tkurender::nodeOpt    $id key            ;# widget option value
::tkurender::setOpt     $id key value
::tkurender::nodeName   $id                ;# handle name ("" if unnamed)
::tkurender::setName    $id name
::tkurender::nodeGeom   $id ?key?          ;# grid/pack geometry dict
::tkurender::setGeom    $id key value
::tkurender::nodeLayout $id                ;# child layout: grid|pack|place
::tkurender::setLayout  $id mode
::tkurender::setStretch $id row|col idx weight
```

## Catalogue
```tcl
::tkurender::isContainer $type             ;# 1 if it may hold children
::tkurender::optspecOf   $type             ;# option-editing spec
::tkurender::labelOf     $type             ;# palette label
::tkurender::pkgFor      $type             ;# required package, or ""
::tkurender::pkgAvail    $type             ;# 1 if that package can load
```
Leaf types whose widget lives in another package (e.g. `tkunumentry`,
`tablelist`) report it via `pkgFor`; the renderer substitutes a labelled
placeholder when the package is missing instead of failing.

## Render
```tcl
::tkurender::renderChildren $::tkurender::D(root) $parentW $pv
```
Builds the live widget tree for the model under `$parentW`. Afterwards
`D(wpath,<id>)` maps each node id to its widget path. Selection is decoupled:
the engine binds `<Button-1>` only when `::tkurender::selectCmd` is set -- the
designer sets it, the loader leaves it empty, so loaded UIs carry no editor
bindings.

## Persistence
```tcl
set spec [::tkurender::serialize]          ;# a plain Tcl dict (a .tkd file)
::tkurender::deserialize $spec
```
`deserialize` is forward-compatible: a node missing an option that was added to
the catalogue later silently receives the current default, so older `.tkd`
files keep loading.

## Errors
Carry `{TKUTILS DESIGNER <REASON>}`: `PARENT` (render target missing), `SPEC`
(malformed `.tkd` on deserialize).
