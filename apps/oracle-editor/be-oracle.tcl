# be-oracle.tcl -- Oracle backend for the shared sqledit core, via Oratcl.
#
# Implements the same ::sqledit::be::* contract as be-sqlite.tcl / be-postgres.tcl,
# but over Oratcl (the direct OCI binding) instead of tdbc. The whole GUI
# (sqledit-core/form/sheet) is shared unchanged; this file is the only
# Oracle-specific piece.
#
# Conventions baked in (see the "Oracle und Oratcl" handbook chapter):
#   - the app is expected to have located the Instant Client and set
#     ORACLE_LIBRARY / NLS_LANG *before* this backend loads Oratcl (bootstrap
#     belongs in the launcher, not the driver);
#   - every statement handle gets `utfmode 1` (Tcl 9 stability) and
#     `nullvalue ""` (so NULL is the empty string for every type, matching the
#     sqlite/postgres backends) right after oraopen;
#   - the session is pinned to ISO dates and dot-decimal numbers at connect;
#   - pagination uses the ROWNUM subquery, not LIMIT;
#   - binds go through oraparse + orabind, never string interpolation.
#
# A "target" here is a dict {connect user password}; `connect` is a full Oracle
# connect string (EZCONNECT host:port/service, a TNS alias, or a DESCRIPTION).
# The db handle passed around by the core is the Oratcl logon handle.

package require Tcl 8.6-

namespace eval ::sqledit::be {
    variable categories {table view index sequence trigger function}
    variable _conn      ;# logon-handle -> target dict (for label/summary)
    array set _conn {}
    variable _dlg
}

# Identity + dependency check ------------------------------------------------
proc ::sqledit::be::displayName {}  { return "Oracle" }
proc ::sqledit::be::connectLabel {} { return "Connect..." }
# no connectNew: Oracle has no "new database file".

proc ::sqledit::be::requireDeps {} {
    # The launcher is expected to have set ORACLE_LIBRARY / NLS_LANG already.
    if {[catch {package require Oratcl} err]} {
        error "This editor needs the Oratcl package with a working Oracle\
 Instant Client.\nSet ORACLE_LIBRARY (Linux) or add the client dir to PATH\
 (Windows) before starting.\n$err"
    }
}

# Interactive connect --------------------------------------------------------
proc ::sqledit::be::connect {parent} { return [_connectDialog $parent] }

proc ::sqledit::be::label {target} {
    if {$target eq ""} { return "(none)" }
    set c [_dg $target connect ""]
    set u [_dg $target user ""]
    return [expr {$u eq "" ? $c : "$u@$c"}]
}
proc ::sqledit::be::_dg {d k {def ""}} {
    return [expr {[dict exists $d $k] ? [dict get $d $k] : $def}]
}

# Connection lifecycle -------------------------------------------------------
proc ::sqledit::be::open {target} {
    variable _conn
    package require Oratcl
    set connect [_dg $target connect ""]
    set user    [_dg $target user ""]
    set pw      [_dg $target password ""]
    if {$connect eq ""} { error "no Oracle connect string given" }
    # Build "user/password@connect" when user/password are supplied separately;
    # otherwise assume the connect string already carries the credentials.
    set logon $connect
    if {$user ne ""} {
        set logon "$user/$pw@$connect"
    }
    set lh [oralogon $logon]
    set _conn($lh) $target
    # pin the session to portable date/number formats
    catch { _alterSession $lh "NLS_DATE_FORMAT = 'YYYY-MM-DD'" }
    catch { _alterSession $lh "NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'" }
    catch { _alterSession $lh "NLS_NUMERIC_CHARACTERS = '.,'" }
    return $lh
}
proc ::sqledit::be::close {db} {
    variable _conn
    unset -nocomplain _conn($db)
    catch { oralogoff $db }
}

proc ::sqledit::be::_alterSession {lh clause} {
    set sh [oraopen $lh]
    try {
        orasql $sh "ALTER SESSION SET $clause"
    } finally {
        catch { oraclose $sh }
    }
}

