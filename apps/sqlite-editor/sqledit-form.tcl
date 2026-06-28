# sqledit-form.tcl -- record form view ("Form") for the sqledit core.
#
# An Access-style single-record editor: pick a table, see one row as a labelled
# form (built automatically from be::columns via tkutils::tkuform), navigate
# records, and edit / insert / delete. All DB access goes through the backend
# contract (columns / run / execParams), so this view works for any backend
# that fills the `pk` flag in its column dicts. Tables without a primary key
# are shown read-only.
#
# Sourced optionally by the launcher; the core mounts it via the _formBuild
# and _formRefresh hooks if present.

package require Tcl 8.6-
package require tkutils::tkuform

namespace eval ::sqledit {
    variable F
    array set F {
        tab "" combo "" holder "" form "" counter "" note "" save "" del ""
        links "" linkcols {}
        table "" cols {} pk {} colnames {} rows {} idx 0 orig {} new 0 fkmap {}
    }
}

# --- build the tab -----------------------------------------------------------
proc ::sqledit::_formBuild {nb} {
    variable F
    set f [ttk::frame $nb.form]

    set bar [ttk::frame $f.bar]
    ttk::label $bar.l -text "Table:"
    set F(combo) $bar.cb
    ttk::combobox $bar.cb -state readonly -width 24
    bind $bar.cb <<ComboboxSelected>> [list ::sqledit::_formLoadTable ""]
    ttk::separator $bar.s1 -orient vertical
    ttk::button $bar.first -text "|<" -width 3 -command [list ::sqledit::_formNav first]
    ttk::button $bar.prev  -text "<"  -width 3 -command [list ::sqledit::_formNav prev]
    set F(counter) $bar.cnt
    ttk::label $bar.cnt -text "-" -width 10 -anchor center
    ttk::button $bar.next -text ">"  -width 3 -command [list ::sqledit::_formNav next]
    ttk::button $bar.last -text ">|" -width 3 -command [list ::sqledit::_formNav last]
    ttk::separator $bar.s2 -orient vertical
    ttk::button $bar.new  -text "New"       -command ::sqledit::_formNew
    set F(save) $bar.save
    ttk::button $bar.save -text "Save" -command ::sqledit::_formSave
    set F(del) $bar.del
    ttk::button $bar.del  -text "Delete"   -command ::sqledit::_formDelete
    ttk::button $bar.rel  -text "Reload" -command ::sqledit::_formReload
    pack $bar.l $bar.cb $bar.s1 $bar.first $bar.prev $bar.cnt $bar.next $bar.last \
         $bar.s2 $bar.new $bar.save $bar.del $bar.rel -side left -padx 2 -pady 4
    pack $bar -side top -fill x

    set F(note) $f.note
    ttk::label $f.note -text "" -anchor w -foreground #aa0000
    pack $f.note -side top -fill x -padx 8

    # bottom row of "open URL" buttons, one per *url* column (filled per table)
    set F(links) $f.links
    ttk::frame $f.links
    pack $f.links -side bottom -fill x -padx 8 -pady {0 6}

    set F(holder) $f.holder
    ttk::frame $f.holder
    pack $f.holder -side top -fill both -expand 1 -padx 4 -pady 4

    $nb add $f -text "Form"
    set F(tab) $f
    return $f
}

# called from cmdRefresh: keep the table list fresh and reload the current
# table's rows WITHOUT resetting the record position (idx is preserved).
proc ::sqledit::_formRefresh {} {
    variable F
    if {$F(combo) eq "" || ![winfo exists $F(combo)]} return
    set tables [_objects table]
    $F(combo) configure -values $tables
    if {$F(table) ne "" && $F(table) in $tables && $F(form) ne ""} {
        _formReload
    }
}

# --- load a table into the form ----------------------------------------------
proc ::sqledit::_formLoadTable {t} {
    variable F; variable S
    if {$t eq ""} { set t [$F(combo) get] }
    if {$t eq "" || ![_isOpen]} return
    set F(table) $t
    $F(combo) set $t
    set F(cols) [_columns $t]
    set F(pk) {}
    foreach c $F(cols) {
        set p [dict get $c pk]
        if {$p ne "" && $p ne "0"} { lappend F(pk) [dict get $c name] }
    }
    # foreign keys -> lookup comboboxes
    set F(fkmap) [dict create]
    if {[llength [info procs ::sqledit::be::foreignKeys]]} {
        foreach fk [::sqledit::be::foreignKeys $S(db) $t] {
            dict set F(fkmap) [dict get $fk column] \
                [list [dict get $fk refTable] [dict get $fk refColumn]]
        }
    }
    _formBuildWidget
    if {![llength $F(pk)]} {
        $F(note) configure -text \
            "No primary key — read-only (Save/Delete disabled)."
        $F(save) state disabled; $F(del) state disabled
    } else {
        $F(note) configure -text ""
        $F(save) state !disabled; $F(del) state !disabled
    }
    set F(new) 0; set F(idx) 0
    _formReload
}

