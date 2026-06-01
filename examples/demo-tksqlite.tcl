#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
# locate the tclutils dependency for in-tree/dev use
# (installed systems already have tclutils on the module path)
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
package require tkutils::tksqlite
package require sqlite3
wm title . "tksqlite demo"
set w [::tkutils::tksqlite::widget .w]
pack $w -fill both -expand 1
# build a small demo database in a temp file
close [file tempfile dbfile]
file delete $dbfile
sqlite3 seed $dbfile
seed eval {CREATE TABLE people(id INTEGER, name TEXT, city TEXT)}
seed eval {INSERT INTO people VALUES(1,'Greg','Vreden'),(2,'Ada','London'),(3,'Bob','Berlin')}
seed eval {CREATE TABLE tags(name TEXT)}
seed close
::tkutils::tksqlite::openFile $w $dbfile
vwait forever
