# tkutils::tkuini -- INI viewer
# Description: INI viewer
# Category: Tk · widgets
#
# A two-pane view of an INI document: a list of sections on the left and the
# key/value pairs of the selected section on the right. The global section ""
# is shown as "(global)". Built on the tclutils tuini engine (requires tclutils
# 0.32.0+). Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuini 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuini {
    namespace export widget loadText loadFile setData data sections \
        selectSection currentSection treeWidget sectionWidget count \
        setKey removeKey addSection removeSection toText save
    variable state
}

proc ::tkutils::tkuini::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkuini::widget {path args} {
    variable state
    array set o {-editable 1}
    array set o $args
    ttk::frame $path
    set state($path,data) [dict create]
    set state($path,cur) ""
    set state($path,editable) $o(-editable)
    set state($path,ekey) ""
    set state($path,eval) ""
    set state($path,esec) ""
    bind $path <Destroy> [list ::tkutils::tkuini::_cleanup $path %W]

    set pw $path.pw
    ttk::panedwindow $pw -orient horizontal

    ttk::frame $pw.lf
    set sec $pw.lf.tv
    ttk::treeview $sec -show tree -yscrollcommand [list $pw.lf.ys set]
    ttk::scrollbar $pw.lf.ys -orient vertical -command [list $sec yview]
    grid $sec $pw.lf.ys -sticky nsew
    grid rowconfigure $pw.lf 0 -weight 1
    grid columnconfigure $pw.lf 0 -weight 1

    ttk::frame $pw.rf
    set kv $pw.rf.tv
    ttk::treeview $kv -columns {value} -yscrollcommand [list $pw.rf.ys set]
    $kv heading #0 -text "Key"
    $kv heading value -text "Value"
    $kv column #0 -width 160 -anchor w
    $kv column value -width 300 -anchor w
    ttk::scrollbar $pw.rf.ys -orient vertical -command [list $kv yview]
    grid $kv $pw.rf.ys -sticky nsew
    grid rowconfigure $pw.rf 0 -weight 1
    grid columnconfigure $pw.rf 0 -weight 1

    $pw add $pw.lf -weight 1
    $pw add $pw.rf -weight 2

    if {$state($path,editable)} {
        set eb $path.eb
        ttk::frame $eb
        ttk::label $eb.sl -text "Section:"
        ttk::entry $eb.se -width 12 -textvariable ::tkutils::tkuini::state($path,esec)
        ttk::button $eb.sa -text "Add Sec" -command [list ::tkutils::tkuini::_uiAddSection $path]
        ttk::button $eb.sd -text "Del Sec" -command [list ::tkutils::tkuini::_uiDelSection $path]
        ttk::separator $eb.sep -orient vertical
        ttk::label $eb.kl -text "Key:"
        ttk::entry $eb.ke -width 14 -textvariable ::tkutils::tkuini::state($path,ekey)
        ttk::label $eb.vl -text "Value:"
        ttk::entry $eb.ve -width 20 -textvariable ::tkutils::tkuini::state($path,eval)
        ttk::button $eb.set -text "Set" -command [list ::tkutils::tkuini::_uiSet $path]
        ttk::button $eb.del -text "Delete" -command [list ::tkutils::tkuini::_uiDel $path]
        pack $eb.sl $eb.se $eb.sa $eb.sd $eb.sep $eb.kl $eb.ke $eb.vl $eb.ve \
            $eb.set $eb.del -side left -padx 2 -pady 3
        pack $eb.sep -fill y -padx 6
        pack $eb -side bottom -fill x
        bind $kv <<TreeviewSelect>> [list ::tkutils::tkuini::_fillEdit $path]
    }

    pack $pw -side top -fill both -expand 1

    bind $sec <<TreeviewSelect>> [list ::tkutils::tkuini::_onSelect $path]
    return $path
}

proc ::tkutils::tkuini::sectionWidget {path} { return $path.pw.lf.tv }
proc ::tkutils::tkuini::treeWidget {path}    { return $path.pw.rf.tv }

proc ::tkutils::tkuini::_label {section} {
    return [expr {$section eq "" ? "(global)" : $section}]
}

proc ::tkutils::tkuini::_populateSections {path} {
    variable state
    set sec [sectionWidget $path]
    $sec delete [$sec children {}]
    foreach k [array names state $path,item,*] { unset state($k) }
    foreach section [dict keys $state($path,data)] {
        set item [$sec insert {} end -text [_label $section]]
        set state($path,item,$item) $section
    }
}

proc ::tkutils::tkuini::_showSection {path section} {
    variable state
    set kv [treeWidget $path]
    $kv delete [$kv children {}]
    set state($path,cur) $section
    if {[dict exists $state($path,data) $section]} {
        dict for {k v} [dict get $state($path,data) $section] {
            $kv insert {} end -text $k -values [list $v]
        }
    }
}