proc ::sqledit::_formBuildWidget {} {
    variable F
    foreach c [winfo children $F(holder)] { destroy $c }
    set spec {}
    foreach c $F(cols) {
        set n  [dict get $c name]
        set ty [string toupper [dict get $c type]]
        set p  [dict get $c pk]
        set nullable [expr {[dict get $c notnull] eq "0" || [dict get $c notnull] eq ""}]
        set label $n
        if {$p ne "" && $p ne "0"} { append label " (PK)" }
        if {[dict exists $F(fkmap) $n]} {
            lappend spec [dict create name $n label "$label \u2192" type combo \
                values [_fkValues $n $nullable]]
        } elseif {[string match *BOOL* $ty]} {
            lappend spec [dict create name $n label $label type check]
        } elseif {[string match *TEXT* $ty] || [string match *CLOB* $ty]} {
            lappend spec [dict create name $n label $label type text height 3]
        } else {
            lappend spec [dict create name $n label $label type entry]
        }
    }
    set F(form) [::tkutils::tkuform::widget $F(holder).frm $spec]
    pack $F(form) -fill both -expand 1
    _formBuildLinks
}

# Widget-name-safe token from a column name.
proc ::sqledit::_linkBtn {col} {
    variable F
    return $F(links).b_[regsub -all {[^a-zA-Z0-9]} $col _]
}

# One "open" button per column whose name contains "url" (case-insensitive).
proc ::sqledit::_formBuildLinks {} {
    variable F
    foreach c [winfo children $F(links)] { destroy $c }
    set F(linkcols) {}
    foreach c $F(cols) {
        set n [dict get $c name]
        if {[string match -nocase *url* $n]} { lappend F(linkcols) $n }
    }
    if {![llength $F(linkcols)]} return
    ttk::label $F(links).lbl -text "Open in browser:"
    pack $F(links).lbl -side left -padx {0 6}
    foreach n $F(linkcols) {
        set b [_linkBtn $n]
        ttk::button $b -text "$n \u29c9" -command [list ::sqledit::_formOpenLink $n]
        $b state disabled
        pack $b -side left -padx 2
    }
}

# Open the current record's value for column $col.
proc ::sqledit::_formOpenLink {col} {
    variable F
    if {$F(form) eq ""} return
    set vals [::tkutils::tkuform::values $F(form)]
    set v [expr {[dict exists $vals $col] ? [dict get $vals $col] : ""}]
    _openUrl $v
}

# Enable a link button only when the current value looks like a URL.
proc ::sqledit::_formLinksState {} {
    variable F
    if {![llength $F(linkcols)] || $F(form) eq ""} return
    set vals [::tkutils::tkuform::values $F(form)]
    foreach n $F(linkcols) {
        set b [_linkBtn $n]
        if {![winfo exists $b]} continue
        set v [expr {[dict exists $vals $n] ? [dict get $vals $n] : ""}]
        if {[_isUrl $v]} { $b state !disabled } else { $b state disabled }
    }
}

# Values for an FK lookup combobox: distinct referenced-column values (capped).
proc ::sqledit::_fkValues {col nullable} {
    variable F
    lassign [dict get $F(fkmap) $col] refTable refCol
    set sql "SELECT DISTINCT \"[_qid $refCol]\" AS v FROM \"[_qid $refTable]\" \
             WHERE \"[_qid $refCol]\" IS NOT NULL ORDER BY 1 LIMIT 1000"
    set vals {}
    if {![catch {_run $sql} res]} {
        foreach row [dict get $res rows] { lappend vals [lindex $row 0] }
    }
    if {$nullable} { set vals [linsert $vals 0 ""] }   ;# allow clearing -> NULL
    return $vals
}

# --- records -----------------------------------------------------------------
proc ::sqledit::_formReload {} {
    variable F
    if {$F(table) eq "" || ![_isOpen]} return
    set res [_run "SELECT * FROM \"[_qid $F(table)]\""]
    set F(colnames) [dict get $res columns]
    set F(rows) [dict get $res rows]
    set F(new) 0
    _formShow
}

proc ::sqledit::_rowDict {i} {
    variable F
    set d {}
    foreach c $F(colnames) v [lindex $F(rows) $i] { dict set d $c $v }
    return $d
}

proc ::sqledit::_formClear {} {
    variable F
    foreach name [::tkutils::tkuform::fieldNames $F(form)] {
        ::tkutils::tkuform::set $F(form) $name ""
    }
}

proc ::sqledit::_formShow {} {
    variable F
    if {$F(form) eq ""} return
    if {$F(new)} {
        _formClear; set F(orig) {}
        $F(counter) configure -text "new"
        _formLinksState
        return
    }
    set n [llength $F(rows)]
    if {$n == 0} {
        _formClear; set F(orig) {}
        $F(counter) configure -text "0 / 0"
        _formLinksState
        return
    }
    if {$F(idx) < 0}   { set F(idx) 0 }
    if {$F(idx) >= $n} { set F(idx) [expr {$n - 1}] }
    set F(orig) [_rowDict $F(idx)]
    ::tkutils::tkuform::setValues $F(form) $F(orig)
    $F(counter) configure -text "[expr {$F(idx)+1}] / $n"
    _formLinksState
}

