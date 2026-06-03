# tkutils::tkeditor -- simple text editor
#
# Editable text widget with file load/save, search, and modified tracking.
# File I/O goes through the tclutils common helpers. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::common 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkeditor {
    namespace export widget setText getText loadFile saveFile find isModified \
        currentFile selectAll menuWidget addMenuItem addMenuSeparator \
        findNext findAll replace highlightAll clearHighlight gotoLine cursor \
        readonly
    variable state
}

proc ::tkutils::tkeditor::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the editor under $path. Options: -width N -height N -wrap mode.
proc ::tkutils::tkeditor::widget {path args} {
    variable state
    array set opts {-width 80 -height 24 -wrap none}
    array set opts $args

    ttk::frame $path
    set state($path,file) ""
    bind $path <Destroy> [list ::tkutils::tkeditor::_cleanup $path %W]

    text $path.t -width $opts(-width) -height $opts(-height) \
        -wrap $opts(-wrap) -undo 1
    ttk::scrollbar $path.ys -orient vertical -command [list $path.t yview]
    ttk::scrollbar $path.xs -orient horizontal -command [list $path.t xview]
    $path.t configure -yscrollcommand [list $path.ys set] \
        -xscrollcommand [list $path.xs set]
    grid $path.t $path.ys -sticky nsew
    grid $path.xs -sticky ew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    # right-click context menu (the editor's menu system)
    menu $path.ctx -tearoff 0 \
        -postcommand [list ::tkutils::tkeditor::_updateMenu $path]
    $path.ctx add command -label "Undo" \
        -command [list ::tkutils::tkeditor::_edit $path undo]
    $path.ctx add command -label "Redo" \
        -command [list ::tkutils::tkeditor::_edit $path redo]
    $path.ctx add separator
    $path.ctx add command -label "Cut" \
        -command [list ::tkutils::tkeditor::_event $path <<Cut>>]
    $path.ctx add command -label "Copy" \
        -command [list ::tkutils::tkeditor::_event $path <<Copy>>]
    $path.ctx add command -label "Paste" \
        -command [list ::tkutils::tkeditor::_event $path <<Paste>>]
    $path.ctx add command -label "Delete" \
        -command [list ::tkutils::tkeditor::_deleteSel $path]
    $path.ctx add separator
    $path.ctx add command -label "Select All" \
        -command [list ::tkutils::tkeditor::selectAll $path]
    bind $path.t <Button-3> [list ::tkutils::tkeditor::_popup $path %X %Y]

    return $path
}

# Replace the whole buffer. Resets the modified flag and undo history.
# Works even when the editor is read-only (temporarily re-enabled).
proc ::tkutils::tkeditor::setText {path text} {
    set t $path.t
    set ro [expr {[$t cget -state] eq "disabled"}]
    if {$ro} { $t configure -state normal }
    $t delete 1.0 end
    $t insert end $text
    $t edit reset
    $t edit modified 0
    if {$ro} { $t configure -state disabled }
    return [string length $text]
}

# Return the buffer contents (without the text widget's trailing newline).
proc ::tkutils::tkeditor::getText {path} {
    return [$path.t get 1.0 end-1c]
}

proc ::tkutils::tkeditor::loadFile {path filename} {
    variable state
    setText $path [::tclutils::common::readFile $filename]
    set state($path,file) $filename
    return $filename
}

# Save to the given file, or to the current file if none is given.
proc ::tkutils::tkeditor::saveFile {path args} {
    variable state
    if {[llength $args] >= 1} {
        set fn [lindex $args 0]
    } else {
        set fn $state($path,file)
    }
    if {$fn eq ""} {
        return -code error -errorcode {TKUTILS TKEDITOR NOFILE} \
            "no filename given and no current file"
    }
    ::tclutils::common::writeFile $fn [getText $path]
    set state($path,file) $fn
    $path.t edit modified 0
    return $fn
}

proc ::tkutils::tkeditor::currentFile {path} {
    variable state
    return $state($path,file)
}

# Search for $needle. Options: -from idx (default 1.0), -nocase.
# Returns the start index (e.g. "3.5") or "" if not found.
proc ::tkutils::tkeditor::find {path needle args} {
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
proc ::tkutils::tkeditor::findAll {path needle args} {
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
proc ::tkutils::tkeditor::findNext {path needle args} {
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
    return $m
}

# Replace occurrences of $needle with $repl. Options: -nocase, -all (default is
# the first match only), -from idx (default 1.0). One undo step. Returns the
# number of replacements. The scan resumes past each replacement, so a $repl
# that contains $needle is not re-matched.
proc ::tkutils::tkeditor::replace {path needle repl args} {
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
    return $count
}

# Tag every match of $needle for visual highlighting. Options: -nocase,
# -tag NAME (default "match"). Returns the number of matches. The tag is given a
# default background the first time; callers may restyle it via the text widget.
proc ::tkutils::tkeditor::highlightAll {path needle args} {
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
proc ::tkutils::tkeditor::clearHighlight {path args} {
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
# Returns the resulting insert index ("line.col").
proc ::tkutils::tkeditor::gotoLine {path n} {
    set t $path.t
    if {![string is integer -strict $n] || $n < 1} {
        return -code error -errorcode {TKUTILS TKEDITOR LINE} \
            "line must be a positive integer: $n"
    }
    set idx [$t index $n.0]
    $t mark set insert $idx
    $t see $idx
    return [$t index insert]
}

# Current cursor position as "line.col".
proc ::tkutils::tkeditor::cursor {path} {
    return [$path.t index insert]
}

# Get or set read-only mode. With no argument returns 1/0; with a boolean it
# enables/disables editing (programmatic setText/loadFile still work).
proc ::tkutils::tkeditor::readonly {path args} {
    set t $path.t
    if {[llength $args] == 0} {
        return [expr {[$t cget -state] eq "disabled"}]
    }
    set on [expr {[lindex $args 0] ? 1 : 0}]
    $t configure -state [expr {$on ? "disabled" : "normal"}]
    return $on
}

proc ::tkutils::tkeditor::isModified {path} {
    return [$path.t edit modified]
}

# Return the context-menu widget so callers can add their own entries.
proc ::tkutils::tkeditor::menuWidget {path} {
    return $path.ctx
}

# Convenience: append a command entry to the context menu.
proc ::tkutils::tkeditor::addMenuItem {path label command} {
    $path.ctx add command -label $label -command $command
    return $path.ctx
}

proc ::tkutils::tkeditor::addMenuSeparator {path} {
    $path.ctx add separator
    return $path.ctx
}

# Select the whole buffer. Returns 1.
proc ::tkutils::tkeditor::selectAll {path} {
    set t $path.t
    $t tag remove sel 1.0 end
    $t tag add sel 1.0 end-1c
    return 1
}

proc ::tkutils::tkeditor::_popup {path X Y} {
    tk_popup $path.ctx $X $Y
}

proc ::tkutils::tkeditor::_edit {path op} {
    catch {$path.t edit $op}
}

proc ::tkutils::tkeditor::_event {path ev} {
    event generate $path.t $ev
}

proc ::tkutils::tkeditor::_deleteSel {path} {
    catch {$path.t delete sel.first sel.last}
}

# Enable selection-dependent items only when there is a selection.
proc ::tkutils::tkeditor::_updateMenu {path} {
    set st [expr {[$path.t tag ranges sel] ne "" ? "normal" : "disabled"}]
    foreach lbl {Cut Copy Delete} {
        catch {$path.ctx entryconfigure $lbl -state $st}
    }
}

package provide tkutils::tkeditor 0.1
