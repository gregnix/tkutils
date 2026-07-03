# be-postgres.tcl -- PostgreSQL backend for the shared sqledit core.
#
# Implements the same ::sqledit::be::* contract as be-sqlite.tcl, but over
# tdbc::postgres (direct SQL, like a small DBeaver -- not PostgREST; the REST
# client tclutils::tupostgrest is for the application layer, not for a SQL
# editor). The whole GUI (sqledit-core/form/sheet) is shared unchanged.
#
# A "target" here is a connection dict {host port db user password}; the core
# passes it around opaquely (connect -> open -> label).

package require Tcl 8.6-

namespace eval ::sqledit::be {
    variable categories {table view index sequence trigger function}
    variable _conn      ;# connection-object -> target dict (for the psql fallback)
    array set _conn {}
}

# Identity + dependency check ------------------------------------------------
proc ::sqledit::be::displayName {}     { return "PostgreSQL" }
proc ::sqledit::be::connectLabel {}    { return "Connect..." }
# no connectNew: PostgreSQL has no "new database file"; the New button is hidden.

proc ::sqledit::be::requireDeps {} {
    if {[catch {package require tdbc::postgres} err]} {
        error "This editor needs the tdbc::postgres package.\n$err"
    }
}

# Interactive connect: a small modal dialog -> connection dict or "" ----------
proc ::sqledit::be::connect {parent} {
    return [_connectDialog $parent]
}
proc ::sqledit::be::label {target} {
    if {$target eq ""} { return "(none)" }
    set host [_dg $target host localhost]
    set port [_dg $target port 5432]
    set db   [_dg $target db ""]
    return "$db@$host:$port"
}
proc ::sqledit::be::_dg {d k {def ""}} {
    return [expr {[dict exists $d $k] ? [dict get $d $k] : $def}]
}

# Connection lifecycle -------------------------------------------------------
proc ::sqledit::be::open {target} {
    variable _conn
    package require tdbc::postgres
    set args [list -host [_dg $target host localhost] \
                   -port [_dg $target port 5432] \
                   -database [_dg $target db ""] \
                   -user [_dg $target user ""]]
    set pw [_dg $target password ""]
    if {$pw ne ""} { lappend args -password $pw }
    set conn [tdbc::postgres::connection new {*}$args]
    set _conn($conn) $target
    return $conn
}
proc ::sqledit::be::close {db} {
    variable _conn
    unset -nocomplain _conn($db)
    catch {$db close}
}

# Split a SQL script into individual statements on `;`, but respect the
# contexts where a semicolon is NOT a separator: '...' strings, "..." quoted
# identifiers, $tag$...$tag$ dollar-quoted bodies (function sources!), -- line
# comments and /* ... */ (nesting) block comments. tdbc::postgres rejects a
# trailing/embedded ';', so the editor must hand it one statement at a time.
proc ::sqledit::be::_splitStatements {sql} {
    set stmts {}; set cur ""; set n [string length $sql]; set i 0
    while {$i < $n} {
        set ch [string index $sql $i]
        if {$ch eq "-" && [string index $sql $i+1] eq "-"} {
            set eol [string first "\n" $sql $i]
            if {$eol < 0} { append cur [string range $sql $i end]; break }
            append cur [string range $sql $i $eol]; set i [expr {$eol+1}]; continue
        }
        if {$ch eq "/" && [string index $sql $i+1] eq "*"} {
            set depth 1; append cur "/*"; incr i 2
            while {$i < $n && $depth > 0} {
                if {[string index $sql $i] eq "/" && [string index $sql $i+1] eq "*"} {
                    incr depth; append cur "/*"; incr i 2; continue }
                if {[string index $sql $i] eq "*" && [string index $sql $i+1] eq "/"} {
                    incr depth -1; append cur "*/"; incr i 2; continue }
                append cur [string index $sql $i]; incr i
            }
            continue
        }
        if {$ch eq "'" || $ch eq "\""} {
            append cur $ch; incr i
            while {$i < $n} {
                set c2 [string index $sql $i]; append cur $c2; incr i
                if {$c2 eq $ch} {
                    if {[string index $sql $i] eq $ch} { append cur $ch; incr i; continue }
                    break
                }
            }
            continue
        }
        if {$ch eq "\$"} {
            if {[regexp {^\$[A-Za-z0-9_]*\$} [string range $sql $i end] tag]} {
                append cur $tag; incr i [string length $tag]
                set close [string first $tag $sql $i]
                if {$close < 0} { append cur [string range $sql $i end]; set i $n; continue }
                append cur [string range $sql $i [expr {$close + [string length $tag] - 1}]]
                set i [expr {$close + [string length $tag]}]
                continue
            }
        }
        if {$ch eq ";"} { lappend stmts $cur; set cur ""; incr i; continue }
        append cur $ch; incr i
    }
    lappend stmts $cur
    set out {}
    foreach s $stmts { if {[string trim $s] ne ""} { lappend out [string trim $s] } }
    return $out
}

