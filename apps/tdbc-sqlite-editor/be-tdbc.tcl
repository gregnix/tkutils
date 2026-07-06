# be-tdbc.tcl -- SQLite-over-TDBC backend for the shared sqledit core.
#
# Implements the same ::sqledit::be::* contract as be-sqlite.tcl, but talks to
# SQLite through tdbc::sqlite3 instead of the bare `sqlite3` command. It is
# self-contained (no dependency on tdbutils): the two well-known TDBC pitfalls
# are handled here directly --
#
#   Macke 1: `allrows -as dicts` drops NULL columns from the row dict.
#            -> result grids are built from `$rs columns` + `$rs nextlist`,
#               which keep every column (NULL as empty string).
#   Macke 2: a bind dict missing a key binds SQL NULL for that column.
#            -> that is exactly what the form view wants for INSERT/UPDATE,
#               so execParams passes the params dict straight through.
#
# The `db` handle passed around by the core is a tdbc::sqlite3 connection
# object. Mirrors be-sqlite.tcl one-to-one so the shared GUI is reused unchanged.

package require Tcl 8.6-

namespace eval ::sqledit::be {
    variable categories {table view index trigger sequence}
}

# Identity + dependency check ------------------------------------------------
proc ::sqledit::be::displayName {}      { return "SQLite (TDBC)" }
proc ::sqledit::be::connectLabel {}     { return "Open" }
proc ::sqledit::be::connectNewLabel {}  { return "New" }
proc ::sqledit::be::requireDeps {} {
    if {[catch {package require tdbc::sqlite3} err]} {
        error "This editor needs the tdbc::sqlite3 package.\n$err"
    }
}

# Interactive connect (file based) -------------------------------------------
proc ::sqledit::be::connect {parent} {
    return [tk_getOpenFile -parent $parent -title "Open SQLite database (TDBC)" \
        -filetypes {{SQLite {.db .sqlite .sqlite3}} {All *}}]
}
proc ::sqledit::be::connectNew {parent} {
    return [tk_getSaveFile -parent $parent -title "New SQLite database (TDBC)" \
        -defaultextension .db \
        -filetypes {{SQLite {.db .sqlite .sqlite3}} {All *}}]
}
proc ::sqledit::be::label {target} {
    if {$target eq "" || $target eq ":memory:"} { return ":memory:" }
    return [file tail $target]
}

# Connection lifecycle -------------------------------------------------------
proc ::sqledit::be::open {target} {
    package require tdbc::sqlite3
    catch {::sqledit::dbconn close}
    if {$target eq ""} { set target ":memory:" }
    tdbc::sqlite3::connection create ::sqledit::dbconn $target
    catch {::sqledit::dbconn allrows {PRAGMA foreign_keys = ON}}
    return ::sqledit::dbconn
}
proc ::sqledit::be::close {db} { catch {$db close} }

# Run one statement -> {columns rows changes capped} ------------------------
# NULL-safe: uses prepare/execute/columns + nextlist, never `allrows -as dicts`.
# `$rs columns` yields the result header even for an empty SELECT (mirrors the
# sqlite3 A(*) fallback in be-sqlite.tcl); it stays empty for DML/DDL.
proc ::sqledit::be::run {db sql {max 0}} {
    set cols {}; set rows {}; set changes 0; set capped 0
    set stmt [$db prepare $sql]
    try {
        set rs [$stmt execute]
        try {
            set cols [$rs columns]
            set nn 0
            while {[$rs nextlist row]} {
                lappend rows $row
                if {$max > 0 && [incr nn] >= $max} { set capped 1; break }
            }
            catch {set changes [$rs rowcount]}
            if {![string is integer -strict $changes] || $changes < 0} { set changes 0 }
        } finally {
            catch {$rs close}
        }
    } finally {
        catch {$stmt close}
    }
    return [dict create columns $cols rows $rows changes $changes capped $capped]
}

# Parameterized DML: $params is a dict name->value, referenced as :name in the
# SQL. Returns the number of affected rows. Values are bound (injection-safe).
# A key absent from $params binds SQL NULL for that column (TDBC Macke 2) --
# the intended behaviour for the form view's INSERT/UPDATE/DELETE.
proc ::sqledit::be::execParams {db sql params} {
    set n 0
    set stmt [$db prepare $sql]
    try {
        set rs [$stmt execute $params]
        catch {set n [$rs rowcount]}
        catch {$rs close}
    } finally {
        catch {$stmt close}
    }
    if {![string is integer -strict $n] || $n < 0} { set n 0 }
    return $n
}

