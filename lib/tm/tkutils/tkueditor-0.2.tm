# tkutils::tkueditor -- text editor widget (v0.2 PROTOTYPE)
# Description: text editor widget (v0.2 PROTOTYPE)
# Category: Tk · widgets
#
# Editable text widget with file load/save, search, modified tracking, an
# optional toolbar and an optional status bar. File I/O goes through the
# tclutils common helpers. Tcl/Tk 8.6+ and 9.x.
#
# v0.2 (PROPOSAL -- additive over 0.1; the whole 0.1 API is unchanged):
#   widget ... ?-toolbar bool? ?-statusbar bool? ?-encoding ENC?  (bars on,
#                                                                  ENC utf-8)
#   toolbarWidget   $w        -> the tkutoolbar path ("" if disabled)
#   statusbarWidget $w        -> the tkustatus  path ("" if disabled)
#   setStatus       $w text   -> set the status bar's main message
#   refreshStatus   $w        -> recompute position/modified/encoding fields
#   loadFile $w path ?-encoding ENC?   saveFile $w ?path? ?-encoding ENC? ?-eol S?
#   encoding $w ?ENC?         -> get/set the encoding used by load/save
#   eol      $w ?lf|crlf?     -> get/set the line-ending style for save
# The toolbar reuses tkutils::tkutoolbar (+ tkuicon icons, text fallback);
# the status bar reuses tkutils::tkustatus. Both are built only when enabled,
# so the bare widget keeps its light dependency set. Encoding conversion uses
# tclutils::tuiconv (default utf-8) for identical behaviour under Tcl 8.6 and
# 9.x; line endings are normalised to LF in the buffer and restored on save.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuiconv

namespace eval ::tkutils {}
namespace eval ::tkutils::tkueditor {
    namespace export widget setText getText loadFile saveFile find isModified \
        currentFile selectAll menuWidget addMenuItem addMenuSeparator \
        findNext findAll replace highlightAll clearHighlight gotoLine cursor \
        readonly toolbarWidget statusbarWidget setStatus refreshStatus encoding eol
    variable state
}

proc ::tkutils::tkueditor::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the editor under $path.
# Options: -width N -height N -wrap mode -toolbar bool -statusbar bool
#          -encoding ENC (default utf-8; the encoding used by loadFile/saveFile).
proc ::tkutils::tkueditor::widget {path args} {
    variable state
    array set opts {-width 80 -height 24 -wrap none -toolbar 1 -statusbar 1 \
        -encoding utf-8 -eol lf}
    array set opts $args

    ttk::frame $path
    set state($path,file)      ""
    set state($path,encoding)  $opts(-encoding)
    set state($path,eol)       $opts(-eol)
    set state($path,toolbar)   ""
    set state($path,statusbar) ""
    bind $path <Destroy> [list ::tkutils::tkueditor::_cleanup $path %W]

    text $path.t -width $opts(-width) -height $opts(-height) \
        -wrap $opts(-wrap) -undo 1
    ttk::scrollbar $path.ys -orient vertical   -command [list $path.t yview]
    ttk::scrollbar $path.xs -orient horizontal -command [list $path.t xview]
    $path.t configure -yscrollcommand [list $path.ys set] \
        -xscrollcommand [list $path.xs set]

    # Layout: toolbar (row 0) / text+yscroll (row 1) / xscroll (row 2) /
    # statusbar (row 3). The text row is the one that expands.
    if {$opts(-toolbar)} { _buildToolbar $path }
    grid $path.t  -row 1 -column 0 -sticky nsew
    grid $path.ys -row 1 -column 1 -sticky ns
    grid $path.xs -row 2 -column 0 -sticky ew
    if {$opts(-statusbar)} { _buildStatusbar $path }
    grid rowconfigure    $path 1 -weight 1
    grid columnconfigure $path 0 -weight 1

    # right-click context menu (the editor's menu system)
    menu $path.ctx -tearoff 0 \
        -postcommand [list ::tkutils::tkueditor::_updateMenu $path]
    $path.ctx add command -label "Undo" \
        -command [list ::tkutils::tkueditor::_edit $path undo]
    $path.ctx add command -label "Redo" \
        -command [list ::tkutils::tkueditor::_edit $path redo]
    $path.ctx add separator
    $path.ctx add command -label "Cut" \
        -command [list ::tkutils::tkueditor::_event $path <<Cut>>]
    $path.ctx add command -label "Copy" \
        -command [list ::tkutils::tkueditor::_event $path <<Copy>>]
    $path.ctx add command -label "Paste" \
        -command [list ::tkutils::tkueditor::_event $path <<Paste>>]
    $path.ctx add command -label "Delete" \
        -command [list ::tkutils::tkueditor::_deleteSel $path]
    $path.ctx add separator
    $path.ctx add command -label "Select All" \
        -command [list ::tkutils::tkueditor::selectAll $path]
    bind $path.t <Button-3> [list ::tkutils::tkueditor::_popup $path %X %Y]

    # keep the status bar and toolbar button states in sync with cursor,
    # selection, modified state and undo/redo availability
    if {$state($path,toolbar) ne "" || $state($path,statusbar) ne ""} {
        foreach ev {<KeyRelease> <ButtonRelease-1> <<Selection>> <<Modified>>} {
            bind $path.t $ev +[list ::tkutils::tkueditor::_sync $path]
        }
        _sync $path
    }
    return $path
}