# Open a statement handle with the driver conventions applied ----------------
proc ::sqledit::be::_openStmt {lh} {
    set sh [oraopen $lh]
    catch { oraconfig $sh utfmode 1 }
    catch { oraconfig $sh nullvalue "" }
    # Raise the LONG fetch size so view text / trigger bodies (Oracle LONG
    # columns, default ~32K) are not truncated. The exact oraconfig option name
    # varies between Oratcl builds, so try the known candidates and let the
    # others fail silently -- if none applies, LONG simply keeps the default.
    foreach opt {longsize maxlong long} {
        catch { oraconfig $sh $opt 4194304 }
    }
    return $sh
}

# binds: {:name value ...} or {name value ...}; leading ':' added if missing.
proc ::sqledit::be::_applyBinds {sh binds} {
    if {[llength $binds] == 0} { return }
    set flat {}
    foreach {k v} $binds {
        if {[string index $k 0] ne ":"} { set k ":$k" }
        lappend flat $k $v
    }
    orabind $sh {*}$flat
}

# Run one query and return rows as a list of dicts keyed by lowercase column.
proc ::sqledit::be::_rows {lh sql {binds {}}} {
    set sh [_openStmt $lh]
    try {
        oraparse $sh $sql
        _applyBinds $sh $binds
        oraexec $sh
        set lc {}
        foreach c [oracols $sh] { lappend lc [string tolower $c] }
        set out {}
        while {[orafetch $sh -datavariable rowVals] == 0} {
            set d [dict create]
            foreach name $lc val $rowVals { dict set d $name $val }
            lappend out $d
        }
        return $out
    } finally {
        catch { oraclose $sh }
    }
}

# first cell of the first row (or "")
proc ::sqledit::be::_scalar {lh sql {binds {}}} {
    set sh [_openStmt $lh]
    try {
        oraparse $sh $sql
        _applyBinds $sh $binds
        oraexec $sh
        if {[orafetch $sh -datavariable rowVals] == 0} {
            return [lindex $rowVals 0]
        }
        return ""
    } finally {
        catch { oraclose $sh }
    }
}

# Does the statement accumulated so far begin a PL/SQL block? Inside such a
# block the inner ';' are part of the code and must NOT split -- only a lone
# '/' terminates it (SQL*Plus rule). Leading comments/whitespace are skipped.
proc ::sqledit::be::_isPlsqlStart {cur} {
    set s $cur
    # strip leading -- and /* */ comments and whitespace
    while {1} {
        set s [string trimleft $s]
        if {[string match "--*" $s]} {
            set eol [string first "\n" $s]
            if {$eol < 0} { return 0 }
            set s [string range $s [expr {$eol+1}] end]; continue
        }
        if {[string match "/*.*" $s] || [string match "/\**" $s]} {
            set e [string first "*/" $s]
            if {$e < 0} { return 0 }
            set s [string range $s [expr {$e+2}] end]; continue
        }
        break
    }
    return [regexp -nocase \
        {^(DECLARE|BEGIN)\M|^CREATE\s+(OR\s+REPLACE\s+)?(PROCEDURE|FUNCTION|TRIGGER|PACKAGE|TYPE)\M} $s]
}