# --- small NULL-safe helpers ------------------------------------------------
# First column of every row as a flat list (uses -as lists: NULL -> "").
proc ::sqledit::be::_col0 {db sql {binds {}}} {
    set out {}
    foreach r [$db allrows -as lists $sql $binds] { lappend out [lindex $r 0] }
    return $out
}
# dict get with empty-string default (guards against a NULL key being absent).
proc ::sqledit::be::_dg {d k} {
    return [expr {[dict exists $d $k] ? [dict get $d $k] : ""}]
}

# Object categories the browser shows ----------------------------------------
proc ::sqledit::be::categories {} {
    return {table Tables view Views index Indexes trigger Triggers
            sequence Sequences}
}

# Names of objects of a given category --------------------------------------
proc ::sqledit::be::objects {db type} {
    switch -- $type {
        table - view - trigger {
            return [_col0 $db {SELECT name FROM sqlite_master
                WHERE type=:type AND name NOT LIKE 'sqlite_%' ORDER BY name} \
                [dict create type $type]]
        }
        index {
            return [_col0 $db {SELECT name FROM sqlite_master
                WHERE type='index' AND sql IS NOT NULL ORDER BY name}]
        }
        sequence {
            if {![llength [_col0 $db {SELECT name FROM sqlite_master
                    WHERE type='table' AND name='sqlite_sequence'}]]} { return {} }
            return [_col0 $db {SELECT name FROM sqlite_sequence ORDER BY name}]
        }
    }
    return {}
}

# CREATE text for a named object ("" if none / virtual) ----------------------
proc ::sqledit::be::schemaOf {db name} {
    return [lindex [_col0 $db {SELECT sql FROM sqlite_master WHERE name=:name} \
        [dict create name $name]] 0]
}

# Column metadata -> list of dicts {name type notnull pk dflt} ---------------
# PRAGMA does not bind its argument, so the name is quoted-substituted.
proc ::sqledit::be::columns {db name} {
    set out {}
    set q "PRAGMA table_info('[string map {' ''} $name]')"
    foreach c [$db allrows -as dicts $q] {
        lappend out [dict create \
            name    [_dg $c name] \
            type    [_dg $c type] \
            notnull [_dg $c notnull] \
            pk      [_dg $c pk] \
            dflt    [_dg $c dflt_value]]
    }
    return $out
}

# Foreign keys of a table -> list of dicts {column refTable refColumn} --------
proc ::sqledit::be::foreignKeys {db name} {
    set out {}
    set q "PRAGMA foreign_key_list('[string map {' ''} $name]')"
    foreach c [$db allrows -as dicts $q] {
        lappend out [dict create \
            column    [_dg $c from] \
            refTable  [_dg $c table] \
            refColumn [_dg $c to]]
    }
    return $out
}

# Full schema as a runnable .sql script --------------------------------------
proc ::sqledit::be::schemaDump {db} {
    set parts {}
    foreach r [$db allrows -as lists {SELECT sql FROM sqlite_master
        WHERE sql IS NOT NULL
        ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'view' THEN 1
                           WHEN 'index' THEN 2 ELSE 3 END, name}] {
        lappend parts "[lindex $r 0];"
    }
    return [join $parts "\n\n"]
}

# Preview SELECT with the backend's row-limit syntax -------------------------
proc ::sqledit::be::previewSql {name limit} {
    set n [string map {\" \"\"} $name]
    return "SELECT * FROM \"$n\" LIMIT $limit;"
}

# Database-wide summary (self-contained) -------------------------------------
proc ::sqledit::be::summary {db} {
    set file ""
    foreach r [$db allrows -as dicts {PRAGMA database_list}] {
        if {[_dg $r name] eq "main"} { set file [_dg $r file] }
    }
    set d [dict create file $file \
        version  [lindex [_col0 $db {SELECT sqlite_version()}] 0] \
        encoding [lindex [_col0 $db {PRAGMA encoding}] 0] \
        pages    [lindex [_col0 $db {PRAGMA page_count}] 0] \
        pagesize [lindex [_col0 $db {PRAGMA page_size}] 0]]
    foreach t {table view index trigger sequence} {
        dict set d count_$t [llength [objects $db $t]]
    }
    return $d
}
proc ::sqledit::be::summaryText {db} {
    set d [summary $db]
    set f [dict get $d file]; if {$f eq ""} { set f "(in-memory)" }
    set t "Database: $f  (via tdbc::sqlite3)\n"
    append t "SQLite version: [dict get $d version]\n"
    append t "Encoding: [dict get $d encoding]\n"
    set sz [expr {[dict get $d pages]*[dict get $d pagesize]}]
    append t "Size: $sz bytes ([dict get $d pages] pages x [dict get $d pagesize])\n\n"
    append t "Tables: [dict get $d count_table]   Views: [dict get $d count_view]\n"
    append t "Indexes: [dict get $d count_index]   Triggers: [dict get $d count_trigger]"
    append t "   Sequences: [dict get $d count_sequence]"
    return $t
}
