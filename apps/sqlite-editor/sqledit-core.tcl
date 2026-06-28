#!/usr/bin/env wish
# sqlite_editor.tcl -- a SQLite database editor, browser and inspector.
#
# Part of a planned family of database editors (sqlite / postgresql / oracle)
# that share one UI and a thin backend boundary. Everything SQLite-specific
# lives in the "backend" section (::sqledit::be::*); the rest of the data layer
# and the GUI are backend-agnostic, so a PostgreSQL (tdbc) or Oracle (oratcl)
# backend can later be dropped in behind the same procs.
#
# Features: SQL editor + result grid, an object browser (tables / views /
# indexes / triggers / sequences), per-object and database information, a query
# history, CSV/text export of the current result, and full schema export.
#
# The data layer is dialog-free (::sqledit::_* and ::sqledit::be::*), so the
# tool can be driven headlessly; see tests/sqlite_editor.test. The GUI is built
# only when the file is run as the main script.

package require Tcl 8.6-


namespace eval ::sqledit {
    variable S
    array set S {
        db "" file "" w "" status "" browser "" sql "" info "" hist "" nb ""
        limit 500 rescols "" resrows ""
    }
    variable HISTORY {}
}

# =============================================================================
# Data layer (backend-agnostic, dialog-free -- unit-testable)
# =============================================================================

proc ::sqledit::_isOpen {} { variable S; expr {$S(db) ne ""} }

