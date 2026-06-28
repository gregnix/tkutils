# be-sqlite.tcl -- SQLite backend for the shared sqledit core.
#
# Implements the ::sqledit::be::* contract that sqledit-core.tcl talks to:
#   displayName / requireDeps / connect ?connectNew? / label / open / close /
#   run / objects / categories / columns / schemaOf / schemaDump /
#   summary / summaryText / previewSql / execParams / foreignKeys
# Mirror this file for PostgreSQL (tdbc::postgres) and Oracle (Oratcl).
#
# Uses the bare `sqlite3` command (not tdbc), so it has no extra dependency.

package require Tcl 8.6-

namespace eval ::sqledit::be {
    variable categories {table view index trigger sequence}
}

# Identity + dependency check ------------------------------------------------
proc ::sqledit::be::displayName {}      { return "SQLite" }
proc ::sqledit::be::connectLabel {}     { return "Open" }
proc ::sqledit::be::connectNewLabel {}  { return "New" }
proc ::sqledit::be::requireDeps {} {
    if {[catch {package require sqlite3} err]} {
        error "This editor needs the sqlite3 package.\n$err"
    }
}

# Interactive connect (file based) -------------------------------------------
proc ::sqledit::be::connect {parent} {
    return [tk_getOpenFile -parent $parent -title "Open SQLite database" \
        -filetypes {{SQLite {.db .sqlite .sqlite3}} {All *}}]
}
proc ::sqledit::be::connectNew {parent} {
    return [tk_getSaveFile -parent $parent -title "New SQLite database" \
        -defaultextension .db \
        -filetypes {{SQLite {.db .sqlite .sqlite3}} {All *}}]
}
proc ::sqledit::be::label {target} {
    if {$target eq "" || $target eq ":memory:"} { return ":memory:" }
    return [file tail $target]
}

# Connection lifecycle -------------------------------------------------------
proc ::sqledit::be::open {target} {
    package require sqlite3
    catch {::sqledit::dbcmd close}
    sqlite3 ::sqledit::dbcmd $target
    return ::sqledit::dbcmd
}
proc ::sqledit::be::close {db} { catch {$db close} }

# Run one statement -> {columns rows changes} -------------------------------
proc ::sqledit::be::run {db sql {max 0}} {
    set cols {}; set rows {}; set nn 0; set capped 0
    $db eval $sql A {
        if {![llength $cols]} { foreach c $A(*) { lappend cols $c } }
        set row {}
        foreach c $cols { lappend row $A($c) }
        lappend rows $row
        if {$max > 0 && [incr nn] >= $max} { set capped 1; break }
    }
    # A SELECT that matches no rows never enters the loop body, yet sqlite3
    # still populates A(*) with the result column names (it stays empty for
    # DML/DDL). Fall back to it so an empty result set keeps its headers.
    if {![llength $cols] && [info exists A(*)]} { set cols $A(*) }
    return [dict create columns $cols rows $rows changes [$db changes] capped $capped]
}

# Parameterized DML: $params is a dict name->value, referenced as :name in the
# SQL. Returns the number of affected rows. Safe against injection (values are
# bound, not spliced). Used by the form view for INSERT/UPDATE/DELETE.
proc ::sqledit::be::execParams {db sql params} {
    # Bind in an isolated scope so the loop/arg names cannot collide with a
    # parameter (e.g. a param literally named "v" or "db"). The mangled names
    # below are not realistic column/param names.
    return [apply {{__db __sql __params} {
        dict for {__k __v} $__params { ::set $__k $__v }
        $__db eval $__sql
        return [$__db changes]
    }} $db $sql $params]
}

# Object categories the browser shows: {type label ...} ----------------------
proc ::sqledit::be::categories {} {
    return {table Tables view Views index Indexes trigger Triggers
            sequence Sequences}
}

# Names of objects of a given category --------------------------------------
proc ::sqledit::be::objects {db type} {
    switch -- $type {
        table - view - trigger {
            return [$db eval {SELECT name FROM sqlite_master
                WHERE type=$type AND name NOT LIKE 'sqlite_%' ORDER BY name}]
        }
        index {
            return [$db eval {SELECT name FROM sqlite_master
                WHERE type='index' AND sql IS NOT NULL ORDER BY name}]
        }
        sequence {
            if {![llength [$db eval {SELECT name FROM sqlite_master
                    WHERE type='table' AND name='sqlite_sequence'}]]} { return {} }
            return [$db eval {SELECT name FROM sqlite_sequence ORDER BY name}]
        }
    }
    return {}
}

# CREATE text for a named object ("" if none / virtual) ----------------------
proc ::sqledit::be::schemaOf {db name} {
    return [lindex [$db eval {SELECT sql FROM sqlite_master WHERE name=$name}] 0]
}

# Column metadata -> list of dicts {name type notnull pk dflt} ---------------
proc ::sqledit::be::columns {db name} {
    set out {}
    $db eval "PRAGMA table_info('[string map {' ''} $name]')" c {
        lappend out [dict create name $c(name) type $c(type) \
            notnull $c(notnull) pk $c(pk) dflt $c(dflt_value)]
    }
    return $out
}

# Foreign keys of a table -> list of dicts {column refTable refColumn} --------
proc ::sqledit::be::foreignKeys {db name} {
    set out {}
    $db eval "PRAGMA foreign_key_list('[string map {' ''} $name]')" c {
        lappend out [dict create column $c(from) refTable $c(table) refColumn $c(to)]
    }
    return $out
}

# Full schema as a runnable .sql script --------------------------------------
proc ::sqledit::be::schemaDump {db} {
    set parts {}
    $db eval {SELECT sql FROM sqlite_master
        WHERE sql IS NOT NULL
        ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'view' THEN 1
                           WHEN 'index' THEN 2 ELSE 3 END, name} r {
        lappend parts "$r(sql);"
    }
    return [join $parts "\n\n"]
}

# Preview SELECT with the backend's row-limit syntax -------------------------
proc ::sqledit::be::previewSql {name limit} {
    set n [string map {\" \"\"} $name]
    return "SELECT * FROM \"$n\" LIMIT $limit;"
}

# Database-wide summary (self-contained) -------------------------------------
# Named `summary` (not `info`) to avoid shadowing the Tcl `info` builtin.
proc ::sqledit::be::summary {db} {
    set file ""
    $db eval {PRAGMA database_list} r {
        if {$r(name) eq "main"} { set file $r(file) }
    }
    set d [dict create file $file \
        version  [lindex [$db eval {SELECT sqlite_version()}] 0] \
        encoding [lindex [$db eval {PRAGMA encoding}] 0] \
        pages    [lindex [$db eval {PRAGMA page_count}] 0] \
        pagesize [lindex [$db eval {PRAGMA page_size}] 0]]
    foreach t {table view index trigger sequence} {
        dict set d count_$t [llength [objects $db $t]]
    }
    return $d
}
proc ::sqledit::be::summaryText {db} {
    set d [summary $db]
    set f [dict get $d file]; if {$f eq ""} { set f "(in-memory)" }
    set t "Database: $f\n"
    append t "SQLite version: [dict get $d version]\n"
    append t "Encoding: [dict get $d encoding]\n"
    set sz [expr {[dict get $d pages]*[dict get $d pagesize]}]
    append t "Size: $sz bytes ([dict get $d pages] pages x [dict get $d pagesize])\n\n"
    append t "Tables: [dict get $d count_table]   Views: [dict get $d count_view]\n"
    append t "Indexes: [dict get $d count_index]   Triggers: [dict get $d count_trigger]"
    append t "   Sequences: [dict get $d count_sequence]"
    return $t
}
