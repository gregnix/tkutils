#!/usr/bin/env wish
# csv_editor.tcl -- a small CSV table editor.
#
# Built on the tkutils widget family: tktablelist (editable, sortable table;
# requires the Tablelist megawidget from tklib), tktoolbar, tkstatus, tkdialog,
# plus a menu bar. CSV parsing/formatting is delegated to tclutils::tucsv, so
# the delimiter, text encoding and header handling are all configurable.
#
# Data operations are factored into _-prefixed procs (no dialogs) so the tool
# can be driven headlessly; see tests/csv_editor.test. The GUI is built only
# when the file is run as the main script.

package require Tcl 8.6-

# --- locate tkutils / tclutils via the shared bootstrap ---
source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]

namespace eval ::csvedit {
    variable S
    array set S {
        file "" dirty 0 w "" status ""
        enc utf-8 delimName Comma header 1 skipcomment 1
    }
}

# =============================================================================
# Build
# =============================================================================

proc ::csvedit::buildApp {{toplevel .}} {
    variable S
    package require Tk 8.6-
    package require tkutils
    package require tkutils::tkutablelist

    wm title $toplevel "CSV Editor"
    if {$toplevel eq "."} {
        wm geometry . 860x580
        wm protocol . WM_DELETE_WINDOW ::csvedit::cmdExit
    }
    set P [expr {$toplevel eq "." ? "" : $toplevel}]

    # --- menu bar ---
    set mb [menu $P.menubar -tearoff 0]
    $toplevel configure -menu $mb
    set mfile [menu $mb.file -tearoff 0]
    $mb add cascade -label "File" -menu $mfile
    $mfile add command -label "New"        -command ::csvedit::cmdNew    -accelerator "Ctrl+N"
    $mfile add command -label "Open..."    -command ::csvedit::cmdOpen   -accelerator "Ctrl+O"
    $mfile add separator
    $mfile add command -label "Save"       -command ::csvedit::cmdSave   -accelerator "Ctrl+S"
    $mfile add command -label "Save As..." -command ::csvedit::cmdSaveAs
    $mfile add separator
    $mfile add command -label "Exit"       -command ::csvedit::cmdExit
    set medit [menu $mb.edit -tearoff 0]
    $mb add cascade -label "Edit" -menu $medit
    $medit add command -label "Add Row"          -command ::csvedit::cmdAddRow     -accelerator "Insert"
    $medit add command -label "Delete Row(s)"    -command ::csvedit::cmdDeleteRows -accelerator "Del"
    $medit add separator
    $medit add command -label "Add Column..."    -command ::csvedit::cmdAddColumn
    $medit add command -label "Rename Column..." -command ::csvedit::cmdRenameColumn
    $medit add command -label "Delete Column..." -command ::csvedit::cmdDeleteColumn

    # --- toolbar ---
    set tb [::tkutils::tkutoolbar::widget $P.tb]
    pack $tb -side top -fill x
    ::tkutils::tkutoolbar::addButton $tb open "Open" ::csvedit::cmdOpen
    ::tkutils::tkutoolbar::addButton $tb save "Save" ::csvedit::cmdSave
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb arow "Add Row"    ::csvedit::cmdAddRow
    ::tkutils::tkutoolbar::addButton $tb drow "Delete Row" ::csvedit::cmdDeleteRows
    ::tkutils::tkutoolbar::addButton $tb acol "Add Column" ::csvedit::cmdAddColumn

    # --- CSV options bar ---
    set ob [ttk::frame $P.opt]
    pack $ob -side top -fill x -pady 2
    ttk::label $ob.el -text "Encoding:"
    ttk::combobox $ob.ec -width 10 -state readonly \
        -textvariable ::csvedit::S(enc) -values {utf-8 cp1252 iso8859-1 ascii}
    ttk::label $ob.dl -text "Delimiter:"
    ttk::combobox $ob.dc -width 10 -state readonly \
        -textvariable ::csvedit::S(delimName) -values {Comma Semicolon Tab Space}
    ttk::checkbutton $ob.hd -text "Header row" -variable ::csvedit::S(header)
    ttk::checkbutton $ob.cm -text "Skip # comments" -variable ::csvedit::S(skipcomment)
    pack $ob.el $ob.ec $ob.dl $ob.dc $ob.hd $ob.cm -side left -padx 4

    # --- table ---
    set w [::tkutils::tkutablelist::widget $P.tbl -editable 1 -sortable 1 \
        -selectmode extended -stripes "#eef3fb" \
        -editendcommand ::csvedit::_onEdit]
    pack $w -side top -fill both -expand 1
    set S(w) $w

    # --- status ---
    set st [::tkutils::tkustatus::widget $P.status]
    pack $st -side bottom -fill x
    ::tkutils::tkustatus::addField $st dim -width 16
    set S(status) $st

    bind $toplevel <Control-n> ::csvedit::cmdNew
    bind $toplevel <Control-o> ::csvedit::cmdOpen
    bind $toplevel <Control-s> ::csvedit::cmdSave
    bind [::tkutils::tkutablelist::tableWidget $w] <Insert> ::csvedit::cmdAddRow
    bind [::tkutils::tkutablelist::tableWidget $w] <Delete> ::csvedit::cmdDeleteRows

    _newDoc
    return $w
}

