#!/usr/bin/env wish
# notes_app.tcl -- a small but complete notes application.
#
# Built entirely on the tkutils widget family: tknotes (hierarchical notes tree
# + editor, with its built-in bar disabled via -toolbar 0), tktoolbar (the app
# toolbar), tkstatus (status bar) and tkdialog (confirm/input/message dialogs),
# plus a classic menu bar. All note logic and JSON persistence live in the
# tclutils tunotes engine, reached through tknotes.
#
# The command procs are factored so the app can be driven without dialogs (used
# by the headless smoke test); the GUI is only built when run as main script.

package require Tcl 8.6-

# --- locate tkutils / tclutils via the shared bootstrap ---
source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]

namespace eval ::notesapp {
    variable S
    array set S {file "" dirty 0 w ""}
}

# =============================================================================
# Build
# =============================================================================

proc ::notesapp::buildApp {{toplevel .}} {
    variable S
    package require Tk 8.6-
    package require tkutils
    package require tclutils::tunotes 0.1

    wm title $toplevel "Notes"
    if {$toplevel eq "."} {
        wm geometry . 900x600
        wm protocol . WM_DELETE_WINDOW ::notesapp::cmdExit
    }
    set P [expr {$toplevel eq "." ? "" : $toplevel}]

    # --- menu bar ---
    set mb [menu $P.menubar -tearoff 0]
    $toplevel configure -menu $mb

    set mfile [menu $mb.file -tearoff 0]
    $mb add cascade -label "File" -menu $mfile
    $mfile add command -label "New"        -command ::notesapp::cmdNew -accelerator "Ctrl+Shift+O"
    $mfile add command -label "Open..."    -command ::notesapp::cmdOpen -accelerator "Ctrl+O"
    $mfile add separator
    $mfile add command -label "Save"       -command ::notesapp::cmdSave -accelerator "Ctrl+S"
    $mfile add command -label "Save As..." -command ::notesapp::cmdSaveAs
    $mfile add separator
    $mfile add command -label "Exit"       -command ::notesapp::cmdExit

    set medit [menu $mb.edit -tearoff 0]
    $mb add cascade -label "Edit" -menu $medit
    $medit add command -label "New Root Note"  -command ::notesapp::cmdNewRoot -accelerator "Ctrl+N"
    $medit add command -label "New Child Note" -command ::notesapp::cmdNewChild -accelerator "Ctrl+Shift+N"
    $medit add separator
    $medit add command -label "Save Note (commit)" -command ::notesapp::cmdCommit
    $medit add separator
    $medit add command -label "Delete (with children)"  -command {::notesapp::cmdDelete 1} -accelerator "Del"
    $medit add command -label "Delete (keep children)"  -command {::notesapp::cmdDelete 0}
    $medit add separator
    $medit add command -label "Move to Root"   -command ::notesapp::cmdMoveToRoot
    $medit add command -label "Move under..."  -command ::notesapp::cmdMoveUnder

    set mview [menu $mb.view -tearoff 0]
    $mb add cascade -label "View" -menu $mview
    $mview add command -label "Expand All"   -command {::notesapp::cmdExpand 1}
    $mview add command -label "Collapse All" -command {::notesapp::cmdExpand 0}
    $mview add separator
    $mview add command -label "Refresh"      -command ::notesapp::cmdRefresh -accelerator "F5"

    # --- toolbar (tktoolbar) ---
    set tb [::tkutils::tkutoolbar::widget $P.tb]
    pack $tb -side top -fill x
    ::tkutils::tkutoolbar::addButton $tb newroot "New Root"  ::notesapp::cmdNewRoot
    ::tkutils::tkutoolbar::addButton $tb newchild "New Child" ::notesapp::cmdNewChild
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb del   "Delete"   {::notesapp::cmdDelete 1}
    ::tkutils::tkutoolbar::addButton $tb save  "Save"     ::notesapp::cmdSave
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb exp   "Expand"   {::notesapp::cmdExpand 1}
    ::tkutils::tkutoolbar::addButton $tb col   "Collapse" {::notesapp::cmdExpand 0}

    # --- notes widget (its own bar disabled; the app drives it) ---
    set w [::tkutils::tkunotes::widget $P.notes -toolbar 0]
    pack $w -side top -fill both -expand 1
    set S(w) $w

    # --- status bar (tkstatus) ---
    set st [::tkutils::tkustatus::widget $P.status]
    pack $st -side bottom -fill x
    ::tkutils::tkustatus::addField $st count -width 12
    set S(status) $st

    # selecting a note updates the path shown in the status bar
    bind [::tkutils::tkunotes::treeWidget $w] <<TreeviewSelect>> \
        +[list ::notesapp::updateStatus]

    # accelerators
    bind $toplevel <Control-n> ::notesapp::cmdNewRoot
    bind $toplevel <Control-N> ::notesapp::cmdNewChild
    bind $toplevel <Control-s> ::notesapp::cmdSave
    bind $toplevel <Control-o> ::notesapp::cmdOpen
    bind $toplevel <F5>        ::notesapp::cmdRefresh
    bind [::tkutils::tkunotes::treeWidget $w] <Delete> {::notesapp::cmdDelete 1}

    clearDirty
    updateStatus
    return $w
}