# Refresh both the status bar and the toolbar button states. Each part is a
# no-op when that piece is absent, so this is safe with either bar disabled.
proc ::tkutils::tkueditor::_sync {path} {
    catch {refreshStatus $path}
    catch {_updateToolbar $path}
}

# Enable/disable the toolbar's edit buttons to match the current state:
# Undo/Redo follow the text widget's undo stack, Cut/Copy follow the selection.
proc ::tkutils::tkueditor::_updateToolbar {path} {
    variable state
    set tb $state($path,toolbar)
    if {$tb eq "" || ![winfo exists $tb]} { return "" }
    set t $path.t
    ::tkutils::tkutoolbar::setEnabled $tb undo [$t edit canundo]
    ::tkutils::tkutoolbar::setEnabled $tb redo [$t edit canredo]
    set hasSel [expr {[$t tag ranges sel] ne ""}]
    ::tkutils::tkutoolbar::setEnabled $tb cut  $hasSel
    ::tkutils::tkutoolbar::setEnabled $tb copy $hasSel
    return ""
}

# --- toolbar -------------------------------------------------------------

# Load a built-in icon as a 16px image, or "" when SVG support / tkuicon is
# unavailable (the toolbar then falls back to text labels).
proc ::tkutils::tkueditor::_loadIcon {name} {
    if {[catch {package require tkutils::tkuicon}]} { return "" }
    if {[catch {::tkutils::tkuicon::create $name 16} img]} { return "" }
    return $img
}

# Build the toolbar (tkutoolbar) with the editor's standard actions. Icons are
# loaded via tkuicon when SVG support is present; otherwise the buttons fall
# back to their text labels, so the toolbar always works.
proc ::tkutils::tkueditor::_buildToolbar {path} {
    variable state
    package require tkutils::tkutoolbar
    set tb $path.tb
    ::tkutils::tkutoolbar::widget $tb -displaymode both
    set state($path,toolbar) $tb

    # icon name (tkuicon/tusvg) -> "" when unavailable
    set ico_open  [_loadIcon folder]
    set ico_save  [_loadIcon save]
    set ico_undo  [_loadIcon undo]
    set ico_redo  [_loadIcon redo]
    set ico_cut   [_loadIcon cut]
    set ico_copy  [_loadIcon copy]
    set ico_find  [_loadIcon search]

    ::tkutils::tkutoolbar::addButton $tb open "Open" \
        [list ::tkutils::tkueditor::_tbOpen $path] -icon $ico_open -tooltip "Open file"
    ::tkutils::tkutoolbar::addButton $tb save "Save" \
        [list ::tkutils::tkueditor::_tbSave $path] -icon $ico_save -tooltip "Save file"
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb undo "Undo" \
        [list ::tkutils::tkueditor::_edit $path undo] -icon $ico_undo -tooltip "Undo"
    ::tkutils::tkutoolbar::addButton $tb redo "Redo" \
        [list ::tkutils::tkueditor::_edit $path redo] -icon $ico_redo -tooltip "Redo"
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb cut "Cut" \
        [list ::tkutils::tkueditor::_event $path <<Cut>>] -icon $ico_cut -tooltip "Cut"
    ::tkutils::tkutoolbar::addButton $tb copy "Copy" \
        [list ::tkutils::tkueditor::_event $path <<Copy>>] -icon $ico_copy -tooltip "Copy"
    ::tkutils::tkutoolbar::addSeparator $tb

    # incremental find: an entry plus a "Find" button, both calling findNext
    set fe $tb.find
    ttk::entry $fe -width 18
    bind $fe <Return> [list ::tkutils::tkueditor::_tbFind $path]
    ::tkutils::tkutoolbar::addWidget $tb findentry $fe left
    ::tkutils::tkutoolbar::addButton $tb find "Find" \
        [list ::tkutils::tkueditor::_tbFind $path] -icon $ico_find -tooltip "Find next"

    grid $tb -row 0 -column 0 -columnspan 2 -sticky ew
}