# =============================================================================
# Status / dirty
# =============================================================================

proc ::csvedit::updateStatus {} {
    variable S
    set w $S(w)
    set r [::tkutils::tkutablelist::size $w]
    set c [llength [::tkutils::tkutablelist::columns $w]]
    ::tkutils::tkustatus::setField $S(status) dim "${r} x ${c}"
    set name [expr {$S(file) eq "" ? "(unsaved)" : [file tail $S(file)]}]
    ::tkutils::tkustatus::setText $S(status) $name
}
proc ::csvedit::markDirty {} { variable S; set S(dirty) 1; _retitle }
proc ::csvedit::clearDirty {} { variable S; set S(dirty) 0; _retitle }
proc ::csvedit::_retitle {} {
    variable S
    set name [expr {$S(file) eq "" ? "Untitled" : [file tail $S(file)]}]
    set mark [expr {$S(dirty) ? "*" : ""}]
    catch {wm title . "CSV Editor - $mark$name"}
}
proc ::csvedit::_onEdit {path row col text} {
    markDirty
    return $text
}

# Current delimiter character from the chosen name.
proc ::csvedit::_delimChar {} {
    variable S
    switch -- $S(delimName) {
        Semicolon { return ";" }
        Tab       { return "\t" }
        Space     { return " " }
        default   { return "," }
    }
}

# =============================================================================
# Data operations (no dialogs -- used by the smoke test)
# =============================================================================

proc ::csvedit::_newDoc {} {
    variable S
    ::tkutils::tkutablelist::setColumns $S(w) {Column1 Column2 Column3}
    ::tkutils::tkutablelist::setRows $S(w) {}
    set S(file) ""
    clearDirty; updateStatus
}

# Read a CSV file using the chosen encoding, delimiter and header setting.
# Split one line at the first run of whitespace into {first rest} (used by the
# "Space" delimiter, e.g. for "mm/dd/yyyy Description" style files). Lines with
# no space yield a single field.
proc ::csvedit::_firstSpaceSplit {ln} {
    set ln [string trim $ln]
    set i [string first " " $ln]
    if {$i < 0} { return [list $ln] }
    return [list [string range $ln 0 [expr {$i - 1}]] \
                 [string trim [string range $ln [expr {$i + 1}] end]]]
}

# Parse CSV text into a list of field-lists, honouring delimiter / comment
# settings. The "Space" delimiter splits each line at the first space.
proc ::csvedit::_parseCsvText {txt} {
    variable S
    set txt [string trimright $txt "\r\n"]
    if {$txt eq ""} { return {} }
    set lines [split $txt "\n"]
    if {$S(skipcomment)} {
        set keep {}
        foreach ln $lines {
            if {![string match "#*" [string trimleft $ln]]} { lappend keep $ln }
        }
        set lines $keep
    }
    if {$S(delimName) eq "Space"} {
        set rows {}
        foreach ln $lines {
            if {[string trim $ln] eq ""} continue
            lappend rows [_firstSpaceSplit $ln]
        }
        return $rows
    }
    return [::tclutils::tucsv::parse [join $lines "\n"] -delimiter [_delimChar] -strict 0]
}