# Split a SQL script into statements. A ';' separates statements, except inside
# '...' strings, "..." quoted identifiers, -- line comments, /* ... */ block
# comments, AND inside a PL/SQL block (DECLARE/BEGIN/CREATE PROCEDURE|FUNCTION|
# TRIGGER|PACKAGE|TYPE), whose inner ';' belong to the code. A line that
# contains only '/' is the SQL*Plus terminator and submits the accumulated text
# as ONE statement. Oratcl's oraparse takes a single statement without a
# trailing ';'.
proc ::sqledit::be::_splitStatements {sql} {
    set stmts {}; set cur ""; set n [string length $sql]; set i 0
    while {$i < $n} {
        set ch [string index $sql $i]
        # line comment
        if {$ch eq "-" && [string index $sql $i+1] eq "-"} {
            set eol [string first "\n" $sql $i]
            if {$eol < 0} { append cur [string range $sql $i end]; break }
            append cur [string range $sql $i $eol]; set i [expr {$eol+1}]; continue
        }
        # block comment
        if {$ch eq "/" && [string index $sql $i+1] eq "*"} {
            set end [string first "*/" $sql $i]
            if {$end < 0} { append cur [string range $sql $i end]; break }
            append cur [string range $sql $i [expr {$end+1}]]
            set i [expr {$end+2}]; continue
        }
        # quoted string / identifier
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
        # lone '/' on its own line: hard terminator (PL/SQL blocks)
        if {$ch eq "/"} {
            set ls [string last "\n" $sql [expr {$i-1}]]
            set before [string range $sql [expr {$ls+1}] [expr {$i-1}]]
            set eol [string first "\n" $sql $i]
            if {$eol < 0} { set eol $n }
            set after [string range $sql [expr {$i+1}] [expr {$eol-1}]]
            if {[string trim $before] eq "" && [string trim $after] eq ""} {
                lappend stmts $cur; set cur ""; set i [expr {$eol+1}]; continue
            }
        }
        # statement separator -- unless we are inside a PL/SQL block
        if {$ch eq ";"} {
            if {[_isPlsqlStart $cur]} { append cur $ch; incr i; continue }
            lappend stmts $cur; set cur ""; incr i; continue
        }
        append cur $ch; incr i
    }
    lappend stmts $cur
    set out {}
    foreach s $stmts {
        set s [string trim $s]
        if {$s ne ""} { lappend out $s }
    }
    return $out
}

# Run a script -> {columns rows changes capped}. Mirrors be-postgres: the last
# result set is returned; DML affected-row counts are summed into `changes`.
proc ::sqledit::be::run {db sql {max 0}} {
    set cols {}; set rows {}; set changes 0; set capped 0
    foreach st [_splitStatements $sql] {
        set cols {}; set rows {}; set capped 0
        set sh [_openStmt $db]
        try {
            oraparse $sh $st
            oraexec $sh
            set cn [oracols $sh]
            if {[llength $cn]} {
                foreach c $cn { lappend cols $c }
                set nn 0
                while {[orafetch $sh -datavariable rowVals] == 0} {
                    lappend rows $rowVals
                    if {$max > 0 && [incr nn] >= $max} { set capped 1; break }
                }
            } else {
                set ch 0; catch { set ch [oramsg $sh rows] }
                if {[string is integer -strict $ch] && $ch > 0} { incr changes $ch }
            }
        } finally {
            catch { oraclose $sh }
        }
    }
    return [dict create columns $cols rows $rows changes $changes capped $capped]
}

# Parameterized DML from the form view: $params is name->value, ref'd as :name.
proc ::sqledit::be::execParams {db sql params} {
    regsub {;[[:space:]]*$} [string trim $sql] "" sql
    set sh [_openStmt $db]
    try {
        oraparse $sh $sql
        _applyBinds $sh $params
        oraexec $sh
        set n 0; catch { set n [oramsg $sh rows] }
        return [expr {[string is integer -strict $n] && $n > 0 ? $n : 0}]
    } finally {
        catch { oraclose $sh }
    }
}

# Object categories the browser shows ----------------------------------------
proc ::sqledit::be::categories {} {
    return {table Tables view Views index Indexes sequence Sequences
            trigger Triggers function Functions}
}

# Names of objects of a category (current schema only; USER_* views) ----------
proc ::sqledit::be::objects {db type} {
    switch -- $type {
        table    { set sql "SELECT table_name AS n FROM user_tables ORDER BY table_name" }
        view     { set sql "SELECT view_name  AS n FROM user_views  ORDER BY view_name" }
        index    { set sql "SELECT index_name AS n FROM user_indexes\
                            WHERE index_type <> 'LOB' ORDER BY index_name" }
        sequence { set sql "SELECT sequence_name AS n FROM user_sequences ORDER BY sequence_name" }
        trigger  { set sql "SELECT trigger_name AS n FROM user_triggers ORDER BY trigger_name" }
        function { set sql "SELECT object_name AS n FROM user_objects\
                            WHERE object_type IN ('FUNCTION','PROCEDURE') ORDER BY object_name" }
        default  { return {} }
    }
    set out {}
    foreach r [_rows $db $sql] { lappend out [dict get $r n] }
    return $out
}