proc ::tkutils::tkueditor::_tbOpen {path} {
    set fn [tk_getOpenFile -parent $path]
    if {$fn ne ""} { loadFile $path $fn; refreshStatus $path }
}

proc ::tkutils::tkueditor::_tbSave {path} {
    variable state
    set fn $state($path,file)
    if {$fn eq ""} { set fn [tk_getSaveFile -parent $path] }
    if {$fn ne ""} { saveFile $path $fn; refreshStatus $path }
}

proc ::tkutils::tkueditor::_tbFind {path} {
    variable state
    set tb $state($path,toolbar)
    if {$tb eq "" || ![winfo exists $tb.find]} return
    set needle [$tb.find get]
    if {$needle ne ""} { findNext $path $needle }
}

# Return the toolbar widget (a tkutoolbar) so callers can add their own
# buttons via ::tkutils::tkutoolbar::addButton, or "" when there is none.
proc ::tkutils::tkueditor::toolbarWidget {path} {
    variable state
    return $state($path,toolbar)
}

# --- status bar ----------------------------------------------------------

proc ::tkutils::tkueditor::_buildStatusbar {path} {
    variable state
    package require tkutils::tkustatus
    set sb $path.sb
    ::tkutils::tkustatus::widget $sb
    ::tkutils::tkustatus::addField $sb mod -width 9
    ::tkutils::tkustatus::addField $sb enc -width 10
    ::tkutils::tkustatus::addField $sb eol -width 6
    ::tkutils::tkustatus::addField $sb pos -width 16
    set state($path,statusbar) $sb
    grid $sb -row 3 -column 0 -columnspan 2 -sticky ew
}

# Return the status bar widget (a tkustatus), or "" when there is none.
proc ::tkutils::tkueditor::statusbarWidget {path} {
    variable state
    return $state($path,statusbar)
}

# Set the status bar's main (left, expanding) message. No-op without a bar.
proc ::tkutils::tkueditor::setStatus {path text} {
    variable state
    if {$state($path,statusbar) ne ""} {
        ::tkutils::tkustatus::setText $state($path,statusbar) $text
    }
    return $text
}

# Recompute the position / modified fields. Called from the editing bindings;
# safe to call when there is no status bar. The main (left) message is left to
# the application via setStatus; loadFile/saveFile show the file name there.
proc ::tkutils::tkueditor::refreshStatus {path} {
    variable state
    set sb $state($path,statusbar)
    if {$sb eq "" || ![winfo exists $sb]} { return "" }
    lassign [split [$path.t index insert] .] line col
    ::tkutils::tkustatus::setField $sb pos "Ln $line, Col $col"
    ::tkutils::tkustatus::setField $sb mod \
        [expr {[$path.t edit modified] ? "modified" : ""}]
    ::tkutils::tkustatus::setField $sb enc $state($path,encoding)
    ::tkutils::tkustatus::setField $sb eol \
        [expr {$state($path,eol) eq "crlf" ? "CRLF" : "LF"}]
    return ""
}

# --- buffer / file (unchanged from 0.1) ----------------------------------

# Replace the whole buffer. Resets the modified flag and undo history.
# Works even when the editor is read-only (temporarily re-enabled).
proc ::tkutils::tkueditor::setText {path text} {
    set t $path.t
    set ro [expr {[$t cget -state] eq "disabled"}]
    if {$ro} { $t configure -state normal }
    $t delete 1.0 end
    $t insert end $text
    $t mark set insert 1.0
    $t see 1.0
    $t edit reset
    $t edit modified 0
    if {$ro} { $t configure -state disabled }
    catch {_sync $path}
    return [string length $text]
}