proc ::tkutils::tkuini::_onSelect {path} {
    variable state
    set sec [sectionWidget $path]
    set item [lindex [$sec selection] 0]
    if {$item eq ""} return
    if {[info exists state($path,item,$item)]} {
        _showSection $path $state($path,item,$item)
    }
}

# Find the section-tree item that maps to a section name ("" if none).
proc ::tkutils::tkuini::_itemFor {path section} {
    variable state
    foreach k [array names state $path,item,*] {
        if {$state($k) eq $section} {
            return [string range $k [string length "$path,item,"] end]
        }
    }
    return ""
}

# Load INI text. Returns the number of sections.
proc ::tkutils::tkuini::loadText {path ini} {
    variable state
    set state($path,data) [::tclutils::tuini::parse $ini]
    _populateSections $path
    set first [lindex [dict keys $state($path,data)] 0]
    if {$first ne ""} {
        selectSection $path $first
    } elseif {[dict size $state($path,data)]} {
        selectSection $path ""
    }
    return [dict size $state($path,data)]
}

proc ::tkutils::tkuini::loadFile {path file} {
    set ch [open $file r]
    set txt [read $ch]
    close $ch
    return [loadText $path $txt]
}

# Display an already-parsed data dict.
proc ::tkutils::tkuini::setData {path d} {
    variable state
    set state($path,data) $d
    _populateSections $path
    return [dict size $d]
}

# Select a section by name and show its keys.
proc ::tkutils::tkuini::selectSection {path section} {
    set sec [sectionWidget $path]
    set item [_itemFor $path $section]
    if {$item ne ""} {
        $sec selection set $item
        $sec see $item
    }
    _showSection $path $section
    return $section
}

proc ::tkutils::tkuini::data {path} {
    variable state
    return $state($path,data)
}
proc ::tkutils::tkuini::sections {path} {
    variable state
    return [dict keys $state($path,data)]
}
proc ::tkutils::tkuini::currentSection {path} {
    variable state
    return $state($path,cur)
}
proc ::tkutils::tkuini::count {path} {
    variable state
    return [dict size $state($path,data)]
}

# --- editing ------------------------------------------------------------------

proc ::tkutils::tkuini::_reload {path} {
    variable state
    _populateSections $path
    set cur $state($path,cur)
    if {[dict exists $state($path,data) $cur]} {
        selectSection $path $cur
    } elseif {[dict size $state($path,data)]} {
        selectSection $path [lindex [dict keys $state($path,data)] 0]
    } else {
        _showSection $path ""
    }
}

# Set (or add) a key in a section.
proc ::tkutils::tkuini::setKey {path section key value} {
    variable state
    set state($path,data) [::tclutils::tuini::setValue $state($path,data) $section $key $value]
    _reload $path
    return $key
}
# Remove a key from a section.
proc ::tkutils::tkuini::removeKey {path section key} {
    variable state
    set state($path,data) [::tclutils::tuini::removeKey $state($path,data) $section $key]
    _reload $path
}
# Add an (empty) section and select it.
proc ::tkutils::tkuini::addSection {path section} {
    variable state
    set state($path,data) [::tclutils::tuini::addSection $state($path,data) $section]
    set state($path,cur) $section
    _reload $path
    return $section
}
# Remove a whole section.
proc ::tkutils::tkuini::removeSection {path section} {
    variable state
    set state($path,data) [::tclutils::tuini::removeSection $state($path,data) $section]
    if {$state($path,cur) eq $section} { set state($path,cur) "" }
    _reload $path
}
# Current document as INI text.
proc ::tkutils::tkuini::toText {path} {
    variable state
    return [::tclutils::tuini::toIni $state($path,data)]
}
# Write the current document to a file.
proc ::tkutils::tkuini::save {path file} {
    set ch [open $file w]
    fconfigure $ch -translation lf
    puts $ch [toText $path]
    close $ch
    return $file
}

# --- edit-bar handlers --------------------------------------------------------

proc ::tkutils::tkuini::_fillEdit {path} {
    variable state
    set kv [treeWidget $path]
    set item [lindex [$kv selection] 0]
    if {$item eq ""} return
    set state($path,ekey) [$kv item $item -text]
    set state($path,eval) [lindex [$kv item $item -values] 0]
}
proc ::tkutils::tkuini::_uiSet {path} {
    variable state
    if {$state($path,ekey) ne ""} {
        setKey $path $state($path,cur) $state($path,ekey) $state($path,eval)
    }
}
proc ::tkutils::tkuini::_uiDel {path} {
    variable state
    if {$state($path,ekey) ne ""} {
        removeKey $path $state($path,cur) $state($path,ekey)
    }
}
proc ::tkutils::tkuini::_uiAddSection {path} {
    variable state
    if {$state($path,esec) ne ""} {
        addSection $path $state($path,esec)
        set state($path,esec) ""
    }
}
proc ::tkutils::tkuini::_uiDelSection {path} {
    variable state
    removeSection $path $state($path,cur)
}

package provide tkutils::tkuini 0.1