# Run a script (one or more statements) -> {columns rows changes capped}.
# The last statement's result set is returned (mirrors sqlite's `db eval`);
# affected-row counts of DML statements are summed into `changes`.
proc ::sqledit::be::run {db sql {max 0}} {
    set cols {}; set rows {}; set changes 0; set capped 0
    foreach st [_splitStatements $sql] {
        set cols {}; set rows {}; set capped 0
        # tdbc's tokenizer does not understand $tag$...$tag$ dollar-quoting and
        # rejects any ';' it sees outside '...'; such statements (function/DO
        # bodies) go through the psql client instead.
        if {[catch {$db prepare $st} stmt]} {
            if {[string match "*semicolon*" $stmt]} {
                _psqlExec $db $st
                continue
            }
            error $stmt
        }
        if {[catch {$stmt execute} rs]} { catch {$stmt close}; error $rs }
        catch { set cols [$rs columns] }
        set nn 0; set row {}
        while {[$rs nextlist row]} {
            lappend rows $row
            if {$max > 0 && [incr nn] >= $max} { set capped 1; break }
        }
        set ch 0; catch { set ch [$rs rowcount] }
        if {$ch > 0} { incr changes $ch }
        catch { $rs close }
        catch { $stmt close }
    }
    return [dict create columns $cols rows $rows changes $changes capped $capped]
}

# Fallback for statements tdbc::postgres cannot prepare (';' inside a
# dollar-quoted body). Runs the statement through the psql client using the
# stored connection info. Returns psql's output; raises if psql is missing.
proc ::sqledit::be::_psqlExec {db sql} {
    variable _conn
    if {![info exists _conn($db)]} {
        error "cannot run this statement: tdbc::postgres rejects the ';' in it\
 (dollar-quoted body) and no connection info is available for the psql fallback"
    }
    set psql [auto_execok psql]
    if {$psql eq ""} {
        error "This statement contains ';' inside a dollar-quoted body (e.g. a\
 function or DO block). tdbc::postgres cannot send such statements, and the\
 'psql' client needed as a fallback is not on PATH."
    }
    set t $_conn($db)
    set cmd [list {*}$psql \
        -h [_dg $t host localhost] -p [_dg $t port 5432] \
        -U [_dg $t user ""] -d [_dg $t db ""] \
        -w -v ON_ERROR_STOP=1 -q -c $sql]
    set pw [_dg $t password ""]
    set had [info exists ::env(PGPASSWORD)]
    if {$had} { set old $::env(PGPASSWORD) }
    if {$pw ne ""} { set ::env(PGPASSWORD) $pw }
    set rc [catch {exec {*}$cmd 2>@1} out]
    if {$pw ne ""} {
        if {$had} { set ::env(PGPASSWORD) $old } else { unset -nocomplain ::env(PGPASSWORD) }
    }
    if {$rc} { error [string trim $out] }
    return $out
}

# Parameterized DML: $params is a dict name->value, referenced as :name.
# tdbc binds natively, so this is injection-safe. Returns affected rows.
proc ::sqledit::be::execParams {db sql params} {
    # a single statement from the form view; drop a trailing ';' that tdbc rejects
    regsub {;[[:space:]]*$} [string trim $sql] "" sql
    set stmt [$db prepare $sql]
    if {[catch {$stmt execute $params} rs]} { catch {$stmt close}; error $rs }
    set n 0
    catch { set n [$rs rowcount] }
    catch { $rs close }
    catch { $stmt close }
    return [expr {$n < 0 ? 0 : $n}]
}