proc ::sqledit::_formNav {dir} {
    variable F
    if {$F(form) eq ""} return
    set F(new) 0
    set n [llength $F(rows)]
    switch -- $dir {
        first { set F(idx) 0 }
        prev  { incr F(idx) -1 }
        next  { incr F(idx) 1 }
        last  { set F(idx) [expr {$n - 1}] }
    }
    _formShow
}

proc ::sqledit::_formNew {} {
    variable F
    if {$F(form) eq "" || ![llength $F(pk)]} return
    set F(new) 1
    _formShow
    _setText "New record — fill in the fields, then Save."
}

# --- write back --------------------------------------------------------------
proc ::sqledit::_formSave {} {
    variable F; variable S
    if {$F(form) eq "" || ![llength $F(pk)] || ![_isOpen]} return
    set t [_qid $F(table)]
    set vals [::tkutils::tkuform::values $F(form)]
    set wasNew $F(new)

    # NOT NULL validation (an autoincrement PK may stay empty on insert)
    foreach c $F(cols) {
        set nm [dict get $c name]
        set notnull [expr {[dict get $c notnull] ne "0" && [dict get $c notnull] ne ""}]
        set isPk    [expr {[dict get $c pk] ne "0" && [dict get $c pk] ne ""}]
        if {$notnull && [dict get $vals $nm] eq ""} {
            if {$wasNew && $isPk} continue
            _setText "Feld \"$nm\" darf nicht leer sein (NOT NULL)."
            return
        }
    }

    if {$wasNew} {
        set names {}; set ph {}; set params {}
        foreach c $F(cols) {
            set nm [dict get $c name]; set v [dict get $vals $nm]
            set isPk     [expr {[dict get $c pk] ne "0" && [dict get $c pk] ne ""}]
            set nullable [expr {[dict get $c notnull] eq "0" || [dict get $c notnull] eq ""}]
            if {$isPk && $v eq ""} continue          ;# autoincrement fills it
            lappend names "\"[_qid $nm]\""
            if {$v eq "" && $nullable} {
                lappend ph NULL
            } else {
                lappend ph :$nm; dict set params $nm $v
            }
        }
        if {![llength $names]} { _setText "Keine Werte eingegeben."; return }
        set sql "INSERT INTO \"$t\" ([join $names ,]) VALUES ([join $ph ,])"
    } else {
        set sets {}; set params {}
        foreach c $F(cols) {
            set nm [dict get $c name]
            if {[dict get $c pk] ne "0" && [dict get $c pk] ne ""} continue
            set v [dict get $vals $nm]
            set nullable [expr {[dict get $c notnull] eq "0" || [dict get $c notnull] eq ""}]
            if {$v eq "" && $nullable} {
                lappend sets "\"[_qid $nm]\" = NULL"
            } else {
                lappend sets "\"[_qid $nm]\" = :$nm"; dict set params $nm $v
            }
        }
        if {![llength $sets]} { _setText "Nichts zu speichern."; return }
        set where {}
        foreach nm $F(pk) {
            lappend where "\"[_qid $nm]\" = :wk_$nm"
            dict set params wk_$nm [dict get $F(orig) $nm]
        }
        set sql "UPDATE \"$t\" SET [join $sets ,] WHERE [join $where { AND }]"
    }
    if {[catch {::sqledit::be::execParams $S(db) $sql $params} err]} {
        ::tkutils::tkudialog::showError "Save failed:\n$err"; return
    }
    _formReload
    if {$wasNew} { set F(idx) [expr {[llength $F(rows)] - 1}]; _formShow }
    cmdRefresh
    _setText "Saved."
}

proc ::sqledit::_formDelete {} {
    variable F; variable S
    if {$F(form) eq "" || ![llength $F(pk)] || ![_isOpen] || $F(new)} return
    if {![llength $F(rows)]} return
    set ans [tk_messageBox -type yesno -icon question -title "Delete" \
        -message "Delete this record?"]
    if {$ans ne "yes"} return
    set t [_qid $F(table)]
    set where {}; set params {}
    foreach nm $F(pk) {
        lappend where "\"[_qid $nm]\" = :wk_$nm"
        dict set params wk_$nm [dict get $F(orig) $nm]
    }
    set sql "DELETE FROM \"$t\" WHERE [join $where { AND }]"
    if {[catch {::sqledit::be::execParams $S(db) $sql $params} err]} {
        ::tkutils::tkudialog::showError "Delete failed:\n$err"; return
    }
    _formReload; cmdRefresh
    _setText "Deleted."
}
