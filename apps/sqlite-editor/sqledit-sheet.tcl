# sqledit-sheet.tcl -- editable datasheet view ("Datasheet") for the core.
#
# A spreadsheet-like grid over one table: double-click a cell to edit it in
# place (Enter commits, Esc cancels), add rows, delete rows. All writes go
# through the backend contract (run / columns / execParams), keyed by the
# primary key, so it works for any backend that fills the `pk` flag. Tables
# without a primary key are shown read-only.
#
# Built on ttk::treeview + a floating entry overlay -- pure Tk, no Tablelist
# dependency. Sourced optionally; the core mounts it via _sheetBuild /
# _sheetRefresh if present.

package require Tcl 8.6-
package require Tk

namespace eval ::sqledit {
    variable D
    array set D {
        tab "" combo "" tv "" note "" add "" del "" ctxval ""
        table "" cols {} pk {} colnames {} pkmap {}
    }
}

# --- build the tab -----------------------------------------------------------
proc ::sqledit::_sheetBuild {nb} {
    variable D
    set f [ttk::frame $nb.sheet]

    set bar [ttk::frame $f.bar]
    ttk::label $bar.l -text "Table:"
    set D(combo) $bar.cb
    ttk::combobox $bar.cb -state readonly -width 24
    bind $bar.cb <<ComboboxSelected>> [list ::sqledit::_sheetLoad ""]
    ttk::separator $bar.s -orient vertical
    set D(add) $bar.add
    ttk::button $bar.add -text "Add row"      -command ::sqledit::_sheetAddRow
    set D(del) $bar.del
    ttk::button $bar.del -text "Delete row" -command ::sqledit::_sheetDelete
    ttk::button $bar.rel -text "Reload"     -command ::sqledit::_sheetReload
    pack $bar.l $bar.cb $bar.s $bar.add $bar.del $bar.rel -side left -padx 2 -pady 4
    pack $bar -side top -fill x

    set D(note) $f.note
    ttk::label $f.note -text "" -anchor w -foreground #aa0000
    pack $f.note -side top -fill x -padx 8

    set g [ttk::frame $f.g]
    set tv [ttk::treeview $g.tv -show headings -selectmode browse \
        -yscrollcommand [list $g.vsb set] -xscrollcommand [list $g.hsb set]]
    ttk::scrollbar $g.vsb -orient vertical   -command [list $tv yview]
    ttk::scrollbar $g.hsb -orient horizontal -command [list $tv xview]
    grid $tv $g.vsb -sticky nsew
    grid $g.hsb     -sticky ew
    grid rowconfigure $g 0 -weight 1
    grid columnconfigure $g 0 -weight 1
    pack $g -side top -fill both -expand 1 -padx 4 -pady 4
    set D(tv) $tv
    bind $tv <Double-1> [list ::sqledit::_sheetEdit %x %y]
    bind $tv <Delete>   ::sqledit::_sheetDelete

    # right-click context menu: open a URL cell in the browser
    menu $tv.ctx -tearoff 0
    $tv.ctx add command -label "Open in browser" -command ::sqledit::_sheetOpenUrl
    bind $tv <Button-3> [list ::sqledit::_sheetCtx %x %y %X %Y]
    bind $tv <Button-2> [list ::sqledit::_sheetCtx %x %y %X %Y]

    $nb add $f -text "Datasheet"
    set D(tab) $f
    return $f
}

# Record the clicked cell value and pop up the context menu (open only if URL).
proc ::sqledit::_sheetCtx {x y X Y} {
    variable D
    set tv $D(tv)
    set item [$tv identify item $x $y]
    set col  [$tv identify column $x $y]
    if {$item eq "" || $col eq ""} return
    set cidx [expr {[string range $col 1 end] - 1}]
    set D(ctxval) [lindex [$tv item $item -values] $cidx]
    if {[_isUrl $D(ctxval)]} {
        $tv.ctx entryconfigure 0 -state normal
    } else {
        $tv.ctx entryconfigure 0 -state disabled
    }
    tk_popup $tv.ctx $X $Y
}

proc ::sqledit::_sheetOpenUrl {} {
    variable D
    _openUrl $D(ctxval)
}

proc ::sqledit::_sheetRefresh {} {
    variable D
    if {$D(combo) eq "" || ![winfo exists $D(combo)]} return
    set tables [_objects table]
    $D(combo) configure -values $tables
    if {$D(table) ne "" && $D(table) in $tables} { _sheetReload }
}

# --- load / reload -----------------------------------------------------------
proc ::sqledit::_sheetLoad {t} {
    variable D
    if {$t eq ""} { set t [$D(combo) get] }
    if {$t eq "" || ![_isOpen]} return
    set D(table) $t
    $D(combo) set $t
    set D(cols) [_columns $t]
    set D(colnames) {}
    set D(pk) {}
    foreach c $D(cols) {
        set n [dict get $c name]; lappend D(colnames) $n
        set p [dict get $c pk]
        if {$p ne "" && $p ne "0"} { lappend D(pk) $n }
    }
    set tv $D(tv)
    $tv configure -columns $D(colnames)
    foreach n $D(colnames) {
        $tv heading $n -text $n
        $tv column  $n -width 120 -stretch 1 -anchor w
    }
    if {![llength $D(pk)]} {
        $D(note) configure -text \
            "No primary key — read-only (Edit/Delete disabled)."
        $D(add) state disabled; $D(del) state disabled
    } else {
        $D(note) configure -text ""
        $D(add) state !disabled; $D(del) state !disabled
    }
    _sheetReload
}

