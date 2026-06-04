# tkutils::tkdavbrowser

A read-only navigation pane for a CalDAV/CardDAV server, built on
`tclutils::tudav`. It lists the server's collections grouped by kind
(Calendars / Address Books / Other) in a `ttk::treeview`; selecting a collection
fires `-oncollection` so an app can load its contents into `tkvcard` / `tktodo`.

```tcl
set b [tkdavbrowser::widget .b -oncollection {apply {{w info} {
    # info = {href .. displayname .. kind ..}
    puts "open [dict get $info kind]: [dict get $info href]"
}}}]
pack $b -fill both -expand 1

tkdavbrowser::setClient .b $davClient   ;# a tclutils::tudav client
tkdavbrowser::refresh .b                ;# discover + listCollections (network)

tkdavbrowser::collections .b            ;# flat list of {href displayname kind}
tkdavbrowser::selected .b               ;# current selection dict, or {}
```

`refresh` runs `tudav::discover` then `listCollections` on both home sets,
de-duplicating by href (Radicale, for instance, uses one home set for both
kinds). It is **synchronous** and may block briefly. For offline rendering or
testing, `setData $path $collections` accepts a ready list of
`{href displayname kind}` dicts and builds the tree without any network I/O.

## Provisioning (opt-in)

With `-editable 1` the widget adds a small bar to create and delete collections:

```tcl
tkdavbrowser::createCalendar    .b "Sprint Board"   ;# -> new path, then refresh
tkdavbrowser::createAddressbook .b "Team"
tkdavbrowser::deleteCollection  .b ?href?           ;# selected if href omitted
```

New collections are created under the discovered home set (path = home +
slug-of-name + `/`) via `tudav::mkCalendar` / `mkAddressbook`; `deleteCollection`
uses `tudav::delete`. All three refresh the tree afterwards and are network
operations (call `refresh` once first so the home set is known, else
`{TKUTILS TKDAVBROWSER NOHOME}`).

Pairs with `tkdavaccount` (connect) on one side and `tkvcard` / `tktodo`
(content) on the other.