# Return the buffer contents (without the text widget's trailing newline).
proc ::tkutils::tkueditor::getText {path} {
    return [$path.t get 1.0 end-1c]
}

# Encoding-aware file I/O via the tclutils::tuiconv helpers. The editor defaults
# to utf-8 so a document loads and saves the same way under Tcl 8.6 (whose
# channels otherwise default to the system encoding -- cp1252 on Windows,
# latin-1 elsewhere) and Tcl 9 (utf-8). Encoding conversion uses the dedicated
# tclutils::tuiconv helpers (binary read/write + convertfrom/convertto). Because
# those do no end-of-line translation, the editor normalises line endings
# itself: on load CRLF/CR become LF (a Tk text widget wants LF), and the file's
# original style is remembered so save can restore it. Pass -encoding to
# override the encoding per call; both encoding and EOL style are remembered.

# Load $filename into the buffer. Option: -encoding ENC (default: the editor's
# current encoding). Detects and remembers the file's EOL style; the buffer is
# always LF-normalised. Remembers the file and its encoding.
proc ::tkutils::tkueditor::loadFile {path filename args} {
    variable state
    set enc $state($path,encoding)
    foreach {k v} $args {
        switch -- $k {
            -encoding { set enc $v }
            default {
                return -code error -errorcode {TKUTILS TKEDITOR OPT} \
                    "unknown option: $k"
            }
        }
    }
    set raw [::tclutils::tuiconv::readFile $filename $enc]
    # Remember the file's line-ending style, then normalise the buffer to LF.
    set state($path,eol) [expr {[string first "\r\n" $raw] >= 0 ? "crlf" : "lf"}]
    regsub -all {\r\n?} $raw "\n" raw
    setText $path $raw
    set state($path,file)     $filename
    set state($path,encoding) $enc
    catch {refreshStatus $path}
    setStatus $path [file tail $filename]
    return $filename
}

# Save the buffer. First non-option arg is the path (optional if loaded from a
# file); options -encoding ENC and -eol lf|crlf override the remembered values.
# The LF buffer is converted to the chosen EOL style before writing.
proc ::tkutils::tkueditor::saveFile {path args} {
    variable state
    set fn ""
    set enc $state($path,encoding)
    set eol $state($path,eol)
    set rest {}
    set i 0; set n [llength $args]
    while {$i < $n} {
        set a [lindex $args $i]
        switch -- $a {
            -encoding { set enc [lindex $args [expr {$i + 1}]]; incr i 2 }
            -eol      { set eol [lindex $args [expr {$i + 1}]]; incr i 2 }
            default   { lappend rest $a; incr i }
        }
    }
    if {[llength $rest] >= 1} {
        set fn [lindex $rest 0]
    } else {
        set fn $state($path,file)
    }
    if {$fn eq ""} {
        return -code error -errorcode {TKUTILS TKEDITOR NOFILE} \
            "no filename given and no current file"
    }
    set data [getText $path]
    if {$eol eq "crlf"} { set data [string map [list "\n" "\r\n"] $data] }
    ::tclutils::tuiconv::writeFile $fn $data $enc
    set state($path,file)     $fn
    set state($path,encoding) $enc
    set state($path,eol)      $eol
    $path.t edit modified 0
    catch {refreshStatus $path}
    setStatus $path [file tail $fn]
    return $fn
}

proc ::tkutils::tkueditor::currentFile {path} {
    variable state
    return $state($path,file)
}

# Get or set the editor's encoding. With no argument returns the current
# encoding; with one argument sets it (used by the next load/save) and updates
# the status bar.
proc ::tkutils::tkueditor::encoding {path args} {
    variable state
    if {[llength $args] == 0} {
        return $state($path,encoding)
    }
    set state($path,encoding) [lindex $args 0]
    catch {refreshStatus $path}
    return $state($path,encoding)
}

