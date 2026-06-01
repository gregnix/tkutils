# tkutils::tknotes -- hierarchical notes widget
#
# A composite widget: a tree of notes on the left, a title/tags/content editor
# on the right, and a small action bar (New Root, New Child, Delete, Save) with
# a search box. All note logic and JSON persistence come from the tclutils
# engine tunotes; this widget only renders and edits. Tcl/Tk 8.6+ and 9.x.
#
# Per-widget state lives in `state`, keyed "$path,...". Tree item ids ARE the
# note ids, so selection maps straight back to the store.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tunotes 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tknotes {
    namespace export widget refresh store load save count current select \
        addRoot addChild delete move search treeWidget \
        expandAll collapseAll tags byTag addTag removeTag subtree saveSubtree
    variable state
}

proc ::tkutils::tknotes::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the widget under $path. Option: -file path (load notes on creation).
proc ::tkutils::tknotes::widget {path args} {
    variable state
    array set o {-file "" -toolbar 1}
    array set o $args

    ttk::frame $path
    set state($path,store) [dict create]
    set state($path,file) $o(-file)
    set state($path,current) ""
    set state($path,title) ""
    set state($path,tags) ""
    bind $path <Destroy> [list ::tkutils::tknotes::_cleanup $path %W]

    # action bar (optional: an embedding app may supply its own controls)
    if {$o(-toolbar)} {
        set bar [ttk::frame $path.bar -padding {2 2}]
        ttk::button $bar.new   -text "New Root"  -command [list ::tkutils::tknotes::_uiAddRoot $path]
        ttk::button $bar.child -text "New Child" -command [list ::tkutils::tknotes::_uiAddChild $path]
        ttk::button $bar.del   -text "Delete"    -command [list ::tkutils::tknotes::_uiDelete $path]
        ttk::button $bar.save  -text "Save"      -command [list ::tkutils::tknotes::_uiSave $path]
        ttk::label  $bar.lsearch -text "  Search:"
        ttk::entry  $bar.search -width 18
        pack $bar.new $bar.child $bar.del $bar.save -side left -padx 1
        pack $bar.search $bar.lsearch -side right -padx 1
        pack $bar -side top -fill x
        bind $bar.search <Return> [list ::tkutils::tknotes::_uiSearch $path]
    }

    # split: tree | editor
    set pw [ttk::panedwindow $path.pw -orient horizontal]
    pack $pw -side top -fill both -expand 1

    set l [ttk::frame $pw.l]
    set tv [ttk::treeview $l.tv -show tree -yscrollcommand [list $l.ys set]]
    ttk::scrollbar $l.ys -orient vertical -command [list $tv yview]
    grid $tv $l.ys -sticky nsew
    grid rowconfigure $l 0 -weight 1
    grid columnconfigure $l 0 -weight 1
    bind $tv <<TreeviewSelect>> [list ::tkutils::tknotes::_onSelect $path]

    set r [ttk::frame $pw.r -padding {6 0 0 0}]
    ttk::label $r.lt -text "Title:"
    ttk::entry $r.title -textvariable ::tkutils::tknotes::state($path,title)
    ttk::label $r.ltag -text "Tags:"
    ttk::entry $r.tags -textvariable ::tkutils::tknotes::state($path,tags)
    text $r.content -width 40 -height 12 -wrap word \
        -yscrollcommand [list $r.ys set]
    ttk::scrollbar $r.ys -orient vertical -command [list $r.content yview]
    grid $r.lt    -row 0 -column 0 -sticky w  -pady 2
    grid $r.title -row 0 -column 1 -columnspan 2 -sticky ew -pady 2
    grid $r.ltag  -row 1 -column 0 -sticky w  -pady 2
    grid $r.tags  -row 1 -column 1 -columnspan 2 -sticky ew -pady 2
    grid $r.content -row 2 -column 0 -columnspan 2 -sticky nsew -pady 2
    grid $r.ys      -row 2 -column 2 -sticky ns -pady 2
    grid rowconfigure $r 2 -weight 1
    grid columnconfigure $r 1 -weight 1

    $pw add $l
    $pw add $r

    if {$state($path,file) ne ""} { load $path $state($path,file) }
    refresh $path
    return $path
}

