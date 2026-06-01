# tkutils::tksqlite

SQLite table browser. Lists the tables of a database on the left and shows the
rows of the selected table on the right.

> Optional widget. The **sqlite3** package is an external dependency and is *not*
> part of tclutils, so tksqlite is not loaded by the tkutils umbrella. Ensure
> sqlite3 is installed, then `package require tkutils::tksqlite`.

## API
```tcl
set w [::tkutils::tksqlite::widget .w ?-height N?]
::tkutils::tksqlite::openFile  $w dbfile     ;# ":memory:" allowed; returns table count
::tkutils::tksqlite::tables    $w
::tkutils::tksqlite::showTable $w tablename  ;# returns row count
::tkutils::tksqlite::getRows   $w
::tkutils::tksqlite::closeDb   $w
```

## Launcher
```bash
tclsh bin/tksqlite.tcl database.db
```
