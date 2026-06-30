# tkutils::tkusqlite -- SQLite table browser
# Description: SQLite table browser
# Category: Tk · widgets
#
# Tk front-end that lists the tables of a SQLite database and shows the rows of
# the selected table. Uses the EXTERNAL sqlite3 package (not part of tclutils);
# this widget is therefore optional and is not pulled in by the tkutils umbrella
# package -- load it directly with `package require tkutils::tkusqlite` once
# sqlite3 is available. Tcl/Tk 8.6+ and 9.x compatible (with a matching sqlite3).

package require Tcl 8.6-
package require Tk 8.6-
package require sqlite3

namespace eval ::tkutils {}
namespace eval ::tkutils::tkusqlite {
    namespace export widget openFile tables showTable getRows closeDb
    variable state
}

proc ::tkutils::tkusqlite::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    closeDb $path
    array unset state $path,*
}

proc ::tkutils::tkusqlite::_handle {path} {
    return ::tkutils::tkusqlite::db_[string map {. _ : _} $path]
}

# Build the browser under $path. Option: -height N (visible rows).
proc ::tkutils::tkusqlite::widget {path args} {
    variable state
    array set opts {-height 18}
    array set opts $args

    ttk::frame $path
    set state($path,db) ""
    set state($path,tables) {}
    set state($path,rows) {}
    bind $path <Destroy> [list ::tkutils::tkusqlite::_cleanup $path %W]

    ttk::panedwindow $path.pw -orient horizontal
    # left: table list
    ttk::frame $path.pw.left
    listbox $path.pw.left.lb -height $opts(-height) -exportselection 0 \
        -yscrollcommand [list $path.pw.left.ys set]
    ttk::scrollbar $path.pw.left.ys -orient vertical \
        -command [list $path.pw.left.lb yview]
    grid $path.pw.left.lb $path.pw.left.ys -sticky nsew
    grid rowconfigure $path.pw.left 0 -weight 1
    grid columnconfigure $path.pw.left 0 -weight 1
    # right: rows
    ttk::frame $path.pw.right
    ttk::treeview $path.pw.right.tv -show headings -height $opts(-height)
    ttk::scrollbar $path.pw.right.ys -orient vertical \
        -command [list $path.pw.right.tv yview]
    ttk::scrollbar $path.pw.right.xs -orient horizontal \
        -command [list $path.pw.right.tv xview]
    $path.pw.right.tv configure -yscrollcommand [list $path.pw.right.ys set] \
        -xscrollcommand [list $path.pw.right.xs set]
    grid $path.pw.right.tv $path.pw.right.ys -sticky nsew
    grid $path.pw.right.xs -sticky ew
    grid rowconfigure $path.pw.right 0 -weight 1
    grid columnconfigure $path.pw.right 0 -weight 1

    $path.pw add $path.pw.left
    $path.pw add $path.pw.right
    pack $path.pw -fill both -expand 1

    bind $path.pw.left.lb <<ListboxSelect>> \
        [list ::tkutils::tkusqlite::_onSelect $path]
    return $path
}

proc ::tkutils::tkusqlite::_onSelect {path} {
    set sel [$path.pw.left.lb curselection]
    if {$sel eq ""} return
    showTable $path [$path.pw.left.lb get [lindex $sel 0]]
}

# Open a database file (or ":memory:"). Returns the table count.
proc ::tkutils::tkusqlite::openFile {path dbfile} {
    variable state
    closeDb $path
    set db [_handle $path]
    sqlite3 $db $dbfile
    set state($path,db) $db
    set state($path,tables) [$db eval \
        {SELECT name FROM sqlite_master WHERE type='table' ORDER BY name}]
    $path.pw.left.lb delete 0 end
    foreach t $state($path,tables) { $path.pw.left.lb insert end $t }
    return [llength $state($path,tables)]
}

# Return the list of table names.
proc ::tkutils::tkusqlite::tables {path} {
    variable state
    return $state($path,tables)
}

# Show the rows of $table. Returns the row count.
proc ::tkutils::tkusqlite::showTable {path table} {
    variable state
    set db $state($path,db)
    if {$db eq ""} {
        return -code error -errorcode {TKUTILS TKSQLITE NODB} "no database open"
    }
    set cols [$db eval {SELECT name FROM pragma_table_info($table)}]
    set rows {}
    $db eval "SELECT * FROM \"[string map {\" \"\"} $table]\"" row {
        set vals {}
        foreach c $cols { lappend vals $row($c) }
        lappend rows $vals
    }
    set state($path,rows) $rows

    set tv $path.pw.right.tv
    $tv delete [$tv children {}]
    set ids {}
    for {set i 0} {$i < [llength $cols]} {incr i} { lappend ids c$i }
    $tv configure -columns $ids
    foreach id $ids c $cols {
        $tv heading $id -text $c
        $tv column $id -width 120 -anchor w
    }
    foreach r $rows { $tv insert {} end -values $r }
    return [llength $rows]
}

# Return the rows of the table shown last (list of value lists).
proc ::tkutils::tkusqlite::getRows {path} {
    variable state
    return $state($path,rows)
}

proc ::tkutils::tkusqlite::closeDb {path} {
    variable state
    if {[info exists state($path,db)] && $state($path,db) ne ""} {
        catch {$state($path,db) close}
        set state($path,db) ""
    }
    return
}

package provide tkutils::tkusqlite 0.1
