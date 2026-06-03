# tkutils::tksearchbar

Search bar: an entry with a debounced change callback, a clear button, and an
optional filter drop-down. Typing fires `-command` after `-delay` ms of
inactivity; clearing and changing the filter fire immediately.

## API

```tcl
set w [::tkutils::tksearchbar::widget .s ?-command cmd? ?-delay ms? \
        ?-filters list? ?-width n?]
::tkutils::tksearchbar::getText     $w
::tkutils::tksearchbar::setText     $w text     ;# programmatic, does not fire
::tkutils::tksearchbar::clear       $w
::tkutils::tksearchbar::getFilter   $w
::tkutils::tksearchbar::setFilter   $w value
::tkutils::tksearchbar::focusSearch $w
```

`-command` is called as `cmd searchText filterValue` (filter is "" when no
`-filters` were given). Default `-delay` is 300 ms.