# Object categories the browser shows ----------------------------------------
proc ::sqledit::be::categories {} {
    return {table Tables view Views index Indexes sequence Sequences
            trigger Triggers function Functions}
}

# --- name qualification: public -> bare, else schema.name -------------------
proc ::sqledit::be::_qual {schema name} {
    return [expr {$schema eq "public" ? $name : "$schema.$name"}]
}
proc ::sqledit::be::_split {qname} {
    set i [string first . $qname]
    if {$i < 0} { return [list public $qname] }
    return [list [string range $qname 0 $i-1] [string range $qname $i+1 end]]
}
proc ::sqledit::be::_userSchemas {} {
    return {'pg_catalog' 'information_schema' 'pg_toast'}
}

# Names of objects of a given category (schema-qualified) ---------------------
proc ::sqledit::be::objects {db type} {
    set excl [join [_userSchemas] ,]
    set q ""
    switch -- $type {
        table    { set q "SELECT schemaname AS s, tablename    AS n FROM pg_tables    WHERE schemaname NOT IN ($excl)" }
        view     { set q "SELECT schemaname AS s, viewname     AS n FROM pg_views     WHERE schemaname NOT IN ($excl)" }
        index    { set q "SELECT schemaname AS s, indexname    AS n FROM pg_indexes   WHERE schemaname NOT IN ($excl)" }
        sequence { set q "SELECT schemaname AS s, sequencename AS n FROM pg_sequences WHERE schemaname NOT IN ($excl)" }
        trigger  { set q "SELECT DISTINCT trigger_schema AS s, trigger_name AS n
                          FROM information_schema.triggers WHERE trigger_schema NOT IN ($excl)" }
        function { set q "SELECT n.nspname AS s, p.proname AS n
                          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                          WHERE n.nspname NOT IN ($excl)" }
        default  { return {} }
    }
    set out {}
    $db foreach r "$q ORDER BY s, n" { lappend out [_qual [dict get $r s] [dict get $r n]] }
    return $out
}

# Column metadata -> list of dicts {name type notnull pk dflt} ---------------
proc ::sqledit::be::columns {db qname} {
    lassign [_split $qname] schema name
    set out {}
    set sql {
        SELECT c.column_name AS cn,
               c.data_type   AS dt,
               c.character_maximum_length AS len,
               c.is_nullable AS nu,
               c.column_default AS df,
               CASE WHEN pk.column_name IS NOT NULL THEN 1 ELSE 0 END AS ispk
        FROM information_schema.columns c
        LEFT JOIN (
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON kcu.constraint_name = tc.constraint_name
             AND kcu.table_schema    = tc.table_schema
            WHERE tc.constraint_type = 'PRIMARY KEY'
              AND tc.table_schema = :schema AND tc.table_name = :name
        ) pk ON pk.column_name = c.column_name
        WHERE c.table_schema = :schema AND c.table_name = :name
        ORDER BY c.ordinal_position
    }
    $db foreach r $sql {
        set type [dict get $r dt]
        # tdbc omits the key entirely for a SQL NULL -> read defensively.
        if {[_dg $r len] ne ""} { append type "([_dg $r len])" }
        lappend out [dict create name [dict get $r cn] type $type \
            notnull [expr {[dict get $r nu] eq "NO" ? 1 : 0}] \
            pk [dict get $r ispk] dflt [_dg $r df]]
    }
    return $out
}

# Foreign keys -> list of dicts {column refTable refColumn} ------------------
proc ::sqledit::be::foreignKeys {db qname} {
    lassign [_split $qname] schema name
    set out {}
    set sql {
        SELECT kcu.column_name AS col,
               ccu.table_name  AS rt,
               ccu.column_name AS rc
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
        JOIN information_schema.constraint_column_usage ccu
          ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = :schema AND tc.table_name = :name
    }
    $db foreach r $sql {
        lappend out [dict create column [dict get $r col] \
            refTable [dict get $r rt] refColumn [dict get $r rc]]
    }
    return $out
}

# first cell of the first row (or "") -- params bound explicitly, because the
# SQL runs in this proc's scope (tdbc binds :name from the local frame).
proc ::sqledit::be::_scalar {db sql {params {}}} {
    set rows [$db allrows -as lists $sql $params]
    if {![llength $rows]} { return "" }
    return [lindex $rows 0 0]
}

# what kind of object is schema.name? r|v|m|i|S | trigger | function | "" ----
proc ::sqledit::be::_kind {db schema name} {
    set p [dict create schema $schema name $name]
    set k [_scalar $db {
        SELECT c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = :schema AND c.relname = :name} $p]
    if {$k ne ""} { return $k }
    if {[_scalar $db {
        SELECT 1 FROM information_schema.triggers
        WHERE trigger_schema = :schema AND trigger_name = :name LIMIT 1} $p] ne ""} {
        return trigger
    }
    if {[_scalar $db {
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = :schema AND p.proname = :name LIMIT 1} $p] ne ""} {
        return function
    }
    return ""
}

# CREATE text for a named object --------------------------------------------
proc ::sqledit::be::schemaOf {db qname} {
    lassign [_split $qname] schema name
    set p [dict create schema $schema name $name]
    switch -- [_kind $db $schema $name] {
        v - m {
            set def [_scalar $db {
                SELECT pg_get_viewdef(c.oid, true)
                FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = :schema AND c.relname = :name} $p]
            set kw [expr {[_kind $db $schema $name] eq "m" ? "MATERIALIZED VIEW" : "VIEW"}]
            return "CREATE $kw [_qi $schema $name] AS\n$def"
        }
        i {
            set def [_scalar $db {
                SELECT pg_get_indexdef(c.oid)
                FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = :schema AND c.relname = :name} $p]
            return [expr {$def eq "" ? "" : "$def;"}]
        }
        S {
            return [_sequenceDdl $db $schema $name]
        }
        trigger {
            set def [_scalar $db {
                SELECT pg_get_triggerdef(t.oid)
                FROM pg_trigger t
                JOIN pg_class c   ON c.oid = t.tgrelid
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = :schema AND t.tgname = :name AND NOT t.tgisinternal
                LIMIT 1} $p]
            return [expr {$def eq "" ? "" : "$def;"}]
        }
        function {
            return [_scalar $db {
                SELECT pg_get_functiondef(p.oid)
                FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = :schema AND p.proname = :name LIMIT 1} $p]
        }
        r - "" {
            return [_tableDdl $db $schema $name]
        }
    }
    return ""
}

# quote identifier(s)
proc ::sqledit::be::_qi {schema name} {
    set n "\"[string map {\" \"\"} $name]\""
    if {$schema eq "public"} { return $n }
    return "\"[string map {\" \"\"} $schema]\".$n"
}

# reconstruct a CREATE TABLE from the catalog (columns + PK + FK) ------------
proc ::sqledit::be::_tableDdl {db schema name} {
    set cols [columns $db [_qual $schema $name]]
    if {![llength $cols]} { return "" }
    set lines {}
    set pk {}
    foreach c $cols {
        set line "    \"[dict get $c name]\" [dict get $c type]"
        if {[dict get $c dflt] ne ""} { append line " DEFAULT [dict get $c dflt]" }
        if {[dict get $c notnull]}    { append line " NOT NULL" }
        lappend lines $line
        if {[dict get $c pk]} { lappend pk "\"[dict get $c name]\"" }
    }
    if {[llength $pk]} { lappend lines "    PRIMARY KEY ([join $pk {, }])" }
    foreach fk [foreignKeys $db [_qual $schema $name]] {
        lappend lines "    FOREIGN KEY (\"[dict get $fk column]\")\
 REFERENCES \"[dict get $fk refTable]\" (\"[dict get $fk refColumn]\")"
    }
    return "CREATE TABLE [_qi $schema $name] (\n[join $lines ",\n"]\n);"
}

proc ::sqledit::be::_sequenceDdl {db schema name} {
    set r [$db allrows {
        SELECT start_value AS sv, increment_by AS inc, min_value AS mn,
               max_value AS mx
        FROM pg_sequences WHERE schemaname = :schema AND sequencename = :name}]
    if {![llength $r]} { return "CREATE SEQUENCE [_qi $schema $name];" }
    set s [lindex $r 0]
    return "CREATE SEQUENCE [_qi $schema $name]\n    INCREMENT BY\
 [dict get $s inc] START WITH [dict get $s sv]\n    MINVALUE [dict get $s mn]\
 MAXVALUE [dict get $s mx];"
}

# Full schema as a runnable .sql script --------------------------------------
proc ::sqledit::be::schemaDump {db} {
    set parts {}
    foreach type {sequence table view index trigger function} {
        foreach o [objects $db $type] {
            set ddl [schemaOf $db $o]
            if {[string trim $ddl] ne ""} { lappend parts $ddl }
        }
    }
    return [join $parts "\n\n"]
}

# Preview SELECT -------------------------------------------------------------
proc ::sqledit::be::previewSql {qname limit} {
    lassign [_split $qname] schema name
    return "SELECT * FROM [_qi $schema $name] LIMIT $limit;"
}

# Database-wide summary ------------------------------------------------------
proc ::sqledit::be::summary {db} {
    set r [$db allrows {
        SELECT current_database() AS db, version() AS ver,
               pg_encoding_to_char(encoding) AS enc,
               pg_database_size(current_database()) AS sz
        FROM pg_database WHERE datname = current_database()}]
    set s [lindex $r 0]
    set d [dict create db [dict get $s db] version [dict get $s ver] \
        encoding [dict get $s enc] size [dict get $s sz]]
    foreach t {table view index sequence trigger function} {
        dict set d count_$t [llength [objects $db $t]]
    }
    return $d
}
proc ::sqledit::be::summaryText {db} {
    set d [summary $db]
    set t "Database: [dict get $d db]\n"
    append t "[dict get $d version]\n"
    append t "Encoding: [dict get $d encoding]\n"
    append t "Size: [dict get $d size] bytes\n\n"
    append t "Tables: [dict get $d count_table]   Views: [dict get $d count_view]\
   Indexes: [dict get $d count_index]\n"
    append t "Sequences: [dict get $d count_sequence]   Triggers: [dict get $d count_trigger]\
   Functions: [dict get $d count_function]"
    return $t
}

# --- connection dialog ------------------------------------------------------
proc ::sqledit::be::_connectDialog {parent} {
    variable _dlg
    array set _dlg {host 127.0.0.1 port 5432 db {} user postgres password {} ok 0}
    set w $parent.pgconnect
    catch {destroy $w}
    toplevel $w
    wm title $w "Connect to PostgreSQL"
    wm transient $w $parent
    set f [ttk::frame $w.f -padding 12]
    pack $f -fill both -expand 1
    set row 0
    foreach {key label show} {host Host: {} port Port: {} db Database: {} user User: {} password Password: *} {
        ttk::label $f.l$key -text $label
        if {$show eq "*"} {
            ttk::entry $f.e$key -show * -textvariable ::sqledit::be::_dlg($key) -width 28
        } else {
            ttk::entry $f.e$key -textvariable ::sqledit::be::_dlg($key) -width 28
        }
        grid $f.l$key $f.e$key -sticky w -padx 4 -pady 3
        incr row
    }
    set bf [ttk::frame $f.b]
    grid $bf - -pady {10 0}
    ttk::button $bf.ok -text "Connect" -command [list set ::sqledit::be::_dlg(ok) 1]
    ttk::button $bf.cancel -text "Cancel" -command [list set ::sqledit::be::_dlg(ok) 0]
    pack $bf.ok $bf.cancel -side left -padx 4
    bind $w <Return> [list set ::sqledit::be::_dlg(ok) 1]
    bind $w <Escape> [list set ::sqledit::be::_dlg(ok) 0]
    focus $f.edb
    catch {grab $w}
    tkwait variable ::sqledit::be::_dlg(ok)
    catch {grab release $w}
    destroy $w
    if {!$_dlg(ok)} { return "" }
    return [dict create host $_dlg(host) port $_dlg(port) db $_dlg(db) \
        user $_dlg(user) password $_dlg(password)]
}
