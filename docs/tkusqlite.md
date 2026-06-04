# tkutils::tkusqlite

SQLite table browser. Lists the tables of a database on the left and shows the
rows of the selected table on the right.

> Optional widget. The **sqlite3** package is an external dependency and is *not*
> part of tclutils, so tkusqlite is not loaded by the tkutils umbrella. Ensure
> sqlite3 is installed, then `package require tkutils::tkusqlite`.

## API
```tcl
set w [::tkutils::tkusqlite::widget .w ?-height N?]
::tkutils::tkusqlite::openFile  $w dbfile     ;# ":memory:" allowed; returns table count
::tkutils::tkusqlite::tables    $w
::tkutils::tkusqlite::showTable $w tablename  ;# returns row count
::tkutils::tkusqlite::getRows   $w
::tkutils::tkusqlite::closeDb   $w
```

## Launcher
```bash
tclsh bin/tkusqlite.tcl database.db
```