# =============================================================================
# Status / dirty
# =============================================================================

proc ::notesapp::updateStatus {} {
    variable S
    set w $S(w)
    set n [::tkutils::tkunotes::count $w]
    ::tkutils::tkustatus::setField $S(status) count "$n note(s)"
    set cur [::tkutils::tkunotes::current $w]
    if {$cur ne ""} {
        set store [::tkutils::tkunotes::store $w]
        set titles {}
        foreach id [::tclutils::tunotes::path $store $cur] {
            lappend titles [dict get [::tclutils::tunotes::get $store $id] title]
        }
        ::tkutils::tkustatus::setText $S(status) [join $titles " / "]
    } else {
        ::tkutils::tkustatus::setText $S(status) "Ready."
    }
}

proc ::notesapp::markDirty {} {
    variable S
    set S(dirty) 1
    _retitle
}
proc ::notesapp::clearDirty {} {
    variable S
    set S(dirty) 0
    _retitle
}
proc ::notesapp::_retitle {} {
    variable S
    set name [expr {$S(file) eq "" ? "Untitled" : [file tail $S(file)]}]
    set mark [expr {$S(dirty) ? "*" : ""}]
    catch {wm title . "Notes - $mark$name"}
}

# =============================================================================
# Commands
# =============================================================================

proc ::notesapp::cmdNewRoot {} {
    variable S
    ::tkutils::tkunotes::addRoot $S(w) "New note" ""
    markDirty; updateStatus
    catch {focus $S(w).pw.r.title}
}

proc ::notesapp::cmdNewChild {} {
    variable S
    set parent [::tkutils::tkunotes::current $S(w)]
    ::tkutils::tkunotes::addChild $S(w) $parent "New note" ""
    markDirty; updateStatus
    catch {focus $S(w).pw.r.title}
}

proc ::notesapp::cmdCommit {} {
    variable S
    ::tkutils::tkunotes::commit $S(w)
    markDirty; updateStatus
}

proc ::notesapp::cmdDelete {cascade} {
    variable S
    set cur [::tkutils::tkunotes::current $S(w)]
    if {$cur eq ""} {
        ::tkutils::tkudialog::showWarning "No note selected."
        return
    }
    set msg [expr {$cascade ? "Delete this note and all its children?" \
                            : "Delete this note and move its children to root?"}]
    if {![::tkutils::tkudialog::confirm $msg]} return
    ::tkutils::tkunotes::delete $S(w) $cur $cascade
    markDirty; updateStatus
}

proc ::notesapp::cmdMoveToRoot {} {
    variable S
    set cur [::tkutils::tkunotes::current $S(w)]
    if {$cur eq ""} return
    ::tkutils::tkunotes::move $S(w) $cur ""
    markDirty; updateStatus
}

# Candidate parents for moving $cur: every note except $cur and its descendants.
proc ::notesapp::candidates {cur} {
    variable S
    set store [::tkutils::tkunotes::store $S(w)]
    set blocked [concat [list $cur] [::tclutils::tunotes::descendants $store $cur]]
    set out {}
    foreach id [::tclutils::tunotes::ids $store] {
        if {$id ni $blocked} { lappend out $id }
    }
    return $out
}

proc ::notesapp::cmdMoveUnder {} {
    variable S
    set cur [::tkutils::tkunotes::current $S(w)]
    if {$cur eq ""} {
        ::tkutils::tkudialog::showWarning "No note selected."
        return
    }
    set target [moveDialog $cur]
    if {$target eq "__cancel__"} return
    if {[catch {::tkutils::tkunotes::move $S(w) $cur $target} err]} {
        ::tkutils::tkudialog::showError "Move failed:\n$err"
        return
    }
    markDirty; updateStatus
}