# Get or set the buffer's line-ending style for the next save ("lf" or "crlf").
proc ::tkutils::tkueditor::eol {path args} {
    variable state
    if {[llength $args] == 0} {
        return $state($path,eol)
    }
    set s [lindex $args 0]
    if {$s ni {lf crlf}} {
        return -code error -errorcode {TKUTILS TKEDITOR EOL} \
            "eol must be lf or crlf: $s"
    }
    set state($path,eol) $s
    catch {refreshStatus $path}
    return $s
}

# --- search / replace / highlight (unchanged from 0.1) -------------------

# Search for $needle. Options: -from idx (default 1.0), -nocase.
# Returns the start index (e.g. "3.5") or "" if not found.
proc ::tkutils::tkueditor::find {path needle args} {
    set from 1.0
    set flags {}
    set i 0
    set n [llength $args]
    while {$i < $n} {
        set k [lindex $args $i]
        switch -- $k {
            -nocase { lappend flags -nocase; incr i }
            -from   { set from [lindex $args [expr {$i + 1}]]; incr i 2 }
            default {
                return -code error -errorcode {TKUTILS TKEDITOR OPT} \
                    "unknown option: $k"
            }
        }
    }
    return [$path.t search {*}$flags -- $needle $from end]
}

# All match start indices for $needle, in document order. Options: -nocase.
proc ::tkutils::tkueditor::findAll {path needle args} {
    set flags {}
    foreach a $args {
        if {$a eq "-nocase"} { lappend flags -nocase } else {
            return -code error -errorcode {TKUTILS TKEDITOR OPT} "unknown option: $a"
        }
    }
    set t $path.t
    if {$needle eq ""} { return {} }
    set res {}
    set idx 1.0
    while {1} {
        set m [$t search {*}$flags -count cnt -- $needle $idx end]
        if {$m eq ""} break
        lappend res $m
        set step [expr {$cnt > 0 ? $cnt : 1}]
        set idx [$t index "$m + $step chars"]
    }
    return $res
}

# Interactive forward search from the cursor, wrapping to the top. On a hit the
# match is selected, the insert mark is moved past it and it is scrolled into
# view; returns the start index (so repeated calls walk through the matches), or
# "" if there is no match anywhere. Options: -nocase.
proc ::tkutils::tkueditor::findNext {path needle args} {
    set flags {}
    foreach a $args {
        if {$a eq "-nocase"} { lappend flags -nocase } else {
            return -code error -errorcode {TKUTILS TKEDITOR OPT} "unknown option: $a"
        }
    }
    set t $path.t
    if {$needle eq ""} { return "" }
    set m [$t search {*}$flags -count cnt -- $needle insert end]
    if {$m eq ""} {
        set m [$t search {*}$flags -count cnt -- $needle 1.0 end]
    }
    if {$m eq ""} { return "" }
    set end [$t index "$m + $cnt chars"]
    $t tag remove sel 1.0 end
    $t tag add sel $m $end
    $t mark set insert $end
    $t see $m
    catch {refreshStatus $path}
    return $m
}

# Replace occurrences of $needle with $repl. Options: -nocase, -all (default is
# the first match only), -from idx (default 1.0). One undo step. Returns the
# number of replacements. The scan resumes past each replacement, so a $repl
# that contains $needle is not re-matched.
proc ::tkutils::tkueditor::replace {path needle repl args} {
    set flags {}; set all 0; set from 1.0
    set i 0; set n [llength $args]
    while {$i < $n} {
        switch -- [lindex $args $i] {
            -nocase { lappend flags -nocase; incr i }
            -all    { set all 1; incr i }
            -from   { set from [lindex $args [expr {$i + 1}]]; incr i 2 }
            default {
                return -code error -errorcode {TKUTILS TKEDITOR OPT} \
                    "unknown option: [lindex $args $i]"
            }
        }
    }
    set t $path.t
    if {$needle eq ""} { return 0 }
    set count 0
    set idx $from
    $t edit separator
    while {1} {
        set m [$t search {*}$flags -count cnt -- $needle $idx end]
        if {$m eq "" || $cnt == 0} break
        set end [$t index "$m + $cnt chars"]
        $t delete $m $end
        $t insert $m $repl
        incr count
        set idx [$t index "$m + [string length $repl] chars"]
        if {!$all} break
    }
    $t edit separator
    catch {refreshStatus $path}
    return $count
}

