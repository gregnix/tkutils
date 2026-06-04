# tkutils::tkusearchbar

Search bar: an entry with a debounced change callback, a clear button, and an
optional filter drop-down. Typing fires `-command` after `-delay` ms of
inactivity; clearing and changing the filter fire immediately.

## API

```tcl
set w [::tkutils::tkusearchbar::widget .s ?-command cmd? ?-delay ms? \
        ?-filters list? ?-width n?]
::tkutils::tkusearchbar::getText     $w
::tkutils::tkusearchbar::setText     $w text     ;# programmatic, does not fire
::tkutils::tkusearchbar::clear       $w
::tkutils::tkusearchbar::getFilter   $w
::tkutils::tkusearchbar::setFilter   $w value
::tkutils::tkusearchbar::focusSearch $w
```

`-command` is called as `cmd searchText filterValue` (filter is "" when no
`-filters` were given). Default `-delay` is 300 ms.