proc ::csvedit::_loadFile {file} {
    variable S
    set ch [open $file r]
    fconfigure $ch -encoding $S(enc)
    set txt [read $ch]
    close $ch
    set rows [_parseCsvText $txt]
    if {$S(header) && [llength $rows]} {
        set cols [lindex $rows 0]
        set data [lrange $rows 1 end]
    } else {
        set max 0
        foreach r $rows { if {[llength $r] > $max} { set max [llength $r] } }
        set cols {}
        for {set i 1} {$i <= $max} {incr i} { lappend cols "Column$i" }
        set data $rows
    }
    if {![llength $cols]} { set cols {Column1} }
    # widen the column set to the widest data row so nothing is dropped on
    # ragged input (e.g. DATEV exports whose data rows carry extra trailing
    # fields beyond the header); extra columns get synthesised names.
    set nc [llength $cols]
    set maxw $nc
    foreach r $data { if {[llength $r] > $maxw} { set maxw [llength $r] } }
    for {set i [expr {$nc + 1}]} {$i <= $maxw} {incr i} { lappend cols "Column$i" }
    set nc $maxw
    set norm {}
    foreach r $data {
        while {[llength $r] < $nc} { lappend r "" }
        lappend norm [lrange $r 0 [expr {$nc - 1}]]
    }
    ::tkutils::tkutablelist::setColumns $S(w) $cols
    ::tkutils::tkutablelist::setRows $S(w) $norm
    set S(file) $file
    clearDirty; updateStatus
}

# Write the table to a CSV file using the chosen encoding/delimiter/header.
proc ::csvedit::_saveFile {file} {
    variable S
    set cols [::tkutils::tkutablelist::columns $S(w)]
    set rows [::tkutils::tkutablelist::rows $S(w)]
    set out [expr {$S(header) ? [linsert $rows 0 $cols] : $rows}]
    if {$S(delimName) eq "Space"} {
        set lines {}
        foreach r $out { lappend lines [join $r " "] }
        set txt [join $lines "\n"]
    } else {
        set txt [::tclutils::tucsv::text $out -delimiter [_delimChar]]
    }
    set ch [open $file w]
    fconfigure $ch -encoding $S(enc) -translation lf
    puts $ch $txt
    close $ch
    set S(file) $file
    clearDirty; updateStatus
}

proc ::csvedit::_addRow {} {
    variable S
    set n [llength [::tkutils::tkutablelist::columns $S(w)]]
    ::tkutils::tkutablelist::insert $S(w) [lrepeat $n ""]
    markDirty; updateStatus
}

proc ::csvedit::_deleteRows {indices} {
    variable S
    set n [::tkutils::tkutablelist::size $S(w)]
    foreach i [lsort -integer -decreasing $indices] {
        if {$i >= 0 && $i < $n} {
            ::tkutils::tkutablelist::deleteRow $S(w) $i
        }
    }
    markDirty; updateStatus
}

proc ::csvedit::_addColumn {name} {
    variable S
    set cols [::tkutils::tkutablelist::columns $S(w)]
    set rows [::tkutils::tkutablelist::rows $S(w)]
    lappend cols $name
    set padded {}
    foreach r $rows { lappend padded [linsert $r end ""] }
    ::tkutils::tkutablelist::setColumns $S(w) $cols
    ::tkutils::tkutablelist::setRows $S(w) $padded
    markDirty; updateStatus
}

proc ::csvedit::_renameColumn {idx name} {
    variable S
    set cols [::tkutils::tkutablelist::columns $S(w)]
    if {$idx < 0 || $idx >= [llength $cols]} return
    set rows [::tkutils::tkutablelist::rows $S(w)]
    set cols [lreplace $cols $idx $idx $name]
    ::tkutils::tkutablelist::setColumns $S(w) $cols
    ::tkutils::tkutablelist::setRows $S(w) $rows
    markDirty; updateStatus
}

proc ::csvedit::_deleteColumn {idx} {
    variable S
    set cols [::tkutils::tkutablelist::columns $S(w)]
    if {$idx < 0 || $idx >= [llength $cols]} return
    set rows [::tkutils::tkutablelist::rows $S(w)]
    set cols [lreplace $cols $idx $idx]
    set trimmed {}
    foreach r $rows { lappend trimmed [lreplace $r $idx $idx] }
    ::tkutils::tkutablelist::setColumns $S(w) $cols
    ::tkutils::tkutablelist::setRows $S(w) $trimmed
    markDirty; updateStatus
}

# =============================================================================
# Menu / toolbar commands (with dialogs)
# =============================================================================

