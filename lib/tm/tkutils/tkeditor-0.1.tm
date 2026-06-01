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
        currentFile selectAll menuWidget addMenuItem addMenuSeparator
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
proc ::tkutils::tkeditor::setText {path text} {
    set t $path.t
    $t delete 1.0 end
    $t insert end $text
    $t edit reset
    $t edit modified 0
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