# --- accessors ---------------------------------------------------------------

proc ::tkutils::tknotes::store {path} {
    variable state
    return $state($path,store)
}
proc ::tkutils::tknotes::count {path} {
    variable state
    return [::tclutils::tunotes::count $state($path,store)]
}
proc ::tkutils::tknotes::current {path} {
    variable state
    return $state($path,current)
}
proc ::tkutils::tknotes::treeWidget {path} {
    return $path.pw.l.tv
}

# --- tree rendering ----------------------------------------------------------

proc ::tkutils::tknotes::refresh {path} {
    variable state
    set tv $path.pw.l.tv
    $tv delete [$tv children {}]
    foreach id [::tclutils::tunotes::roots $state($path,store)] {
        _insertNode $path {} $id
    }
}
proc ::tkutils::tknotes::_insertNode {path parentItem id} {
    variable state
    set tv $path.pw.l.tv
    set note [::tclutils::tunotes::get $state($path,store) $id]
    $tv insert $parentItem end -id $id -text [dict get $note title] -open 1
    foreach c [::tclutils::tunotes::children $state($path,store) $id] {
        _insertNode $path $id $c
    }
}

# Select a note: highlight in the tree and load it into the editor.
proc ::tkutils::tknotes::select {path id} {
    variable state
    set tv $path.pw.l.tv
    if {![$tv exists $id]} return
    $tv selection set $id
    $tv see $id
    set state($path,current) $id
    _loadEditor $path $id
}

proc ::tkutils::tknotes::_onSelect {path} {
    variable state
    set sel [$path.pw.l.tv selection]
    if {$sel eq ""} return
    set id [lindex $sel 0]
    set state($path,current) $id
    _loadEditor $path $id
}

proc ::tkutils::tknotes::_loadEditor {path id} {
    variable state
    set note [::tclutils::tunotes::get $state($path,store) $id]
    set state($path,title) [dict get $note title]
    set state($path,tags)  [join [dict get $note tags] " "]
    set c $path.pw.r.content
    $c delete 1.0 end
    $c insert end [dict get $note content]
}

# --- mutations (programmatic API) -------------------------------------------

proc ::tkutils::tknotes::addRoot {path title content {tags {}}} {
    variable state
    set id [::tclutils::tunotes::create state($path,store) $title $content $tags ""]
    refresh $path
    select $path $id
    return $id
}

proc ::tkutils::tknotes::addChild {path parentId title content {tags {}}} {
    variable state
    set id [::tclutils::tunotes::create state($path,store) $title $content $tags $parentId]
    refresh $path
    select $path $id
    return $id
}

proc ::tkutils::tknotes::delete {path id {cascade 1}} {
    variable state
    ::tclutils::tunotes::delete state($path,store) $id $cascade
    if {$state($path,current) eq $id} {
        set state($path,current) ""
        set state($path,title) ""
        set state($path,tags) ""
        $path.pw.r.content delete 1.0 end
    }
    refresh $path
    return
}

# Persist the current editor fields back into the store for $id (or current).
proc ::tkutils::tknotes::commit {path {id ""}} {
    variable state
    if {$id eq ""} { set id $state($path,current) }
    if {$id eq "" || ![::tclutils::tunotes::exists $state($path,store) $id]} {
        return ""
    }
    set tags [regexp -all -inline {\S+} $state($path,tags)]
    set content [$path.pw.r.content get 1.0 end-1c]
    ::tclutils::tunotes::update state($path,store) $id \
        $state($path,title) $content $tags
    refresh $path
    select $path $id
    return $id
}

proc ::tkutils::tknotes::search {path query} {
    variable state
    return [::tclutils::tunotes::search $state($path,store) $query]
}