# Column metadata -> list of dicts {name type notnull pk dflt} ---------------
proc ::sqledit::be::columns {db qname} {
    set tn [string toupper $qname]
    # primary-key columns of this table
    set pkcols {}
    foreach r [_rows $db {
        SELECT cc.column_name AS cn
        FROM user_constraints c
        JOIN user_cons_columns cc ON cc.constraint_name = c.constraint_name
        WHERE c.table_name = :tn AND c.constraint_type = 'P'
    } [list :tn $tn]] {
        lappend pkcols [string toupper [dict get $r cn]]
    }
    set out {}
    foreach r [_rows $db {
        SELECT column_name AS cn, data_type AS dt, data_length AS len,
               data_precision AS prec, data_scale AS scale,
               nullable AS nu, data_default AS df
        FROM user_tab_columns
        WHERE table_name = :tn
        ORDER BY column_id
    } [list :tn $tn]] {
        set type [dict get $r dt]
        set len   [_dg $r len]
        set prec  [_dg $r prec]
        set scale [_dg $r scale]
        # render a readable type: NUMBER(p,s) / VARCHAR2(n) / plain
        if {$type in {NUMBER} && $prec ne ""} {
            set type [expr {$scale ne "" && $scale != 0 ? "NUMBER($prec,$scale)" : "NUMBER($prec)"}]
        } elseif {$type in {VARCHAR2 CHAR NVARCHAR2 NCHAR RAW} && $len ne ""} {
            append type "($len)"
        }
        set cn [dict get $r cn]
        lappend out [dict create name $cn type $type \
            notnull [expr {[dict get $r nu] eq "N" ? 1 : 0}] \
            pk [expr {[string toupper $cn] in $pkcols ? 1 : 0}] \
            dflt [string trim [_dg $r df]]]
    }
    return $out
}

# Foreign keys -> list of dicts {column refTable refColumn} ------------------
proc ::sqledit::be::foreignKeys {db qname} {
    set tn [string toupper $qname]
    set out {}
    # each R-constraint on this table; join own columns to the referenced
    # constraint's columns by position.
    foreach h [_rows $db {
        SELECT c.constraint_name AS cn, c.r_constraint_name AS rcn,
               r.table_name AS rt
        FROM user_constraints c
        JOIN user_constraints r ON r.constraint_name = c.r_constraint_name
        WHERE c.table_name = :tn AND c.constraint_type = 'R'
        ORDER BY c.constraint_name
    } [list :tn $tn]] {
        set cn  [dict get $h cn]
        set rcn [dict get $h rcn]
        set rt  [dict get $h rt]
        set fromCols {}
        foreach r [_rows $db {
            SELECT column_name AS c FROM user_cons_columns
            WHERE constraint_name = :cn ORDER BY position
        } [list :cn $cn]] { lappend fromCols [dict get $r c] }
        set toCols {}
        foreach r [_rows $db {
            SELECT column_name AS c FROM user_cons_columns
            WHERE constraint_name = :cn ORDER BY position
        } [list :cn $rcn]] { lappend toCols [dict get $r c] }
        foreach fc $fromCols tc $toCols {
            lappend out [dict create column $fc refTable $rt refColumn $tc]
        }
    }
    return $out
}

# What kind of object is this name? TABLE|VIEW|INDEX|SEQUENCE|TRIGGER|FUNCTION..
proc ::sqledit::be::_kind {db name} {
    return [_scalar $db {
        SELECT object_type FROM user_objects
        WHERE object_name = :n
        ORDER BY CASE object_type
                 WHEN 'TABLE' THEN 1 WHEN 'VIEW' THEN 2 ELSE 3 END
    } [list :n [string toupper $name]]]
}