proc ::csvedit::cmdNew {} {
    if {![_confirmDiscard]} return
    _newDoc
}
proc ::csvedit::cmdOpen {{file ""}} {
    if {![_confirmDiscard]} return
    if {$file eq ""} {
        set file [tk_getOpenFile -title "Open CSV" \
            -filetypes {{CSV {.csv}} {Text {.txt}} {All *}}]
    }
    if {$file eq ""} return
    if {[catch {_loadFile $file} err]} {
        ::tkutils::tkudialog::showError "Could not open:\n$err"
    }
}
proc ::csvedit::_trySave {file} {
    variable S
    if {[catch {_saveFile $file} err]} {
        ::tkutils::tkudialog::showError "Could not save:\n$err"
        return 0
    }
    catch {::tkutils::tkustatus::flash $S(status) "Saved [file tail $file]." 2500}
    return 1
}
proc ::csvedit::cmdSave {} {
    variable S
    if {$S(file) eq ""} { return [cmdSaveAs] }
    _trySave $S(file)
}
proc ::csvedit::cmdSaveAs {{file ""}} {
    if {$file eq ""} {
        set file [tk_getSaveFile -title "Save CSV as" -defaultextension .csv \
            -filetypes {{CSV {.csv}} {All *}}]
    }
    if {$file eq ""} return
    _trySave $file
}
proc ::csvedit::cmdExit {} {
    if {![_confirmDiscard]} return
    exit
}
proc ::csvedit::cmdAddRow {} { _addRow }
proc ::csvedit::cmdDeleteRows {} {
    variable S
    set sel [::tkutils::tkutablelist::selection $S(w)]
    if {$sel eq ""} {
        ::tkutils::tkudialog::showWarning "No rows selected."
        return
    }
    _deleteRows $sel
}
proc ::csvedit::cmdAddColumn {} {
    set v [::tkutils::tkudialog::form {
        {name name label "Column name" type entry default "Column"}
    } -title "Add Column"]
    if {$v eq ""} return
    _addColumn [dict get $v name]
}
proc ::csvedit::cmdRenameColumn {} {
    variable S
    set cols [::tkutils::tkutablelist::columns $S(w)]
    if {![llength $cols]} return
    set v [::tkutils::tkudialog::form [list \
        [list name col label "Column"   type combo values $cols default [lindex $cols 0]] \
        [list name new label "New name" type entry] \
    ] -title "Rename Column"]
    if {$v eq ""} return
    set idx [lsearch -exact $cols [dict get $v col]]
    if {$idx >= 0 && [dict get $v new] ne ""} {
        _renameColumn $idx [dict get $v new]
    }
}
proc ::csvedit::cmdDeleteColumn {} {
    variable S
    set cols [::tkutils::tkutablelist::columns $S(w)]
    if {[llength $cols] <= 1} {
        ::tkutils::tkudialog::showWarning "Cannot delete the last column."
        return
    }
    set v [::tkutils::tkudialog::form [list \
        [list name col label "Column" type combo values $cols default [lindex $cols 0]] \
    ] -title "Delete Column"]
    if {$v eq ""} return
    set idx [lsearch -exact $cols [dict get $v col]]
    if {$idx >= 0} { _deleteColumn $idx }
}

proc ::csvedit::_confirmDiscard {} {
    variable S
    if {!$S(dirty)} { return 1 }
    return [::tkutils::tkudialog::confirm \
        "There are unsaved changes. Discard them?"]
}

# =============================================================================
# Dependency check + GUI bootstrap (only when run as the main script).
# =============================================================================

# Verify Tablelist is available; show a friendly message and exit if not.
proc ::csvedit::requireTablelist {} {
    if {[catch {package require Tablelist} e]} {
        set msg "CSV Editor needs the Tablelist megawidget (from tklib),\
which is not installed.\n\nInstall it, e.g.:  apt install tklib\n\n($e)"
        if {[catch {package require Tk}] == 0} {
            catch {wm withdraw .}
            catch {tk_messageBox -icon error -title "Missing dependency" -message $msg}
        }
        puts stderr $msg
        exit 1
    }
}

if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    ::csvedit::requireTablelist
    ::csvedit::buildApp .
    if {[llength $argv] > 0} { ::csvedit::cmdOpen [lindex $argv 0] }
    vwait forever
}