proc ::sqledit::_sheetReload {} {
    variable D
    if {$D(table) eq "" || ![_isOpen]} return
    set tv $D(tv)
    catch {destroy $tv.edit}
    $tv delete [$tv children {}]
    set D(pkmap) [dict create]
    set res [_run "SELECT * FROM \"[_qid $D(table)]\""]
    set cnames [dict get $res columns]
    foreach row [dict get $res rows] {
        set item [$tv insert {} end -values $row]
        if {[llength $D(pk)]} {
            set pkvals [dict create]
            foreach cn $cnames v $row {
                if {$cn in $D(pk)} { dict set pkvals $cn $v }
            }
            dict set D(pkmap) $item $pkvals
        }
    }
}

# --- in-place cell editing ---------------------------------------------------
proc ::sqledit::_sheetEdit {x y} {
    variable D
    set tv $D(tv)
    if {![llength $D(pk)]} return
    set item [$tv identify item $x $y]
    set col  [$tv identify column $x $y]
    if {$item eq "" || $col eq ""} return
    set cidx [expr {[string range $col 1 end] - 1}]
    set colname [lindex $D(colnames) $cidx]
    if {$colname in $D(pk)} { _setText "Primary key is not editable."; return }
    set bbox [$tv bbox $item $col]
    if {$bbox eq ""} return
    lassign $bbox bx by bw bh
    set e $tv.edit
    catch {destroy $e}
    entry $e
    $e insert 0 [lindex [$tv item $item -values] $cidx]
    place $e -x $bx -y $by -width $bw -height $bh
    focus $e
    $e selection range 0 end
    bind $e <Return>   [list ::sqledit::_sheetCommit $item $cidx]
    bind $e <KP_Enter> [list ::sqledit::_sheetCommit $item $cidx]
    bind $e <Escape>   [list destroy $e]
    bind $e <FocusOut> [list ::sqledit::_sheetCommit $item $cidx]
}

proc ::sqledit::_sheetCommit {item cidx} {
    variable D
    set e $D(tv).edit
    if {![winfo exists $e]} return
    set value [$e get]
    destroy $e
    _sheetSetCell $item $cidx $value
}

# The actual write (testable without the entry overlay).
proc ::sqledit::_sheetSetCell {item cidx value} {
    variable D; variable S
    if {![llength $D(pk)] || ![_isOpen]} return
    set colname [lindex $D(colnames) $cidx]
    if {$colname in $D(pk)} return
    set nullable 1
    foreach c $D(cols) {
        if {[dict get $c name] eq $colname} {
            set nullable [expr {[dict get $c notnull] eq "0" || [dict get $c notnull] eq ""}]
        }
    }
    set params {}
    if {$value eq "" && $nullable} {
        set setclause "\"[_qid $colname]\" = NULL"
    } else {
        set setclause "\"[_qid $colname]\" = :v"; dict set params v $value
    }
    set where {}
    set pkvals [dict get $D(pkmap) $item]
    foreach pk $D(pk) {
        lappend where "\"[_qid $pk]\" = :wk_$pk"
        dict set params wk_$pk [dict get $pkvals $pk]
    }
    set sql "UPDATE \"[_qid $D(table)]\" SET $setclause WHERE [join $where { AND }]"
    if {[catch {::sqledit::be::execParams $S(db) $sql $params} err]} {
        ::tkutils::tkudialog::showError "Update failed:\n$err"; return
    }
    set vals [$D(tv) item $item -values]; lset vals $cidx $value
    $D(tv) item $item -values $vals
    _setText "Zelle gespeichert."
}

# --- add / delete rows -------------------------------------------------------
proc ::sqledit::_sheetAddRow {} {
    variable D; variable S
    if {![llength $D(pk)] || ![_isOpen]} return
    set sql "INSERT INTO \"[_qid $D(table)]\" DEFAULT VALUES"
    if {[catch {::sqledit::be::execParams $S(db) $sql {}} err]} {
        ::tkutils::tkudialog::showError \
            "Could not add row (required fields without a default?):\n$err"; return
    }
    _sheetReload; cmdRefresh
    set kids [$D(tv) children {}]
    if {[llength $kids]} {
        set last [lindex $kids end]
        $D(tv) selection set $last; $D(tv) see $last
    }
    _setText "Row added."
}

proc ::sqledit::_sheetDeleteRow {item} {
    variable D; variable S
    if {![llength $D(pk)] || ![_isOpen] || $item eq ""} return
    if {![dict exists $D(pkmap) $item]} return
    set where {}; set params {}
    set pkvals [dict get $D(pkmap) $item]
    foreach pk $D(pk) {
        lappend where "\"[_qid $pk]\" = :wk_$pk"
        dict set params wk_$pk [dict get $pkvals $pk]
    }
    set sql "DELETE FROM \"[_qid $D(table)]\" WHERE [join $where { AND }]"
    if {[catch {::sqledit::be::execParams $S(db) $sql $params} err]} {
        ::tkutils::tkudialog::showError "Delete failed:\n$err"; return
    }
    _sheetReload; cmdRefresh
}

proc ::sqledit::_sheetDelete {} {
    variable D
    if {![llength $D(pk)]} return
    set sel [$D(tv) selection]
    if {![llength $sel]} return
    set ans [tk_messageBox -type yesno -icon question -title "Delete" \
        -message "Delete the selected row?"]
    if {$ans ne "yes"} return
    _sheetDeleteRow [lindex $sel 0]
    _setText "Row deleted."
}