# quote identifier only if it is not a simple uppercase name
proc ::sqledit::be::_qi {name} {
    if {[regexp {^[A-Z][A-Z0-9_]*$} $name]} { return $name }
    return "\"[string map {\" \"\"} $name]\""
}

# CREATE text for a named object --------------------------------------------
proc ::sqledit::be::schemaOf {db qname} {
    switch -- [_kind $db $qname] {
        TABLE            { return [_tableDdl $db $qname] }
        VIEW             { return [_viewDdl  $db $qname] }
        INDEX            { return [_indexDdl $db $qname] }
        SEQUENCE         { return [_sequenceDdl $db $qname] }
        TRIGGER          { return [_triggerDdl $db $qname] }
        FUNCTION         { return [_sourceDdl $db $qname FUNCTION] }
        PROCEDURE        { return [_sourceDdl $db $qname PROCEDURE] }
        default          { return "" }
    }
}

# reconstruct CREATE TABLE from the catalog (columns + PK + FK) --------------
proc ::sqledit::be::_tableDdl {db name} {
    set cols [columns $db $name]
    if {![llength $cols]} { return "" }
    set lines {}
    set pk {}
    foreach c $cols {
        set line "    [_qi [dict get $c name]] [dict get $c type]"
        if {[dict get $c dflt] ne ""} { append line " DEFAULT [dict get $c dflt]" }
        if {[dict get $c notnull]}    { append line " NOT NULL" }
        lappend lines $line
        if {[dict get $c pk]} { lappend pk [_qi [dict get $c name]] }
    }
    if {[llength $pk]} { lappend lines "    PRIMARY KEY ([join $pk {, }])" }
    foreach fk [foreignKeys $db $name] {
        lappend lines "    FOREIGN KEY ([_qi [dict get $fk column]])\
 REFERENCES [_qi [dict get $fk refTable]] ([_qi [dict get $fk refColumn]])"
    }
    return "CREATE TABLE [_qi [string toupper $name]] (\n[join $lines ",\n"]\n);"
}

# reconstruct CREATE INDEX from USER_INDEXES + USER_IND_COLUMNS -------------
proc ::sqledit::be::_indexDdl {db name} {
    set ix [string toupper $name]
    set head [_rows $db {
        SELECT uniqueness AS u, table_name AS t FROM user_indexes
        WHERE index_name = :ix} [list :ix $ix]]
    if {![llength $head]} { return "" }
    set h [lindex $head 0]
    set uniq [expr {[dict get $h u] eq "UNIQUE" ? "UNIQUE " : ""}]
    set cols {}
    foreach r [_rows $db {
        SELECT column_name AS c FROM user_ind_columns
        WHERE index_name = :ix ORDER BY column_position} [list :ix $ix]] {
        lappend cols [_qi [dict get $r c]]
    }
    return "CREATE ${uniq}INDEX [_qi $ix] ON [_qi [dict get $h t]]\
 ([join $cols {, }]);"
}

# reconstruct CREATE SEQUENCE from USER_SEQUENCES ---------------------------
proc ::sqledit::be::_sequenceDdl {db name} {
    set sq [string toupper $name]
    set r [_rows $db {
        SELECT min_value AS mn, max_value AS mx, increment_by AS inc,
               cache_size AS cache, cycle_flag AS cyc
        FROM user_sequences WHERE sequence_name = :sq} [list :sq $sq]]
    if {![llength $r]} { return "CREATE SEQUENCE [_qi $sq];" }
    set s [lindex $r 0]
    set ddl "CREATE SEQUENCE [_qi $sq]\n    INCREMENT BY [dict get $s inc]"
    append ddl "\n    MINVALUE [dict get $s mn] MAXVALUE [dict get $s mx]"
    if {[_dg $s cache] ne "" && [dict get $s cache] > 0} {
        append ddl "\n    CACHE [dict get $s cache]"
    }
    append ddl [expr {[_dg $s cyc] eq "Y" ? "\n    CYCLE" : ""}]
    append ddl ";"
    return $ddl
}