# Reparent a note ("" = root). Delegates to tunotes (cycle-checked), then
# refreshes and reselects.
proc ::tkutils::tknotes::move {path id newParentId} {
    variable state
    ::tclutils::tunotes::move state($path,store) $id $newParentId
    refresh $path
    select $path $id
    return $id
}

# --- file persistence --------------------------------------------------------

proc ::tkutils::tknotes::load {path file} {
    variable state
    set state($path,store) [::tclutils::tunotes::load $file]
    set state($path,file) $file
    set state($path,current) ""
    refresh $path
    return [count $path]
}

proc ::tkutils::tknotes::save {path {file ""}} {
    variable state
    if {$file eq ""} { set file $state($path,file) }
    if {$file eq ""} {
        return -code error -errorcode {TKUTILS TKNOTES NOFILE} \
            "no file specified for save"
    }
    ::tclutils::tunotes::save $state($path,store) $file
    set state($path,file) $file
    return $file
}

# --- UI command wrappers -----------------------------------------------------

proc ::tkutils::tknotes::_uiAddRoot {path} {
    addRoot $path "New note" "" {}
    focus $path.pw.r.title
}
proc ::tkutils::tknotes::_uiAddChild {path} {
    variable state
    set parent $state($path,current)
    addChild $path $parent "New note" "" {}
    focus $path.pw.r.title
}
proc ::tkutils::tknotes::_uiDelete {path} {
    variable state
    if {$state($path,current) ne ""} { delete $path $state($path,current) }
}
proc ::tkutils::tknotes::_uiSave {path} {
    commit $path
}
proc ::tkutils::tknotes::_uiSearch {path} {
    set hits [search $path [$path.bar.search get]]
    if {[llength $hits]} { select $path [lindex $hits 0] }
}

# --- tree expansion -----------------------------------------------------------

proc ::tkutils::tknotes::_allItems {tv parent} {
    set out {}
    foreach c [$tv children $parent] {
        lappend out $c
        lappend out {*}[_allItems $tv $c]
    }
    return $out
}
proc ::tkutils::tknotes::expandAll {path} {
    set tv [treeWidget $path]
    foreach it [_allItems $tv {}] { $tv item $it -open 1 }
}
proc ::tkutils::tknotes::collapseAll {path} {
    set tv [treeWidget $path]
    foreach it [_allItems $tv {}] { $tv item $it -open 0 }
}

# --- tags ---------------------------------------------------------------------

# All distinct tags in the store (sorted).
proc ::tkutils::tknotes::tags {path} {
    variable state
    return [::tclutils::tunotes::tags $state($path,store)]
}
# Ids of notes carrying a tag.
proc ::tkutils::tknotes::byTag {path tag} {
    variable state
    return [::tclutils::tunotes::byTag $state($path,store) $tag]
}
# Add/remove a tag on a note, refreshing the view (and the editor if current).
proc ::tkutils::tknotes::addTag {path id tag} {
    variable state
    ::tclutils::tunotes::addTag state($path,store) $id $tag
    refresh $path
    if {$state($path,current) eq $id} { _loadEditor $path $id }
    return $id
}
proc ::tkutils::tknotes::removeTag {path id tag} {
    variable state
    ::tclutils::tunotes::removeTag state($path,store) $id $tag
    refresh $path
    if {$state($path,current) eq $id} { _loadEditor $path $id }
    return $id
}

# --- branch export ------------------------------------------------------------

# A standalone store-dict of a note and its descendants (re-rooted).
proc ::tkutils::tknotes::subtree {path id} {
    variable state
    return [::tclutils::tunotes::subtree $state($path,store) $id]
}
# Save that branch to a JSON file.
proc ::tkutils::tknotes::saveSubtree {path id file} {
    variable state
    ::tclutils::tunotes::save \
        [::tclutils::tunotes::subtree $state($path,store) $id] $file
    return $file
}

package provide tkutils::tknotes 0.1