# Modal chooser: returns a target id, "" (root) or "__cancel__".
proc ::notesapp::moveDialog {cur} {
    variable S
    set store [::tkutils::tkunotes::store $S(w)]
    set ids [candidates $cur]
    set top .movedlg
    catch {destroy $top}
    toplevel $top
    wm title $top "Move under..."
    wm transient $top .
    ttk::label $top.l -text "Choose a new parent:" -padding 6
    pack $top.l -side top -anchor w
    set lb [listbox $top.lb -height 12 -width 50 \
        -yscrollcommand [list $top.ys set]]
    ttk::scrollbar $top.ys -orient vertical -command [list $lb yview]
    pack $top.ys -side right -fill y
    pack $lb -side top -fill both -expand 1 -padx 6

    # index 0 = root, then candidates (indented by depth)
    set map [list ""]
    $lb insert end "(root)"
    foreach id $ids {
        set depth [expr {[llength [::tclutils::tunotes::path $store $id]] - 1}]
        set title [dict get [::tclutils::tunotes::get $store $id] title]
        $lb insert end "[string repeat {    } $depth]$title"
        lappend map $id
    }
    $lb selection set 0

    set ::notesapp::_moveResult __cancel__
    set bf [ttk::frame $top.bf -padding 6]
    ttk::button $bf.ok -text "OK" -command [list ::notesapp::_movePick $top $lb $map]
    ttk::button $bf.cancel -text "Cancel" -command [list set ::notesapp::_moveResult __cancel__]
    pack $bf.cancel $bf.ok -side right -padx 2
    pack $bf -side bottom -fill x
    bind $lb <Double-1> [list ::notesapp::_movePick $top $lb $map]
    bind $top <Escape> [list set ::notesapp::_moveResult __cancel__]

    grab $top
    tkwait variable ::notesapp::_moveResult
    catch {grab release $top}
    catch {destroy $top}
    return $::notesapp::_moveResult
}
proc ::notesapp::_movePick {top lb map} {
    set sel [$lb curselection]
    if {$sel eq ""} { set sel 0 }
    set ::notesapp::_moveResult [lindex $map $sel]
}

proc ::notesapp::cmdExpand {open} {
    variable S
    set tv [::tkutils::tkunotes::treeWidget $S(w)]
    foreach it [_allItems $tv {}] { $tv item $it -open $open }
}
proc ::notesapp::_allItems {tv node} {
    set acc {}
    foreach c [$tv children $node] {
        lappend acc $c
        lappend acc {*}[_allItems $tv $c]
    }
    return $acc
}

proc ::notesapp::cmdRefresh {} {
    variable S
    ::tkutils::tkunotes::refresh $S(w)
    updateStatus
}

# --- file handling ---

proc ::notesapp::cmdNew {} {
    variable S
    if {![_confirmDiscard]} return
    ::tkutils::tkunotes::load $S(w) ""   ;# missing file -> empty store
    set S(file) ""
    clearDirty; updateStatus
}

proc ::notesapp::cmdOpen {{file ""}} {
    variable S
    if {![_confirmDiscard]} return
    if {$file eq ""} {
        set file [tk_getOpenFile -title "Open notes" \
            -filetypes {{JSON {.json}} {All *}}]
    }
    if {$file eq ""} return
    if {[catch {::tkutils::tkunotes::load $S(w) $file} err]} {
        ::tkutils::tkudialog::showError "Could not open:\n$err"
        return
    }
    set S(file) $file
    clearDirty; updateStatus
}

proc ::notesapp::cmdSave {} {
    variable S
    ::tkutils::tkunotes::commit $S(w)   ;# flush the editor into the store first
    if {$S(file) eq ""} { return [cmdSaveAs] }
    if {[catch {::tkutils::tkunotes::save $S(w) $S(file)} err]} {
        ::tkutils::tkudialog::showError "Could not save:\n$err"
        return
    }
    clearDirty
    catch {::tkutils::tkustatus::flash $S(status) "Saved [file tail $S(file)]." 2500}
    updateStatus
}

proc ::notesapp::cmdSaveAs {{file ""}} {
    variable S
    if {$file eq ""} {
        set file [tk_getSaveFile -title "Save notes as" -defaultextension .json \
            -filetypes {{JSON {.json}} {All *}}]
    }
    if {$file eq ""} return
    set S(file) $file
    cmdSave
}

proc ::notesapp::cmdExit {} {
    if {![_confirmDiscard]} return
    exit
}

proc ::notesapp::_confirmDiscard {} {
    variable S
    if {!$S(dirty)} { return 1 }
    return [::tkutils::tkudialog::confirm \
        "There are unsaved changes. Discard them?"]
}

# =============================================================================
# Build the GUI only when run as the main script.
# =============================================================================
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    ::notesapp::buildApp .
    if {[llength $argv] > 0} { ::notesapp::cmdOpen [lindex $argv 0] }
    vwait forever
}