# Tag every match of $needle for visual highlighting. Options: -nocase,
# -tag NAME (default "match"). Returns the number of matches.
proc ::tkutils::tkueditor::highlightAll {path needle args} {
    set flags {}; set tag match
    set i 0; set n [llength $args]
    while {$i < $n} {
        switch -- [lindex $args $i] {
            -nocase { lappend flags -nocase; incr i }
            -tag    { set tag [lindex $args [expr {$i + 1}]]; incr i 2 }
            default {
                return -code error -errorcode {TKUTILS TKEDITOR OPT} \
                    "unknown option: [lindex $args $i]"
            }
        }
    }
    set t $path.t
    $t tag remove $tag 1.0 end
    $t tag configure $tag -background "#fff2a8"
    if {$needle eq ""} { return 0 }
    set count 0
    set idx 1.0
    while {1} {
        set m [$t search {*}$flags -count cnt -- $needle $idx end]
        if {$m eq ""} break
        set step [expr {$cnt > 0 ? $cnt : 1}]
        $t tag add $tag $m "$m + $step chars"
        incr count
        set idx [$t index "$m + $step chars"]
    }
    return $count
}

# Remove a highlight tag's ranges (default tag "match"). Option: -tag NAME.
proc ::tkutils::tkueditor::clearHighlight {path args} {
    set tag match
    set i 0; set n [llength $args]
    while {$i < $n} {
        switch -- [lindex $args $i] {
            -tag    { set tag [lindex $args [expr {$i + 1}]]; incr i 2 }
            default {
                return -code error -errorcode {TKUTILS TKEDITOR OPT} \
                    "unknown option: [lindex $args $i]"
            }
        }
    }
    $path.t tag remove $tag 1.0 end
    return 1
}

# Move the cursor to the start of line $n and scroll it into view.
proc ::tkutils::tkueditor::gotoLine {path n} {
    set t $path.t
    if {![string is integer -strict $n] || $n < 1} {
        return -code error -errorcode {TKUTILS TKEDITOR LINE} \
            "line must be a positive integer: $n"
    }
    set idx [$t index $n.0]
    $t mark set insert $idx
    $t see $idx
    catch {refreshStatus $path}
    return [$t index insert]
}

# Current cursor position as "line.col".
proc ::tkutils::tkueditor::cursor {path} {
    return [$path.t index insert]
}

# Get or set read-only mode.
proc ::tkutils::tkueditor::readonly {path args} {
    set t $path.t
    if {[llength $args] == 0} {
        return [expr {[$t cget -state] eq "disabled"}]
    }
    set on [expr {[lindex $args 0] ? 1 : 0}]
    $t configure -state [expr {$on ? "disabled" : "normal"}]
    return $on
}

proc ::tkutils::tkueditor::isModified {path} {
    return [$path.t edit modified]
}

# --- context menu (unchanged from 0.1) -----------------------------------

proc ::tkutils::tkueditor::menuWidget {path} {
    return $path.ctx
}

proc ::tkutils::tkueditor::addMenuItem {path label command} {
    $path.ctx add command -label $label -command $command
    return $path.ctx
}

proc ::tkutils::tkueditor::addMenuSeparator {path} {
    $path.ctx add separator
    return $path.ctx
}

# Select the whole buffer. Returns 1.
proc ::tkutils::tkueditor::selectAll {path} {
    set t $path.t
    $t tag remove sel 1.0 end
    $t tag add sel 1.0 end-1c
    return 1
}

proc ::tkutils::tkueditor::_popup {path X Y} {
    tk_popup $path.ctx $X $Y
}

proc ::tkutils::tkueditor::_edit {path op} {
    catch {$path.t edit $op}
    catch {_sync $path}
}

proc ::tkutils::tkueditor::_event {path ev} {
    event generate $path.t $ev
}

proc ::tkutils::tkueditor::_deleteSel {path} {
    catch {$path.t delete sel.first sel.last}
}

# Enable selection-dependent items only when there is a selection.
proc ::tkutils::tkueditor::_updateMenu {path} {
    set st [expr {[$path.t tag ranges sel] ne "" ? "normal" : "disabled"}]
    foreach lbl {Cut Copy Delete} {
        catch {$path.ctx entryconfigure $lbl -state $st}
    }
}

package provide tkutils::tkueditor 0.2