# view text (USER_VIEWS.text is a LONG -- see LONG note in the header) -------
proc ::sqledit::be::_viewDdl {db name} {
    set vn [string toupper $name]
    set txt [_scalar $db {
        SELECT text FROM user_views WHERE view_name = :vn} [list :vn $vn]]
    if {[string trim $txt] eq ""} { return "" }
    return "CREATE OR REPLACE VIEW [_qi $vn] AS\n$txt;"
}

# trigger body (USER_TRIGGERS.trigger_body is a LONG) -----------------------
proc ::sqledit::be::_triggerDdl {db name} {
    set tg [string toupper $name]
    set r [_rows $db {
        SELECT description AS d, trigger_body AS b
        FROM user_triggers WHERE trigger_name = :tg} [list :tg $tg]]
    if {![llength $r]} { return "" }
    set h [lindex $r 0]
    set desc [string trim [_dg $h d]]
    set body [_dg $h b]
    return "CREATE OR REPLACE TRIGGER $desc$body\n/"
}

# function/procedure source from USER_SOURCE (VARCHAR2 lines, no LONG) -------
proc ::sqledit::be::_sourceDdl {db name type} {
    set nm [string toupper $name]
    set src ""
    foreach r [_rows $db {
        SELECT text AS t FROM user_source
        WHERE name = :nm AND type = :ty ORDER BY line} [list :nm $nm :ty $type]] {
        append src [dict get $r t]
    }
    if {[string trim $src] eq ""} { return "" }
    # USER_SOURCE starts at "FUNCTION name..." / "PROCEDURE name..."; add the
    # CREATE OR REPLACE prefix and a terminating slash.
    return "CREATE OR REPLACE [string trim $src]\n/"
}

# Full schema as a runnable script ------------------------------------------
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

# Preview SELECT (ROWNUM subquery, not LIMIT) -------------------------------
proc ::sqledit::be::previewSql {qname limit} {
    return "SELECT * FROM (SELECT * FROM [_qi [string toupper $qname]])\
 WHERE ROWNUM <= $limit"
}

# Database-wide summary ------------------------------------------------------
proc ::sqledit::be::summary {db} {
    set d [dict create]
    dict set d db  [_scalar $db {SELECT sys_context('USERENV','DB_NAME') FROM dual}]
    dict set d user [_scalar $db {SELECT user FROM dual}]
    set ver ""
    catch { set ver [orainfo server $db] }
    if {$ver eq ""} {
        catch { set ver [_scalar $db {
            SELECT banner FROM v$version WHERE ROWNUM <= 1}] }
    }
    if {$ver eq ""} {
        catch { set ver [_scalar $db {
            SELECT version FROM product_component_version WHERE ROWNUM <= 1}] }
    }
    dict set d version $ver
    set enc ""
    catch { set enc [_scalar $db {
        SELECT value FROM nls_database_parameters
        WHERE parameter = 'NLS_CHARACTERSET'}] }
    dict set d encoding $enc
    foreach t {table view index sequence trigger function} {
        dict set d count_$t [llength [objects $db $t]]
    }
    return $d
}
proc ::sqledit::be::summaryText {db} {
    set d [summary $db]
    set t "Schema: [dict get $d user]"
    if {[dict get $d db] ne ""} { append t "@[dict get $d db]" }
    append t "\n"
    if {[dict get $d version] ne ""}  { append t "[dict get $d version]\n" }
    if {[dict get $d encoding] ne ""} { append t "Character set: [dict get $d encoding]\n" }
    append t "\nTables: [dict get $d count_table]   Views: [dict get $d count_view]\
   Indexes: [dict get $d count_index]\n"
    append t "Sequences: [dict get $d count_sequence]   Triggers: [dict get $d count_trigger]\
   Functions: [dict get $d count_function]"
    return $t
}

# backend key for the shared profile store
proc ::sqledit::be::_backendKey {} { return "oracle" }