# Quote an SQL identifier (double any embedded double-quotes).
proc ::sqledit::_qid {s} { return [string map {\" \"\"} $s] }

# A value worth offering an "open" action for.
proc ::sqledit::_isUrl {s} { return [regexp {^\s*https?://} $s] }

# Open a URL in the system browser (Linux/macOS/Windows). Returns 1 on success.
proc ::sqledit::_openUrl {url} {
    set url [string trim $url]
    if {![_isUrl $url]} { _setText "Not a valid URL."; return 0 }
    foreach exe {xdg-open open} {
        set p [auto_execok $exe]
        if {[llength $p] && ![catch {exec {*}$p $url &}]} { return 1 }
    }
    set cmd [auto_execok cmd.exe]
    if {[llength $cmd] && ![catch {exec {*}$cmd /c start {} $url &}]} { return 1 }
    set st [auto_execok start]
    if {[llength $st] && ![catch {exec {*}$st {} $url &}]} { return 1 }
    _setText "Could not open the browser."
    return 0
}

proc ::sqledit::_open {target} {
    variable S
    _close
    set S(db) [::sqledit::be::open $target]
    set S(target) $target
    set S(file) [::sqledit::be::label $target]
    return $target
}
proc ::sqledit::_close {} {
    variable S
    if {[_isOpen]} { ::sqledit::be::close $S(db) }
    set S(db) ""; set S(file) ""
}
proc ::sqledit::_run {sql {max 0}} {
    variable S
    if {![_isOpen]} { return -code error -errorcode {SQLEDIT NODB} "no database open" }
    return [::sqledit::be::run $S(db) $sql $max]
}
proc ::sqledit::_objects {type} {
    variable S
    if {![_isOpen]} { return {} }
    return [::sqledit::be::objects $S(db) $type]
}
proc ::sqledit::_tables {} { return [_objects table] }
proc ::sqledit::_schemaOf {name} {
    variable S
    if {![_isOpen]} { return "" }
    return [::sqledit::be::schemaOf $S(db) $name]
}
proc ::sqledit::_columns {name} {
    variable S
    if {![_isOpen]} { return {} }
    return [::sqledit::be::columns $S(db) $name]
}
proc ::sqledit::_info {} {
    variable S
    if {![_isOpen]} { return {} }
    return [::sqledit::be::summary $S(db)]
}
proc ::sqledit::_schemaDump {} {
    variable S
    if {![_isOpen]} { return "" }
    return [::sqledit::be::schemaDump $S(db)]
}

# --- CSV import (dialog-free, uses tclutils::tucsv) ---------------------------
# Quote an SQL identifier (table/column) by wrapping in "" and doubling any ".
proc ::sqledit::_quoteId {name} {
    return \"[string map [list \" \"\"] $name]\"
}
# A safe-ish default identifier from arbitrary text (for the suggested table).
proc ::sqledit::_sanitizeIdent {s} {
    set s [regsub -all {[^A-Za-z0-9_]} $s _]
    if {$s eq "" || [string is digit -strict [string index $s 0]]} { set s t_$s }
    return $s
}
proc ::sqledit::_columnNames {table} {
    set out {}
    foreach c [_columns $table] { lappend out [dict get $c name] }
    return $out
}
# Import a CSV file into $table. If the table exists the rows are appended (the
# CSV columns must be a subset of the table's); otherwise a new table with all
# TEXT columns is created from the header. Options: -header bool (default 1; if
# 0, columns are named c1..cN and every row is data). Rows are inserted with
# bound parameters inside a single transaction. Returns the number of rows
# imported, or throws (rolling back) on the first failing row.
proc ::sqledit::_importCsv {path table args} {
    variable S
    if {![_isOpen]} { return -code error -errorcode {SQLEDIT NODB} "no database open" }
    package require tclutils::tucsv
    array set o {-header 1}
    array set o $args
    set rows [::tclutils::tucsv::file $path]
    if {![llength $rows]} {
        return -code error -errorcode {SQLEDIT EMPTY} "CSV file is empty"
    }
    if {$o(-header)} {
        set cols [lindex $rows 0]
        set data [lrange $rows 1 end]
    } else {
        set ncol [llength [lindex $rows 0]]
        set cols {}
        for {set i 1} {$i <= $ncol} {incr i} { lappend cols c$i }
        set data $rows
    }
    if {![llength $cols]} {
        return -code error -errorcode {SQLEDIT NOCOLS} "no columns in CSV"
    }
    set ncol [llength $cols]
    if {[lsearch -exact [_objects table] $table] >= 0} {
        set tcols [_columnNames $table]
        foreach c $cols {
            if {[lsearch -exact $tcols $c] < 0} {
                return -code error -errorcode {SQLEDIT BADCOL} \
                    "CSV column \"$c\" does not exist in table \"$table\""
            }
        }
    } else {
        set defs {}
        foreach c $cols { lappend defs "[_quoteId $c] TEXT" }
        _run "CREATE TABLE [_quoteId $table] ([join $defs {, }])"
    }
    set qcols {}; set ph {}
    for {set i 0} {$i < $ncol} {incr i} {
        lappend qcols [_quoteId [lindex $cols $i]]
        lappend ph :p$i
    }
    set sql "INSERT INTO [_quoteId $table] ([join $qcols {, }]) VALUES ([join $ph {, }])"
    set n 0
    _run BEGIN
    if {[catch {
        foreach row $data {
            set params {}
            for {set i 0} {$i < $ncol} {incr i} { dict set params p$i [lindex $row $i] }
            ::sqledit::be::execParams $S(db) $sql $params
            incr n
        }
    } err]} {
        catch {_run ROLLBACK}
        return -code error -errorcode {SQLEDIT IMPORT} "import failed after $n row(s):\n$err"
    }
    _run COMMIT
    return $n
}

# --- saved queries (named SQL snippets, persisted as JSON via tujson) ---------
# Default store path: $SQLEDIT_QUERIES, else a per-user config file.
proc ::sqledit::_queriesPath {} {
    if {[info exists ::env(SQLEDIT_QUERIES)]} { return $::env(SQLEDIT_QUERIES) }
    if {$::tcl_platform(platform) eq "windows" && [info exists ::env(APPDATA)]} {
        return [file join $::env(APPDATA) sqlite-editor queries.json]
    }
    if {[info exists ::env(XDG_CONFIG_HOME)]} {
        return [file join $::env(XDG_CONFIG_HOME) sqlite-editor queries.json]
    }
    if {[info exists ::env(HOME)]} {
        return [file join $::env(HOME) .config sqlite-editor queries.json]
    }
    return [file join [pwd] sqlite-editor-queries.json]
}
# Load the name->sql dict from $path (empty dict if missing or unreadable).
proc ::sqledit::_loadQueries {path} {
    if {![file exists $path]} { return {} }
    if {[catch {
        set fh [open $path r]; set data [read $fh]; close $fh
    }]} { return {} }
    if {[string trim $data] eq ""} { return {} }
    package require tclutils::tujson
    if {[catch {::tclutils::tujson::fromJson $data} d]} { return {} }
    if {![string is list $d] || [llength $d] % 2 != 0} { return {} }
    return $d
}
# Persist the name->sql dict to $path as pretty JSON (creates the directory).
proc ::sqledit::_saveQueries {path queries} {
    package require tclutils::tujson
    set pairs {}
    foreach name [lsort [dict keys $queries]] {
        lappend pairs $name [::tclutils::tujson::str [dict get $queries $name]]
    }
    set json [::tclutils::tujson::toJson [::tclutils::tujson::obj $pairs] -indent 2]
    catch {file mkdir [file dirname $path]}
    set fh [open $path w]; puts $fh $json; close $fh
    return $path
}

# --- history -----------------------------------------------------------------
proc ::sqledit::_historyAdd {sql status} {
    variable HISTORY
    lappend HISTORY [dict create time [clock format [clock seconds] -format %H:%M:%S] \
        status $status sql $sql]
    return [llength $HISTORY]
}
proc ::sqledit::_history {} { variable HISTORY; return $HISTORY }

# --- export (reuse tclutils engines, with plain fallbacks) -------------------
proc ::sqledit::_exportCsv {path columns rows} {
    set all [linsert $rows 0 $columns]
    if {![catch {package require tclutils::tucsv}]} {
        ::tclutils::tucsv::writeFile $path $all
    } else {
        set ch [::open $path w]
        foreach r $all {
            set f {}
            foreach v $r {
                if {[string match {*[",
]*} $v]} { set v \"[string map {\" \"\"} $v]\" }
                lappend f $v
            }
            puts $ch [join $f ,]
        }
        ::close $ch
    }
    return $path
}
proc ::sqledit::_exportText {path columns rows} {
    if {![catch {package require tclutils::tutable}]} {
        set txt [::tclutils::tutable::render $columns $rows]
    } else {
        set txt [join $columns \t]\n
        foreach r $rows { append txt [join $r \t] \n }
    }
    set ch [::open $path w]; puts $ch $txt; ::close $ch
    return $path
}
# JSON: an array of row objects. Numeric cells become JSON numbers; everything
# else (including empty cells) becomes a JSON string -- the data layer cannot
# tell SQL NULL from '' apart, so we do not invent null. Uses tclutils::tujson
# when present, with a minimal self-contained fallback otherwise.
proc ::sqledit::_jsonStr {s} {
    return \"[string map [list \\ \\\\ \" \\\" \n \\n \r \\r \t \\t] $s]\"
}
proc ::sqledit::_exportJson {path columns rows} {
    if {![catch {package require tclutils::tujson}]} {
        set elems {}
        foreach r $rows {
            set pairs {}; set i 0
            foreach c $columns {
                set v [lindex $r $i]; incr i
                if {$v ne "" && [string is double -strict $v]} {
                    lappend pairs $c [::tclutils::tujson::num $v]
                } else {
                    lappend pairs $c [::tclutils::tujson::str $v]
                }
            }
            lappend elems [::tclutils::tujson::obj $pairs]
        }
        set txt [::tclutils::tujson::toJson [::tclutils::tujson::arr $elems] -indent 2]
    } else {
        set rj {}
        foreach r $rows {
            set fj {}; set i 0
            foreach c $columns {
                set v [lindex $r $i]; incr i
                if {$v ne "" && [string is double -strict $v]} {
                    lappend fj "[_jsonStr $c]: $v"
                } else {
                    lappend fj "[_jsonStr $c]: [_jsonStr $v]"
                }
            }
            lappend rj "  {[join $fj {, }]}"
        }
        set txt "\[\n[join $rj ,\n]\n\]"
    }
    set ch [::open $path w]; puts $ch $txt; ::close $ch
    return $path
}
proc ::sqledit::_exportSchema {path} {
    set ch [::open $path w]; puts $ch [_schemaDump]; ::close $ch
    return $path
}

# =============================================================================
# GUI
# =============================================================================

proc ::sqledit::requireDeps {} {
    if {[catch {::sqledit::be::requireDeps} err]} {
        if {[namespace exists ::tkutils::tkudialog]} {
            ::tkutils::tkudialog::showError $err
        } else { puts stderr "sqledit: $err" }
        exit 1
    }
}

# Call an optional backend label proc (::sqledit::be::<name>), else $default.
proc ::sqledit::_beLabel {name default} {
    if {[llength [info procs ::sqledit::be::$name]]} {
        return [::sqledit::be::$name]
    }
    return $default
}

proc ::sqledit::buildApp {toplevel} {
    variable S
    package require Tk 8.6-
    package require tkutils::tkutoolbar
    package require tkutils::tkustatus
    package require tkutils::tkudialog
    package require tkutils::tkutablelist
    package require tkutils::tkusearchbar
    package require tkutils::tkufilterbar

    set P $toplevel
    if {$P eq "."} { set P "" }

    set tb [::tkutils::tkutoolbar::widget $P.tb]
    pack $tb -side top -fill x
    ::tkutils::tkutoolbar::addButton $tb open [_beLabel connectLabel "Connect…"] ::sqledit::cmdOpen
    if {[llength [info procs ::sqledit::be::connectNew]]} {
        ::tkutils::tkutoolbar::addButton $tb new [_beLabel connectNewLabel "New"] ::sqledit::cmdNew
    }
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb exec "Execute (F5)" ::sqledit::cmdExecute
    ::tkutils::tkutoolbar::addButton $tb refr "Refresh"      ::sqledit::cmdRefresh

    set pw [ttk::panedwindow $P.pw -orient horizontal]
    pack $pw -side top -fill both -expand 1

    # --- left: object browser ---
    set lf [ttk::labelframe $pw.db -text "Database"]
    set br [ttk::treeview $lf.tv -show tree -selectmode browse \
        -yscrollcommand [list $lf.sb set]]
    ttk::scrollbar $lf.sb -orient vertical -command [list $br yview]
    pack $lf.sb -side right -fill y
    pack $br -side left -fill both -expand 1
    bind $br <Double-1> ::sqledit::cmdOpenObject
    bind $br <<TreeviewSelect>> ::sqledit::_onSelect
    set S(browser) $br

    # --- right: SQL editor over a notebook (Result / Info / History) ---
    set right [ttk::panedwindow $pw.work -orient vertical]

    set qf [ttk::labelframe $right.query -text "SQL"]
    set txt [text $qf.t -height 6 -wrap none -undo 1 \
        -yscrollcommand [list $qf.sb set]]
    ttk::scrollbar $qf.sb -orient vertical -command [list $txt yview]
    set bar [ttk::frame $qf.bar]
    ttk::button $bar.run -text "Execute" -command ::sqledit::cmdExecute
    ttk::button $bar.clr -text "Clear"   -command ::sqledit::clearSql
    pack $bar.run $bar.clr -side left -padx 2
    pack $bar -side bottom -fill x -pady 2
    pack $qf.sb -side right -fill y
    pack $txt -side left -fill both -expand 1
    set S(sql) $txt

    set nb [ttk::notebook $right.nb]
    set S(nb) $nb

    # Result tab
    set rf [ttk::frame $nb.result]
    # top row: free-text search bar + a toggle for the per-column filter bar
    set top [ttk::frame $rf.top]
    set sb [::tkutils::tkusearchbar::widget $top.search \
        -command ::sqledit::_resultFilter -width 32]
    set S(search) $sb
    set S(colfilter_on) 0
    ttk::checkbutton $top.toggle -text "Column filters" \
        -variable ::sqledit::S(colfilter_on) -command ::sqledit::_toggleColFilter
    pack $sb -side left -fill x -expand 1
    pack $top.toggle -side right -padx {6 2}
    pack $top -side top -fill x -padx 2 -pady {2 0}
    # per-column filter bar (hidden until toggled); rebuilt per result
    set fb [::tkutils::tkufilterbar::widget $rf.fbar \
        -command ::sqledit::_resultColFilter -width 10]
    set S(colfilter) $fb
    # export bar (bottom)
    set ebar [ttk::frame $rf.bar]
    ttk::button $ebar.csv  -text "Export CSV"  -command {::sqledit::cmdExportResult csv}
    ttk::button $ebar.txt  -text "Export Text" -command {::sqledit::cmdExportResult text}
    ttk::button $ebar.json -text "Export JSON" -command {::sqledit::cmdExportResult json}
    pack $ebar.csv $ebar.txt $ebar.json -side left -padx 2
    pack $ebar -side bottom -fill x -pady 2
    # pagination bar (just above the export bar)
    set pb [ttk::frame $rf.page]
    ttk::button $pb.first -text "|<" -width 3 -command ::sqledit::cmdPageFirst
    ttk::button $pb.prev  -text "<"  -width 3 -command ::sqledit::cmdPagePrev
    ttk::label  $pb.info  -text ""
    ttk::button $pb.next  -text ">"  -width 3 -command ::sqledit::cmdPageNext
    ttk::button $pb.last  -text ">|" -width 3 -command ::sqledit::cmdPageLast
    ttk::label  $pb.psl   -text "Rows/page:"
    set S(pagesize) 200
    ttk::combobox $pb.ps -width 6 -state readonly \
        -values {50 100 200 500 1000 All} -textvariable ::sqledit::S(pagesizeText)
    set S(pagesizeText) 200
    bind $pb.ps <<ComboboxSelected>> ::sqledit::cmdSetPageSize
    ttk::label  $pb.maxl  -text "Max rows:"
    set S(maxrowsText) 0
    ttk::combobox $pb.max -width 7 -state readonly \
        -values {0 1000 10000 100000} -textvariable ::sqledit::S(maxrowsText)
    set S(maxrows) 0
    bind $pb.max <<ComboboxSelected>> ::sqledit::cmdSetMaxRows
    pack $pb.first $pb.prev $pb.info $pb.next $pb.last -side left -padx 1
    pack $pb.max $pb.maxl $pb.ps $pb.psl -side right -padx {1 4}
    pack $pb -side bottom -fill x -pady {0 2}
    set S(pageinfo) $pb.info
    set S(pagebtns) [list $pb.first $pb.prev $pb.next $pb.last]
    # sortable multi-column grid (Tablelist): header click sorts the full
    # filtered set (managed, so it stays correct across page boundaries)
    set tbl [::tkutils::tkutablelist::widget $rf.tbl \
        -columns {} -stretch all -selectmode browse -stripes "#eef3fb"]
    pack $tbl -side top -fill both -expand 1
    set S(w) $tbl
    [::tkutils::tkutablelist::tableWidget $tbl] configure \
        -labelcommand ::sqledit::_resultSortClick
    $nb add $rf -text "Result"

    # Info tab
    set inf [ttk::frame $nb.info]
    set itxt [text $inf.t -wrap word -state disabled \
        -yscrollcommand [list $inf.sb set]]
    ttk::scrollbar $inf.sb -orient vertical -command [list $itxt yview]
    pack $inf.sb -side right -fill y
    pack $itxt -side left -fill both -expand 1
    set S(info) $itxt
    $nb add $inf -text "Info"

    # History tab
    set hf [ttk::frame $nb.hist]
    set hv [ttk::treeview $hf.tv -show headings -columns {time status sql} \
        -yscrollcommand [list $hf.sb set]]
    $hv heading time -text "Time";    $hv column time -width 70 -stretch 0
    $hv heading status -text "Status"; $hv column status -width 70 -stretch 0
    $hv heading sql -text "SQL";      $hv column sql -width 400
    ttk::scrollbar $hf.sb -orient vertical -command [list $hv yview]
    pack $hf.sb -side right -fill y
    pack $hv -side left -fill both -expand 1
    bind $hv <Double-1> ::sqledit::cmdLoadHistory
    set S(hist) $hv
    $nb add $hf -text "History"

    # optional Form view (sqledit-form.tcl); present only if sourced
    if {[llength [info procs ::sqledit::_formBuild]]} { ::sqledit::_formBuild $nb }
    # optional editable datasheet (sqledit-sheet.tcl)
    if {[llength [info procs ::sqledit::_sheetBuild]]} { ::sqledit::_sheetBuild $nb }

    $right add $qf -weight 1
    $right add $nb -weight 3
    $pw add $lf    -weight 1
    $pw add $right -weight 4

    set st [::tkutils::tkustatus::widget $P.status]
    pack $st -side bottom -fill x
    ::tkutils::tkustatus::addField $st rows -width 14
    set S(status) $st

    _menu $toplevel
    bind $toplevel <F5> ::sqledit::cmdExecute
    bind $toplevel <Control-o> ::sqledit::cmdOpen
    bind $toplevel <Control-n> ::sqledit::cmdNew

    _setText "No database open."
    _retitle
    return $S(w)
}

proc ::sqledit::_menu {toplevel} {
    variable S
    set m [menu $toplevel.menu]; $toplevel configure -menu $m
    set file [menu $m.file -tearoff 0]; $m add cascade -label "File" -menu $file
    $file add command -label "Open..." -accelerator "Ctrl+O" -command ::sqledit::cmdOpen
    $file add command -label "New..."  -accelerator "Ctrl+N" -command ::sqledit::cmdNew
    $file add command -label "Close"   -command ::sqledit::cmdClose
    $file add separator
    $file add command -label "Import CSV..."   -command ::sqledit::cmdImportCsv
    $file add command -label "Export Schema..." -command ::sqledit::cmdExportSchema
    $file add separator
    $file add command -label "Quit" -command {destroy .}
    set q [menu $m.query -tearoff 0]; $m add cascade -label "Query" -menu $q
    $q add command -label "Execute" -accelerator "F5" -command ::sqledit::cmdExecute
    $q add command -label "Clear"   -command ::sqledit::clearSql
    $q add separator
    $q add command -label "Export Result as CSV..."  -command {::sqledit::cmdExportResult csv}
    $q add command -label "Export Result as Text..." -command {::sqledit::cmdExportResult text}
    $q add command -label "Export Result as JSON..." -command {::sqledit::cmdExportResult json}
    set sq [menu $m.saved -tearoff 0]; $m add cascade -label "Queries" -menu $sq
    set S(qmenu) $sq
    set S(qdelmenu) [menu $sq.del -tearoff 0]
    set S(qfile) [_queriesPath]
    set S(queries) [_loadQueries $S(qfile)]
    _rebuildQueriesMenu
    set v [menu $m.view -tearoff 0]; $m add cascade -label "View" -menu $v
    $v add command -label "Refresh" -command ::sqledit::cmdRefresh
}

# --- helpers -----------------------------------------------------------------
proc ::sqledit::_setText {msg} {
    variable S
    if {$S(status) ne ""} { ::tkutils::tkustatus::setText $S(status) $msg }
}
proc ::sqledit::_setRows {n} {
    variable S
    if {$S(status) ne ""} { ::tkutils::tkustatus::setField $S(status) rows "$n rows" }
}
proc ::sqledit::_retitle {} {
    variable S
    set dn   [_beLabel displayName "SQL"]
    set name [expr {$S(file) eq "" ? "(not connected)" : $S(file)}]
    catch {wm title . "$dn Editor - $name"}
}
proc ::sqledit::clearSql {} { variable S; $S(sql) delete 1.0 end }

proc ::sqledit::_infoShow {text} {
    variable S
    set w $S(info)
    $w configure -state normal
    $w delete 1.0 end
    $w insert 1.0 $text
    $w configure -state disabled
}

# --- commands: open / refresh ------------------------------------------------
proc ::sqledit::cmdOpen {} {
    variable S
    set target [::sqledit::be::connect $S(w)]
    if {$target ne ""} { _connectTo $target }
}
proc ::sqledit::cmdNew {} {
    variable S
    if {![llength [info procs ::sqledit::be::connectNew]]} return
    set target [::sqledit::be::connectNew $S(w)]
    if {$target ne ""} { _connectTo $target }
}
proc ::sqledit::_connectTo {target} {
    if {[catch {_open $target} err]} {
        ::tkutils::tkudialog::showError "Could not connect:\n$err"; return
    }
    cmdRefresh
    _showDbInfo
    _setText "Connected: [::sqledit::be::label $target]"
    _retitle
}
proc ::sqledit::cmdClose {} {
    variable S
    _close
    $S(browser) delete [$S(browser) children {}]
    _clearResult
    _infoShow ""
    _setText "No database open."; _setRows 0; _retitle
}
proc ::sqledit::cmdRefresh {} {
    variable S
    if {![_isOpen]} return
    set br $S(browser)
    $br delete [$br children {}]
    foreach {type label} [::sqledit::be::categories] {
        set objs [_objects $type]
        if {![llength $objs]} continue
        set cat [$br insert {} end -text "$label ([llength $objs])" -open 0 \
            -values [list category ""]]
        foreach o $objs {
            $br insert $cat end -text $o -values [list $type $o]
        }
    }
    if {[llength [info procs ::sqledit::_formRefresh]]} { ::sqledit::_formRefresh }
    if {[llength [info procs ::sqledit::_sheetRefresh]]} { ::sqledit::_sheetRefresh }
}

# --- commands: browser interaction ------------------------------------------
proc ::sqledit::_selValues {} {
    variable S
    set sel [$S(browser) selection]
    if {$sel eq ""} { return {} }
    return [$S(browser) item [lindex $sel 0] -values]
}
proc ::sqledit::_onSelect {} {
    lassign [_selValues] type name
    if {$type eq "" || $type eq "category"} { _showDbInfo; return }
    _showObjectInfo $type $name
}
proc ::sqledit::cmdOpenObject {} {
    variable S
    lassign [_selValues] type name
    if {$type in {table view}} {
        $S(sql) delete 1.0 end
        $S(sql) insert 1.0 [::sqledit::be::previewSql $name $S(limit)]
        cmdExecute
    }
}
proc ::sqledit::_showDbInfo {} {
    variable S
    if {![_isOpen]} { _infoShow ""; return }
    _infoShow [::sqledit::be::summaryText $S(db)]
}
proc ::sqledit::_showObjectInfo {type name} {
    set t "[string toupper $type 0 0]: $name\n\n"
    if {$type in {table view}} {
        append t "Columns:\n"
        foreach c [_columns $name] {
            append t [format "  %-22s %-12s%s%s\n" \
                [dict get $c name] [dict get $c type] \
                [expr {[dict get $c notnull] ? "NOT NULL " : ""}] \
                [expr {[dict get $c pk] ? "PK" : ""}]]
        }
        append t "\n"
    }
    set sql [_schemaOf $name]
    if {$sql ne ""} { append t "Schema:\n$sql\n" }
    _infoShow $t
}

# --- commands: execute -------------------------------------------------------
proc ::sqledit::cmdExecute {} {
    variable S
    if {![_isOpen]} { ::tkutils::tkudialog::showWarning "Open a database first."; return }
    set sql [string trim [$S(sql) get 1.0 end]]
    if {$sql eq ""} return
    if {[catch {_run $sql $S(maxrows)} res]} {
        _histPush $sql "error"
        ::tkutils::tkudialog::showError "SQL error:\n$res"
        _setText "Error"; return
    }
    set cols [dict get $res columns]
    if {[llength $cols]} {
        _showResult $cols [dict get $res rows]
        $S(nb) select 0
        set nrows [llength [dict get $res rows]]
        set capped [expr {[dict exists $res capped] && [dict get $res capped]}]
        _histPush $sql [expr {$capped ? "$nrows rows (capped)" : "$nrows rows"}]
        _setText [expr {$capped ? "OK - capped at $S(maxrows) rows" : "OK"}]
    } else {
        _clearResult
        set n [dict get $res changes]
        _histPush $sql "$n changed"
        _setText "OK - $n row(s) affected"
        cmdRefresh
    }
}
proc ::sqledit::_histPush {sql status} {
    variable S
    _historyAdd $sql $status
    set one [string map {\n " "} [string trim $sql]]
    $S(hist) insert {} 0 -values [list [clock format [clock seconds] -format %H:%M:%S] \
        $status $one]
}
proc ::sqledit::cmdLoadHistory {} {
    variable S
    set sel [$S(hist) selection]
    if {$sel eq ""} return
    set sql [lindex [$S(hist) item [lindex $sel 0] -values] 2]
    $S(sql) delete 1.0 end
    $S(sql) insert 1.0 $sql
}

# --- result grid: filter -> sort -> page -------------------------------------
# Pipeline state:
#   S(resrows)  full result (as fetched, possibly capped)
#   S(resnum)   per-column boolean: is the column numeric?
#   S(filtered) rows after the search + per-column filters
#   S(view)     S(filtered) after the current sort
#   S(page)     0-based page index; S(pagesize) rows per page (0 = all)
#   S(sortcol)  sorted column index (-1 = none); S(sortdir) -increasing/-decreasing
proc ::sqledit::_clearResult {} {
    variable S
    ::tkutils::tkutablelist::clear $S(w)
    ::tkutils::tkutablelist::setColumns $S(w) {}
    set S(rescols) ""; set S(resrows) ""; set S(resnum) ""
    set S(filtered) ""; set S(view) ""
    set S(ftext) ""; set S(fscope) ""; set S(fcols) {}
    set S(sortcol) -1; set S(sortdir) -increasing
    set S(page) 0
    catch {::tkutils::tkusearchbar::setText $S(search) ""}
    catch {::tkutils::tkusearchbar::setFilters $S(search) {{All columns}}}
    catch {::tkutils::tkufilterbar::setColumns $S(colfilter) {}}
    catch {$S(pageinfo) configure -text ""}
    _setRows 0
}
# Tablelist column spec: numeric columns (all non-empty values are numbers) get
# a numeric sort mode and right alignment; the rest sort as text.
proc ::sqledit::_resultColumnSpec {cols rows} {
    set spec {}
    foreach num [_resultNumericFlags $cols $rows] c $cols {
        if {$num} {
            lappend spec [list $c -align right -sortmode real]
        } else {
            lappend spec [list $c -align left -sortmode dictionary]
        }
    }
    return $spec
}
proc ::sqledit::_resultNumericFlags {cols rows} {
    set flags {}
    set n [llength $cols]
    for {set i 0} {$i < $n} {incr i} {
        set numeric [expr {[llength $rows] > 0}]
        foreach r $rows {
            set v [lindex $r $i]
            if {$v eq ""} continue
            if {![string is double -strict $v]} { set numeric 0; break }
        }
        lappend flags $numeric
    }
    return $flags
}
proc ::sqledit::_showResult {cols rows} {
    variable S
    set S(rescols) $cols; set S(resrows) $rows
    set S(resnum) [_resultNumericFlags $cols $rows]
    set S(ftext) ""; set S(fscope) "All columns"; set S(fcols) {}
    set S(sortcol) -1; set S(sortdir) -increasing
    set S(page) 0
    ::tkutils::tkutablelist::setColumns $S(w) [_resultColumnSpec $cols $rows]
    catch {::tkutils::tkusearchbar::setText $S(search) ""}
    catch {::tkutils::tkusearchbar::setFilters $S(search) [linsert $cols 0 "All columns"]}
    if {[info exists S(colfilter_on)] && $S(colfilter_on)} {
        catch {::tkutils::tkufilterbar::setColumns $S(colfilter) $cols}
    }
    _applyResultFilter
}
# The grid is filtered by two cooperating inputs, ANDed together:
#   * the free-text search bar  -> _resultFilter (text + column scope)
#   * the per-column filter bar -> _resultColFilter (a dict column->text)
proc ::sqledit::_resultFilter {text filter} {
    variable S
    set S(ftext) $text; set S(fscope) $filter
    _applyResultFilter
}
proc ::sqledit::_resultColFilter {filters} {
    variable S
    set S(fcols) $filters
    _applyResultFilter
}
# Recompute S(filtered) from the full result, re-apply the sort, jump to page 1
# and render. Search terms are whitespace-separated and must all match (case-
# insensitive substring) within the scope ("All columns"/empty = any cell, else
# one column); each non-empty per-column field adds an AND condition.
proc ::sqledit::_applyResultFilter {} {
    variable S
    if {![llength $S(rescols)]} return
    set terms [regexp -all -inline {\S+} [string tolower $S(ftext)]]
    set scope -1
    if {$S(fscope) ne "" && $S(fscope) ne "All columns"} {
        set scope [lsearch -exact $S(rescols) $S(fscope)]
    }
    set colconds {}
    if {[info exists S(fcols)]} {
        dict for {c v} $S(fcols) {
            set idx [lsearch -exact $S(rescols) $c]
            if {$idx >= 0 && [string trim $v] ne ""} {
                lappend colconds [list $idx [string tolower $v]]
            }
        }
    }
    if {![llength $terms] && ![llength $colconds]} {
        set S(filtered) $S(resrows)
    } else {
        set out {}
        foreach r $S(resrows) {
            if {$scope >= 0} {
                set hay [string tolower [lindex $r $scope]]
            } else {
                set hay [string tolower $r]
            }
            set ok 1
            foreach t $terms {
                if {[string first $t $hay] < 0} { set ok 0; break }
            }
            if {$ok} {
                foreach cc $colconds {
                    lassign $cc idx needle
                    if {[string first $needle [string tolower [lindex $r $idx]]] < 0} {
                        set ok 0; break
                    }
                }
            }
            if {$ok} { lappend out $r }
        }
        set S(filtered) $out
    }
    _recomputeView
    set S(page) 0
    _renderPage
}
# Safe numeric comparator (empty sorts before any number).
proc ::sqledit::_cmpNum {a b} {
    if {$a eq "" && $b eq ""} { return 0 }
    if {$a eq ""} { return -1 }
    if {$b eq ""} { return 1 }
    if {$a < $b} { return -1 } elseif {$a > $b} { return 1 }
    return 0
}
# Apply the current sort to S(filtered) -> S(view).
proc ::sqledit::_recomputeView {} {
    variable S
    if {$S(sortcol) < 0} { set S(view) $S(filtered); return }
    set col $S(sortcol)
    if {[lindex $S(resnum) $col]} {
        set S(view) [lsort -index $col -command ::sqledit::_cmpNum $S(sortdir) $S(filtered)]
    } else {
        set S(view) [lsort -index $col -dictionary $S(sortdir) $S(filtered)]
    }
}
# Header click: toggle the sort on $col (over the whole filtered set), show page
# 1, then let Tablelist draw the sort arrow on the now-ordered page.
proc ::sqledit::_resultSortClick {tbl col} {
    variable S
    if {$S(sortcol) == $col && $S(sortdir) eq "-increasing"} {
        set S(sortdir) -decreasing
    } else {
        set S(sortdir) -increasing
    }
    set S(sortcol) $col
    _recomputeView
    set S(page) 0
    _renderPage
    catch {$tbl sortbycolumn $col $S(sortdir)}
}
# Render the current page of S(view) into the grid and update the nav bar.
proc ::sqledit::_renderPage {} {
    variable S
    set total [llength $S(view)]
    set ps $S(pagesize)
    if {$ps <= 0} {
        set slice $S(view); set pages 1; set S(page) 0
    } else {
        set pages [expr {($total + $ps - 1) / $ps}]
        if {$pages < 1} { set pages 1 }
        if {$S(page) >= $pages} { set S(page) [expr {$pages - 1}] }
        if {$S(page) < 0} { set S(page) 0 }
        set start [expr {$S(page) * $ps}]
        set slice [lrange $S(view) $start [expr {$start + $ps - 1}]]
    }
    ::tkutils::tkutablelist::setRows $S(w) $slice
    catch {$S(pageinfo) configure -text \
        "Page [expr {$S(page) + 1}] / $pages   ($total rows)"}
    if {[info exists S(pagebtns)]} {
        lassign $S(pagebtns) bf bp bn bl
        set atFirst [expr {$S(page) <= 0}]
        set atLast  [expr {$S(page) >= $pages - 1}]
        catch {$bf state [expr {$atFirst ? "disabled" : "!disabled"}]}
        catch {$bp state [expr {$atFirst ? "disabled" : "!disabled"}]}
        catch {$bn state [expr {$atLast ? "disabled" : "!disabled"}]}
        catch {$bl state [expr {$atLast ? "disabled" : "!disabled"}]}
    }
    _setRows $total
}
proc ::sqledit::cmdPageFirst {} { variable S; set S(page) 0; _renderPage }
proc ::sqledit::cmdPagePrev  {} { variable S; incr S(page) -1; _renderPage }
proc ::sqledit::cmdPageNext  {} { variable S; incr S(page) 1;  _renderPage }
proc ::sqledit::cmdPageLast  {} {
    variable S
    set ps $S(pagesize)
    if {$ps > 0} { set S(page) [expr {([llength $S(view)] + $ps - 1) / $ps}] }
    _renderPage
}
proc ::sqledit::cmdSetPageSize {} {
    variable S
    set v $S(pagesizeText)
    set S(pagesize) [expr {$v eq "All" ? 0 : $v}]
    set S(page) 0
    _renderPage
}
proc ::sqledit::cmdSetMaxRows {} {
    variable S
    set S(maxrows) $S(maxrowsText)
}
# Toggle the per-column filter bar. Showing it (re)builds its fields for the
# current result columns and packs it just above the grid; hiding it drops its
# conditions and re-applies.
proc ::sqledit::_toggleColFilter {} {
    variable S
    if {$S(colfilter_on)} {
        ::tkutils::tkufilterbar::setColumns $S(colfilter) $S(rescols)
        pack $S(colfilter) -side top -fill x -padx 2 -pady {0 2} -before $S(w)
    } else {
        pack forget $S(colfilter)
        set S(fcols) {}
        _applyResultFilter
    }
}
proc ::sqledit::cmdExportResult {fmt} {
    variable S
    if {![llength $S(rescols)]} {
        ::tkutils::tkudialog::showWarning "No result to export. Run a SELECT first."
        return
    }
    switch -- $fmt {
        csv  { set title "Export result as CSV";  set ext .csv;  set ft {{CSV .csv} {All *}} }
        json { set title "Export result as JSON"; set ext .json; set ft {{JSON .json} {All *}} }
        default { set fmt text
                  set title "Export result as text"; set ext .txt; set ft {{Text .txt} {All *}} }
    }
    set f [tk_getSaveFile -title $title -defaultextension $ext -filetypes $ft]
    if {$f eq ""} return
    if {[catch {
        switch -- $fmt {
            csv  { _exportCsv  $f $S(rescols) $S(resrows) }
            json { _exportJson $f $S(rescols) $S(resrows) }
            text { _exportText $f $S(rescols) $S(resrows) }
        }
    } err]} {
        ::tkutils::tkudialog::showError "Export failed:\n$err"; return
    }
    _setText "Exported to [file tail $f]"
}
proc ::sqledit::cmdExportSchema {} {
    if {![_isOpen]} { ::tkutils::tkudialog::showWarning "Open a database first."; return }
    set f [tk_getSaveFile -title "Export schema" -defaultextension .sql \
        -filetypes {{SQL .sql} {All *}}]
    if {$f eq ""} return
    if {[catch {_exportSchema $f} err]} {
        ::tkutils::tkudialog::showError "Export failed:\n$err"; return
    }
    _setText "Schema exported to [file tail $f]"
}
proc ::sqledit::cmdImportCsv {} {
    variable S
    if {![_isOpen]} { ::tkutils::tkudialog::showWarning "Open a database first."; return }
    set f [tk_getOpenFile -title "Import CSV" \
        -filetypes {{CSV {.csv .tsv}} {All *}}]
    if {$f eq ""} return
    set default [_sanitizeIdent [file rootname [file tail $f]]]
    set table [::tkutils::tkudialog::input -title "Import CSV" \
        -message "Target table (existing = append, new = create as TEXT):" \
        -initial $default]
    if {[string trim $table] eq ""} return
    set header [::tkutils::tkudialog::confirm \
        "Does the first row contain the column names?"]
    if {[catch {_importCsv $f $table -header $header} res]} {
        ::tkutils::tkudialog::showError $res; return
    }
    cmdRefresh
    _setText "Imported $res row(s) into $table"
}
# --- saved queries (GUI) -----------------------------------------------------
proc ::sqledit::_rebuildQueriesMenu {} {
    variable S
    set sq $S(qmenu); set del $S(qdelmenu)
    $sq delete 0 end
    $del delete 0 end
    $sq add command -label "Save Current As..." -command ::sqledit::cmdSaveQuery
    $sq add cascade -label "Delete" -menu $del
    $sq add separator
    set names [lsort -dictionary [dict keys $S(queries)]]
    if {![llength $names]} {
        $sq  add command -label "(no saved queries)" -state disabled
        $del add command -label "(none)"             -state disabled
        return
    }
    foreach n $names {
        $sq  add command -label $n -command [list ::sqledit::cmdLoadQuery $n]
        $del add command -label $n -command [list ::sqledit::cmdDeleteQuery $n]
    }
}
proc ::sqledit::cmdSaveQuery {} {
    variable S
    set sql [string trim [$S(sql) get 1.0 end]]
    if {$sql eq ""} { ::tkutils::tkudialog::showWarning "The SQL editor is empty."; return }
    set name [string trim [::tkutils::tkudialog::input -title "Save Query" \
        -message "Name for this query:"]]
    if {$name eq ""} return
    if {[dict exists $S(queries) $name] \
        && ![::tkutils::tkudialog::confirm "A query named \"$name\" exists. Overwrite?"]} {
        return
    }
    dict set S(queries) $name $sql
    if {[catch {_saveQueries $S(qfile) $S(queries)} err]} {
        ::tkutils::tkudialog::showError "Could not save:\n$err"; return
    }
    _rebuildQueriesMenu
    _setText "Saved query \"$name\""
}
proc ::sqledit::cmdLoadQuery {name} {
    variable S
    if {![dict exists $S(queries) $name]} return
    $S(sql) delete 1.0 end
    $S(sql) insert 1.0 [dict get $S(queries) $name]
    _setText "Loaded query \"$name\""
}
proc ::sqledit::cmdDeleteQuery {name} {
    variable S
    if {![dict exists $S(queries) $name]} return
    if {![::tkutils::tkudialog::confirm "Delete saved query \"$name\"?"]} return
    dict unset S(queries) $name
    if {[catch {_saveQueries $S(qfile) $S(queries)} err]} {
        ::tkutils::tkudialog::showError "Could not save:\n$err"; return
    }
    _rebuildQueriesMenu
    _setText "Deleted query \"$name\""
}