# --- connection dialog ------------------------------------------------------
proc ::sqledit::be::_connectDialog {parent} {
    variable _dlg
    array set _dlg {connect {} user {} password {} savepw 0 pname {} ok 0}
    set w $parent.oraconnect
    catch {destroy $w}
    toplevel $w
    wm title $w "Connect to Oracle"
    wm transient $w $parent
    set f [ttk::frame $w.f -padding 12]
    pack $f -fill both -expand 1
    set haveStore [expr {[llength [info commands ::sqledit::conn::names]] > 0}]

    # saved profiles (if the shared store is available) -----------------------
    if {$haveStore} {
        ttk::label $f.lprof -text "Profile:"
        ttk::combobox $f.prof -textvariable ::sqledit::be::_dlg(pname) -width 26 \
            -values [::sqledit::conn::names [_backendKey]]
        ttk::button $f.del -text "Delete" -width 7 \
            -command [list ::sqledit::be::_profDelete $f]
        grid $f.lprof $f.prof $f.del -sticky w -padx 4 -pady {0 6}
        bind $f.prof <<ComboboxSelected>> [list ::sqledit::be::_profLoad $f]
    }

    ttk::label $f.hint -text "Connect: host:port/service, a TNS alias, or a DESCRIPTION(...)"
    grid $f.hint - - -sticky w -pady {0 6}
    foreach {key label show} {connect Connect: {} user User: {} password Password: *} {
        ttk::label $f.l$key -text $label
        if {$show eq "*"} {
            ttk::entry $f.e$key -show * -textvariable ::sqledit::be::_dlg($key) -width 34
        } else {
            ttk::entry $f.e$key -textvariable ::sqledit::be::_dlg($key) -width 34
        }
        grid $f.l$key $f.e$key - -sticky w -padx 4 -pady 3
    }

    if {$haveStore} {
        ttk::checkbutton $f.savepw -text "Save password" \
            -variable ::sqledit::be::_dlg(savepw)
        ttk::button $f.save -text "Save profile" -width 12 \
            -command [list ::sqledit::be::_profSave $f]
        grid $f.savepw $f.save -sticky w -padx 4 -pady {4 0}
    }

    set bf [ttk::frame $f.b]
    grid $bf - - -pady {10 0}
    ttk::button $bf.ok -text "Connect" -command [list set ::sqledit::be::_dlg(ok) 1]
    ttk::button $bf.cancel -text "Cancel" -command [list set ::sqledit::be::_dlg(ok) 0]
    pack $bf.ok $bf.cancel -side left -padx 4
    bind $w <Return> [list set ::sqledit::be::_dlg(ok) 1]
    bind $w <Escape> [list set ::sqledit::be::_dlg(ok) 0]
    focus $f.econnect
    catch {grab $w}
    tkwait variable ::sqledit::be::_dlg(ok)
    catch {grab release $w}
    destroy $w
    if {!$_dlg(ok)} { return "" }
    return [dict create connect $_dlg(connect) user $_dlg(user) password $_dlg(password)]
}

# fill the fields from the selected saved profile
proc ::sqledit::be::_profLoad {f} {
    variable _dlg
    set t [::sqledit::conn::get [_backendKey] $_dlg(pname)]
    if {$t eq ""} return
    foreach k {connect user password} {
        set _dlg($k) [expr {[dict exists $t $k] ? [dict get $t $k] : ""}]
    }
}

# save the current fields under the profile name (password only if ticked)
proc ::sqledit::be::_profSave {f} {
    variable _dlg
    set name [string trim $_dlg(pname)]
    if {$name eq ""} {
        tk_messageBox -parent $f -icon warning -title "Save profile" \
            -message "Enter a profile name first."
        return
    }
    set t [dict create connect $_dlg(connect) user $_dlg(user) password $_dlg(password)]
    if {!$_dlg(savepw)} { set t [::sqledit::conn::stripSecret $t] }
    ::sqledit::conn::save [_backendKey] $name $t
    $f.prof configure -values [::sqledit::conn::names [_backendKey]]
}

proc ::sqledit::be::_profDelete {f} {
    variable _dlg
    set name [string trim $_dlg(pname)]
    if {$name eq ""} return
    ::sqledit::conn::delete [_backendKey] $name
    $f.prof configure -values [::sqledit::conn::names [_backendKey]]
    set _dlg(pname) ""
}
