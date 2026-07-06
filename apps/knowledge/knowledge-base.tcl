#!/usr/bin/env wish
# knowledge-base.tcl -- Tk GUI for the knowledge base.
#
# Assembles existing tkutils widgets around the kb-store data layer:
#   tkusearchbar  full-text search box (with a category filter)
#   tkutltree     category tree (left)
#   tkutablelist  entry / result list (top right)
#   tkumdview     markdown preview of the selected entry (bottom right)
#   tkueditor     markdown body editor (with a live preview)
#
#   wish knowledge-base.tcl ?dbfile?
#
package require Tcl 8.6-

# --- bootstrap tkutils/tclutils + local modules -----------------------------
set ::kbdir [file dirname [file normalize [info script]]]
set _paths [file join $::kbdir .. _lib paths.tcl]
if {[file exists $_paths]} { source $_paths }
if {[info exists ::env(TCLUTILS_TM)]} { catch {tcl::tm::path add $::env(TCLUTILS_TM)} }
if {[info exists ::env(TKUTILS_TM)]}  { catch {tcl::tm::path add $::env(TKUTILS_TM)} }

source [file join $::kbdir kb-store.tcl]
source [file join $::kbdir kb-import.tcl]
source [file join $::kbdir kb-export.tcl]

package require Tk
package require tablelist
package require tkutils::tkusearchbar
package require tkutils::tkutablelist
package require tkutils::tkutltree
package require tkutils::tkumdview
package require tkutils::tkueditor

namespace eval ::kbgui {
    variable G
    array set G {store {} ids {} catmap {} curCat {} curEntry {} search {} \
        allTagsLabel {(alle Tags)}}
}

# --- build ------------------------------------------------------------------
proc ::kbgui::build {top store} {
    variable G
    set G(store) $store
    if {$top eq "."} { set base "" } else { set base $top }

    wm title $top "Wissensbasis"
    wm geometry $top 1100x680

    # top: search bar
    ::tkutils::tkusearchbar::widget $base.search \
        -command [list ::kbgui::onSearch] -filters {} -width 40
    set G(search) $base.search
    ttk::label $base.hint -text "Volltextsuche  \u00b7  Kategorie links  \u00b7  Tag im Filter rechts" \
        -foreground gray45

    # main paned: tree | (list / preview)
    ttk::panedwindow $base.pw -orient horizontal

    # left: category tree (tltree on a raw tablelist configured as a tree)
    ttk::frame $base.pw.cat
    set tree $base.pw.cat.t
    tablelist::tablelist $tree -columns {0 Kategorie left  0 id left} \
        -stretch 0 -expandcommand {} -selectmode extended -showlabels 1 \
        -treecolumn 0 -width 26 -height 20 \
        -yscrollcommand [list $base.pw.cat.ys set]
    $tree columnconfigure 1 -hide 1
    ttk::scrollbar $base.pw.cat.ys -orient vertical -command [list $tree yview]
    ttk::frame $base.pw.cat.btns
    ttk::button $base.pw.cat.btns.all -text "Alle" -command [list ::kbgui::showAll]
    ttk::button $base.pw.cat.btns.move -text "Verschieben\u2026" \
        -command [list ::kbgui::moveCategory]
    grid $base.pw.cat.btns.all $base.pw.cat.btns.move -sticky ew -padx {0 2}
    grid columnconfigure $base.pw.cat.btns 0 -weight 1
    grid columnconfigure $base.pw.cat.btns 1 -weight 1
    # tag filter (multi-select) below the tree
    ttk::labelframe $base.pw.cat.tags -text "Tags (Filter)"
    listbox $base.pw.cat.tags.lb -selectmode extended -height 7 -exportselection 0 \
        -activestyle none -yscrollcommand [list $base.pw.cat.tags.ys set]
    ttk::scrollbar $base.pw.cat.tags.ys -orient vertical \
        -command [list $base.pw.cat.tags.lb yview]
    ttk::frame $base.pw.cat.tags.ctl
    set ::kbgui::_tagMode all
    ttk::radiobutton $base.pw.cat.tags.ctl.all -text "alle" \
        -variable ::kbgui::_tagMode -value all -command [list ::kbgui::_applyFilters]
    ttk::radiobutton $base.pw.cat.tags.ctl.any -text "eine" \
        -variable ::kbgui::_tagMode -value any -command [list ::kbgui::_applyFilters]
    ttk::button $base.pw.cat.tags.ctl.clear -text "\u00d7" -width 2 \
        -command [list ::kbgui::_clearTags]
    grid $base.pw.cat.tags.ctl.all $base.pw.cat.tags.ctl.any \
         $base.pw.cat.tags.ctl.clear -sticky w -padx 2
    grid $base.pw.cat.tags.lb $base.pw.cat.tags.ys -sticky nsew
    grid $base.pw.cat.tags.ctl -row 1 -column 0 -columnspan 2 -sticky ew -pady {2 0}
    grid rowconfigure $base.pw.cat.tags 0 -weight 1
    grid columnconfigure $base.pw.cat.tags 0 -weight 1
    set G(taglb) $base.pw.cat.tags.lb
    bind $G(taglb) <<ListboxSelect>> [list ::kbgui::_applyFilters]

    grid $base.pw.cat.btns -row 0 -column 0 -columnspan 2 -sticky ew -pady {0 4}
    grid $tree $base.pw.cat.ys -row 1 -sticky nsew
    grid $base.pw.cat.tags -row 2 -column 0 -columnspan 2 -sticky nsew -pady {6 0}
    grid rowconfigure    $base.pw.cat 1 -weight 3
    grid rowconfigure    $base.pw.cat 2 -weight 1
    grid columnconfigure $base.pw.cat 0 -weight 1
    bind $tree <<TablelistSelect>> [list ::kbgui::onCategory $tree]
    set G(tree) $tree
    _dndSetup $tree
    _menuSetup $tree

    # right: vertical paned (entry list on top, preview below)
    ttk::panedwindow $base.pw.rt -orient vertical
    ::tkutils::tkutablelist::widget $base.pw.rt.list \
        -columns {Titel Kategorie} -selectmode extended \
        -selectcommand ::kbgui::onEntry
    set G(list) $base.pw.rt.list
    _listMenuSetup $G(list)

    ttk::frame $base.pw.rt.det
    ::tkutils::tkumdview::widget $base.pw.rt.det.md -width 64 -height 16
    # TOC-less preview: drop the outline pane, keep only the rendered text
    catch {$base.pw.rt.det.md.pw forget $base.pw.rt.det.md.pw.l}
    ttk::label $base.pw.rt.det.tags -text "" -foreground "#39603a" -anchor w
    grid $base.pw.rt.det.md   -sticky nsew
    grid $base.pw.rt.det.tags -sticky ew -padx 6 -pady {2 4}
    grid rowconfigure    $base.pw.rt.det 0 -weight 1
    grid columnconfigure $base.pw.rt.det 0 -weight 1
    set G(md)   $base.pw.rt.det.md
    set G(tags) $base.pw.rt.det.tags

    $base.pw.rt add $base.pw.rt.list -weight 2
    $base.pw.rt add $base.pw.rt.det  -weight 3
    $base.pw add $base.pw.cat -weight 1
    $base.pw add $base.pw.rt  -weight 3

    # bottom: actions + status
    ttk::frame $base.act
    ttk::button $base.act.new  -text "Neu"      -command [list ::kbgui::edit new]
    ttk::button $base.act.edit -text "Bearbeiten" -command [list ::kbgui::edit cur]
    ttk::button $base.act.del  -text "Loeschen"  -command [list ::kbgui::delete]
    ttk::separator $base.act.sep -orient vertical
    ttk::button $base.act.imp  -text "Import\u2026" -command [list ::kbgui::import]
    ttk::button $base.act.exp  -text "Export\u2026" -command [list ::kbgui::export]
    ttk::label  $base.act.status -text "" -anchor e -foreground gray45
    grid $base.act.new $base.act.edit $base.act.del $base.act.sep \
         $base.act.imp $base.act.exp $base.act.status -sticky w -padx {0 4}
    grid $base.act.sep -sticky ns -padx 6
    grid columnconfigure $base.act 6 -weight 1
    set G(status) $base.act.status

    # overall layout
    grid $base.search -row 0 -column 0 -sticky ew -padx 6 -pady {6 0}
    grid $base.hint   -row 1 -column 0 -sticky w  -padx 8
    grid $base.pw     -row 2 -column 0 -sticky nsew -padx 6 -pady 4
    grid $base.act    -row 3 -column 0 -sticky ew -padx 6 -pady {0 6}
    grid rowconfigure    $top 2 -weight 1
    grid columnconfigure $top 0 -weight 1

    refreshCategories
    showAll
    ::tkutils::tkusearchbar::focusSearch $base.search
}

# --- data -> widgets --------------------------------------------------------
proc ::kbgui::refreshCategories {} {
    variable G
    set cats [::kb::store::categories $G(store)]
    set G(catmap)    [dict create]   ;# id -> leaf name
    set G(catpath)   [dict create]   ;# id -> "Bereich / Thema" path
    set G(catparent) [dict create]   ;# id -> parent id ("" = top level)
    set byId     [dict create]
    set children [dict create]
    foreach c $cats {
        set id [dict get $c id]
        dict set byId $id $c
        dict set G(catmap) $id [dict get $c name]
        dict set G(catparent) $id [dict get $c parent_id]
        set p [dict get $c parent_id]
        if {$p eq ""} { set p root }
        dict lappend children $p $id
    }
    foreach c $cats {
        dict set G(catpath) [dict get $c id] [_buildPath $byId [dict get $c id]]
    }
    set data [_buildNodes $byId $children root]
    ::tkutils::tkutltree::clear $G(tree)
    ::tkutils::tkutltree::fromData $G(tree) $data \
        -fields {name id} -childrenkey children -parent root
    catch {$G(tree) expandall}
    _refreshTagList
}

# populate the multi-select tag list, restoring any still-valid selection
proc ::kbgui::_refreshTagList {} {
    variable G
    if {![info exists G(taglb)] || ![winfo exists $G(taglb)]} return
    set sel [_selectedTags]
    set all [::kb::store::tagsAll $G(store)]
    $G(taglb) delete 0 end
    foreach t $all { $G(taglb) insert end $t }
    foreach t $sel {
        set i [lsearch -exact $all $t]
        if {$i >= 0} { $G(taglb) selection set $i }
    }
}

# tags currently selected in the filter list
proc ::kbgui::_selectedTags {} {
    variable G
    if {![info exists G(taglb)] || ![winfo exists $G(taglb)]} { return {} }
    set out {}
    foreach i [$G(taglb) curselection] { lappend out [$G(taglb) get $i] }
    return $out
}

proc ::kbgui::_clearTags {} {
    variable G
    if {[info exists G(taglb)] && [winfo exists $G(taglb)]} { $G(taglb) selection clear 0 end }
    _applyFilters
}

# does entry $id satisfy the selected tags under the current mode?
proc ::kbgui::_matchesTags {id tags mode} {
    variable G
    set et [::kb::store::entryTags $G(store) $id]
    if {$mode eq "any"} {
        foreach t $tags { if {$t in $et} { return 1 } }
        return 0
    }
    foreach t $tags { if {$t ni $et} { return 0 } }
    return 1
}

# unified filter: combine search text, selected tags and the category scope.
proc ::kbgui::_applyFilters {{text ""}} {
    variable G
    if {$text eq ""} { catch {set text [::tkutils::tkusearchbar::getText $G(search)]} }
    set text [string trim $text]
    set tags [_selectedTags]
    set mode $::kbgui::_tagMode

    if {$text ne ""} {
        set opts {}
        if {$G(curCat) ne ""} { lappend opts -category $G(curCat) }
        if {[catch {::kb::store::search $G(store) $text {*}$opts} res]} {
            status "Suche: $res"; return
        }
        set rows {}
        foreach r $res {
            if {[llength $tags] && ![_matchesTags [dict get $r id] $tags $mode]} continue
            lappend rows [dict create id [dict get $r id] title [dict get $r title] cat ""]
        }
        _fillList $rows
        status "[llength $rows] Treffer fuer \"$text\"[expr {[llength $tags] ? " + Tags" : ""}]"
        return
    }
    if {[llength $tags]} {
        set rows {}
        foreach e [::kb::store::entriesByTags $G(store) $tags $mode] {
            lappend rows [dict create id [dict get $e id] title [dict get $e title] \
                cat [_catLabel [dict get $e category_id]]]
        }
        _fillList $rows
        status "[llength $rows] Eintraege \u2014 Tags ([expr {$mode eq "all" ? "alle" : "eine"}]): [join $tags {, }]"
        return
    }
    if {$G(curCat) ne ""} { onCategoryId $G(curCat) } else { showAll }
}

# nested node data for a parent (recursive), ordered as `categories` returned.
proc ::kbgui::_buildNodes {byId children parent} {
    if {![dict exists $children $parent]} { return {} }
    set out {}
    foreach id [dict get $children $parent] {
        set node [dict create name [dict get $byId $id name] id $id]
        set kids [_buildNodes $byId $children $id]
        if {[llength $kids]} { dict set node children $kids }
        lappend out $node
    }
    return $out
}

# "Bereich / Thema" path by walking parent_id up to the root.
proc ::kbgui::_buildPath {byId id} {
    set parts {}
    set cur $id
    while {$cur ne "" && [dict exists $byId $cur]} {
        set parts [linsert $parts 0 [dict get $byId $cur name]]
        set cur [dict get $byId $cur parent_id]
    }
    return [join $parts " / "]
}

# full path label for an entry's category (falls back to leaf name)
proc ::kbgui::_catLabel {id} {
    variable G
    if {$id ne "" && [dict exists $G(catpath) $id]} { return [dict get $G(catpath) $id] }
    return [_catName $id]
}

proc ::kbgui::_catName {id} {
    variable G
    if {$id ne "" && [dict exists $G(catmap) $id]} { return [dict get $G(catmap) $id] }
    return ""
}

# fill the entry list from a list of {id title category} rows
proc ::kbgui::_fillList {rows} {
    variable G
    set G(ids) {}
    set out {}
    foreach r $rows {
        lappend G(ids) [dict get $r id]
        lappend out [list [dict get $r title] [dict get $r cat]]
    }
    ::tkutils::tkutablelist::setRows $G(list) $out
    status "[llength $out] Eintraege"
}

proc ::kbgui::showAll {} {
    variable G
    set G(curCat) ""
    set rows {}
    foreach e [::kb::store::entriesAll $G(store)] {
        lappend rows [dict create id [dict get $e id] title [dict get $e title] \
            cat [_catLabel [dict get $e category_id]]]
    }
    _fillList $rows
    _clearPreview
}

proc ::kbgui::onCategory {tree} {
    variable G
    set sel [$tree curselection]
    if {![llength $sel]} return
    set row [$tree get [lindex $sel 0]]
    set id  [lindex $row 1]     ;# columns: name, id
    set G(curCat) $id
    set rows {}
    foreach e [::kb::store::categoryEntries $G(store) $id] {
        lappend rows [dict create id [dict get $e id] title [dict get $e title] \
            cat [_catLabel $id]]
    }
    _fillList $rows
    _clearPreview
}

proc ::kbgui::onSearch {text filter} { _applyFilters $text }

proc ::kbgui::onCategoryId {id} {
    variable G
    set rows {}
    foreach e [::kb::store::categoryEntries $G(store) $id] {
        lappend rows [dict create id [dict get $e id] title [dict get $e title] \
            cat [_catLabel $id]]
    }
    _fillList $rows
}

proc ::kbgui::onEntry {path row} {
    variable G
    if {$row < 0 || $row >= [llength $G(ids)]} return
    set id [lindex $G(ids) $row]
    set G(curEntry) $id
    set e [::kb::store::entryGet $G(store) $id]
    if {$e eq ""} return
    set md "# [dict get $e title]\n\n[dict get $e body]"
    ::tkutils::tkumdview::setMarkdown $G(md) $md
    set tags [::kb::store::entryTags $G(store) $id]
    $G(tags) configure -text [expr {[llength $tags] ? "Tags: [join $tags {, }]" : ""}]
}

proc ::kbgui::_clearPreview {} {
    variable G
    set G(curEntry) ""
    ::tkutils::tkumdview::setMarkdown $G(md) ""
    $G(tags) configure -text ""
}

proc ::kbgui::status {msg} {
    variable G
    $G(status) configure -text $msg
}

# --- right-click context menu on the entry list -----------------------------
proc ::kbgui::_listMenuSetup {list} {
    variable G
    set m $list.ctx
    catch {destroy $m}
    menu $m -tearoff 0
    $m add command -label "Neuer Eintrag\u2026" -command [list ::kbgui::edit new]
    $m add command -label "Bearbeiten\u2026"     -command [list ::kbgui::edit cur]
    $m add separator
    $m add command -label "Loeschen"            -command [list ::kbgui::delete]
    set G(listmenu) $m
    bind [$list.tbl bodytag] <Button-3> +[list ::kbgui::_listPopup $list %x %y %X %Y]
}

proc ::kbgui::_listPopup {list x y X Y} {
    variable G
    # keep an existing multi-selection; otherwise select the row under the cursor
    if {[llength [$list.tbl curselection]] <= 1} {
        event generate [$list.tbl bodypath] <Button-1> -x $x -y $y
        event generate [$list.tbl bodypath] <ButtonRelease-1> -x $x -y $y
        update idletasks
        set sel [$list.tbl curselection]
        if {[llength $sel]} { onEntry $list [lindex $sel 0] }
    }
    tk_popup $G(listmenu) $X $Y
}

# --- add / edit / delete ----------------------------------------------------
proc ::kbgui::edit {which} {
    variable G
    set e ""
    if {$which eq "cur"} {
        if {$G(curEntry) eq ""} { status "Kein Eintrag gewaehlt"; return }
        set e [::kb::store::entryGet $G(store) $G(curEntry)]
    }
    set G(edMode) $which
    set G(edId)   [expr {$e ne "" ? $G(curEntry) : ""}]
    set G(edPvAfter) ""
    set names [lsort [dict values $G(catpath)]]

    set dlg .kbedit
    catch {destroy $dlg}
    toplevel $dlg
    wm title $dlg [expr {$e eq "" ? "Neuer Eintrag" : "Eintrag bearbeiten"}]
    wm transient $dlg [winfo toplevel $G(list)]
    wm geometry $dlg 920x600

    # header: title / category / tags
    set hdr $dlg.h
    ttk::frame $hdr
    set ::kbgui::_edTitle ""; set ::kbgui::_edCat ""; set ::kbgui::_edTags ""
    ttk::label $hdr.lt -text "Titel"
    ttk::entry $hdr.t  -textvariable ::kbgui::_edTitle
    ttk::label $hdr.lc -text "Kategorie"
    ttk::combobox $hdr.c -textvariable ::kbgui::_edCat -values $names
    ttk::label $hdr.lg -text "Tags (Komma)"
    ttk::entry $hdr.g  -textvariable ::kbgui::_edTags
    grid $hdr.lt $hdr.t -sticky ew -padx 2 -pady 2
    grid $hdr.lc $hdr.c -sticky ew -padx 2 -pady 2
    grid $hdr.lg $hdr.g -sticky ew -padx 2 -pady 2
    grid columnconfigure $hdr 1 -weight 1

    # body: markdown editor (left) | live preview (right)
    ttk::panedwindow $dlg.pw -orient horizontal
    ttk::frame $dlg.pw.ed
    _mdToolbar $dlg.pw.ed.tb
    ::tkutils::tkueditor::widget $dlg.pw.ed.e -width 46 -height 20 -wrap word -statusbar 0
    grid $dlg.pw.ed.tb -sticky ew
    grid $dlg.pw.ed.e  -sticky nsew
    grid rowconfigure $dlg.pw.ed 1 -weight 1
    grid columnconfigure $dlg.pw.ed 0 -weight 1
    set G(edEd) $dlg.pw.ed.e

    ttk::frame $dlg.pw.pv
    ttk::button $dlg.pw.pv.rf -text "\u21bb Vorschau" -command [list ::kbgui::_edRefreshPreview]
    ::tkutils::tkumdview::widget $dlg.pw.pv.md -width 38 -height 20
    catch {$dlg.pw.pv.md.pw forget $dlg.pw.pv.md.pw.l}
    grid $dlg.pw.pv.rf -sticky w
    grid $dlg.pw.pv.md -sticky nsew
    grid rowconfigure $dlg.pw.pv 1 -weight 1
    grid columnconfigure $dlg.pw.pv 0 -weight 1
    set G(edMd) $dlg.pw.pv.md

    $dlg.pw add $dlg.pw.ed -weight 3
    $dlg.pw add $dlg.pw.pv -weight 2

    ttk::frame $dlg.b
    ttk::button $dlg.b.ok     -text "Speichern"  -command [list ::kbgui::_save]
    ttk::button $dlg.b.cancel -text "Abbrechen"  -command [list destroy $dlg]
    grid $dlg.b.ok $dlg.b.cancel -padx 4

    grid $hdr    -row 0 -column 0 -sticky ew   -padx 8 -pady {8 2}
    grid $dlg.pw -row 1 -column 0 -sticky nsew -padx 8 -pady 4
    grid $dlg.b  -row 2 -column 0 -sticky e    -padx 8 -pady {0 8}
    grid rowconfigure $dlg 1 -weight 1
    grid columnconfigure $dlg 0 -weight 1

    if {$e ne ""} {
        set ::kbgui::_edTitle [dict get $e title]
        set ::kbgui::_edCat   [_catLabel [dict get $e category_id]]
        set ::kbgui::_edTags  [join [::kb::store::entryTags $G(store) $G(curEntry)] ", "]
        ::tkutils::tkueditor::setText $G(edEd) [dict get $e body]
    }
    bind $G(edEd).t <KeyRelease> [list ::kbgui::_edPreviewDebounced]
    after idle [list focus $hdr.t]
    _edRefreshPreview
}

# markdown formatting toolbar operating on the editor's text widget
proc ::kbgui::_mdToolbar {tb} {
    ttk::frame $tb
    ttk::button $tb.b    -text "B"    -width 3 -command [list ::kbgui::_mdWrap "**" "**"]
    ttk::button $tb.i    -text "I"    -width 3 -command [list ::kbgui::_mdWrap "*" "*"]
    ttk::button $tb.code -text "</>"  -width 4 -command [list ::kbgui::_mdWrap "`" "`"]
    ttk::button $tb.h1   -text "H1"   -width 3 -command [list ::kbgui::_mdPrefix "# "]
    ttk::button $tb.h2   -text "H2"   -width 3 -command [list ::kbgui::_mdPrefix "## "]
    ttk::button $tb.li   -text "Liste" -width 5 -command [list ::kbgui::_mdPrefix "- "]
    ttk::button $tb.link -text "Link" -width 5 -command [list ::kbgui::_mdWrap "\[" "\](url)"]
    grid $tb.b $tb.i $tb.code $tb.h1 $tb.h2 $tb.li $tb.link -sticky w -padx 1 -pady 2
    return $tb
}

# wrap the selection (or insert markers at the cursor) with before/after
proc ::kbgui::_mdWrap {before after} {
    variable G
    set t $G(edEd).t
    if {![catch {$t get sel.first sel.last} sel] && $sel ne ""} {
        set a [$t index sel.first]; set b [$t index sel.last]
        $t delete $a $b
        $t insert $a "$before$sel$after"
    } else {
        set i [$t index insert]
        $t insert $i "$before$after"
        $t mark set insert "$i + [string length $before] chars"
    }
    focus $t
    _edRefreshPreview
}

# prefix the current line with a marker (heading / list item)
proc ::kbgui::_mdPrefix {prefix} {
    variable G
    set t $G(edEd).t
    $t insert "insert linestart" $prefix
    focus $t
    _edRefreshPreview
}

proc ::kbgui::_edRefreshPreview {} {
    variable G
    if {![info exists G(edMd)] || ![winfo exists $G(edMd)]} return
    ::tkutils::tkumdview::setMarkdown $G(edMd) [::tkutils::tkueditor::getText $G(edEd)]
}

proc ::kbgui::_edPreviewDebounced {} {
    variable G
    catch {after cancel $G(edPvAfter)}
    set G(edPvAfter) [after 400 ::kbgui::_edRefreshPreview]
}

proc ::kbgui::_save {} {
    variable G
    set title [string trim $::kbgui::_edTitle]
    if {$title eq ""} { status "Titel fehlt"; return }
    _saveEntryDo $G(edMode) $G(edId) $title \
        [::tkutils::tkueditor::getText $G(edEd)] $::kbgui::_edCat $::kbgui::_edTags
    catch {destroy .kbedit}
    status "Gespeichert: $title"
}

# store-side save (add/update + retag + refresh); testable without the dialog.
proc ::kbgui::_saveEntryDo {mode id title body catName tagsStr} {
    variable G
    set catId [_catIdFor $catName]
    if {$mode eq "cur" && $id ne ""} {
        ::kb::store::entryUpdate $G(store) $id $title $body $catId
        foreach t [::kb::store::entryTags $G(store) $id] { ::kb::store::entryUntag $G(store) $id $t }
    } else {
        set id [::kb::store::entryAdd $G(store) $title $body $catId manual]
    }
    foreach t [_splitTags $tagsStr] { ::kb::store::entryTag $G(store) $id $t }
    ::kb::store::pruneTags $G(store)
    refreshCategories
    if {$G(curCat) ne ""} { onCategoryId $G(curCat) } else { showAll }
    return $id
}

# Resolve a category label to an id. Accepts a "Bereich / Thema / ..." path and
# creates any missing levels, so the user can type new hierarchies in the combo.
proc ::kbgui::_catIdFor {name} {
    variable G
    set name [string trim $name]
    if {$name eq ""} { return "" }
    # exact existing path?
    dict for {id path} $G(catpath) { if {$path eq $name} { return $id } }
    # walk / create the path parts
    set parent ""
    foreach part [split $name /] {
        set part [string trim $part]
        if {$part eq ""} continue
        set id [_findChild $parent $part]
        if {$id eq ""} { set id [::kb::store::categoryAdd $G(store) $part $parent] }
        set parent $id
    }
    return $parent
}

# id of a direct child category named `name` under `parent` (""=top level), or "".
proc ::kbgui::_findChild {parent name} {
    variable G
    foreach c [::kb::store::categories $G(store)] {
        set p [dict get $c parent_id]
        set match [expr {$parent eq "" ? ($p eq "") : ($p eq $parent)}]
        if {$match && [dict get $c name] eq $name} { return [dict get $c id] }
    }
    return ""
}

proc ::kbgui::_splitTags {s} {
    set out {}
    foreach t [split $s ,] {
        set t [string trim $t]
        if {$t ne ""} { lappend out $t }
    }
    return $out
}

# --- move (re-parent) a category --------------------------------------------
proc ::kbgui::moveCategory {} {
    variable G
    set sel [$G(tree) curselection]
    if {![llength $sel]} { status "Keine Kategorie gewaehlt"; return }
    set srcId [lindex [$G(tree) get [lindex $sel 0]] 1]

    # valid targets: every category except the source and its descendants
    set excl [concat [list $srcId] [::kb::store::categoryDescendants $G(store) $srcId]]
    set targets [dict create "(oberste Ebene)" ""]
    dict for {id path} $G(catpath) {
        if {$id ni $excl} { dict set targets $path $id }
    }

    set dlg .kbmove
    catch {destroy $dlg}
    toplevel $dlg
    wm title $dlg "Kategorie verschieben"
    wm transient $dlg [winfo toplevel $G(tree)]
    ttk::label $dlg.l -text "\"[_catLabel $srcId]\" verschieben unter:"
    set ::kbgui::_moveTarget "(oberste Ebene)"
    ttk::combobox $dlg.c -state readonly -width 44 \
        -values [dict keys $targets] -textvariable ::kbgui::_moveTarget
    ttk::frame $dlg.b
    ttk::button $dlg.b.ok -text "Verschieben" \
        -command [list ::kbgui::_moveApply $dlg $srcId $targets]
    ttk::button $dlg.b.cancel -text "Abbrechen" -command [list destroy $dlg]
    grid $dlg.b.ok $dlg.b.cancel -padx 4
    grid $dlg.l -sticky w  -padx 8 -pady {8 2}
    grid $dlg.c -sticky ew -padx 8
    grid $dlg.b -sticky e  -padx 8 -pady 8
    grid columnconfigure $dlg 0 -weight 1
}

proc ::kbgui::_moveApply {dlg srcId targets} {
    variable _moveTarget
    set newParent [expr {[dict exists $targets $_moveTarget] ? [dict get $targets $_moveTarget] : ""}]
    destroy $dlg
    if {[moveCategoryTo $srcId $newParent]} { status "Kategorie verschoben" }
}

# do the move + refresh (separated so it is testable without a dialog)
proc ::kbgui::moveCategoryTo {srcId newParent} {
    variable G
    set cur [_categoryParent $srcId]
    if {($newParent eq "" && $cur eq "") || ($newParent ne "" && $newParent == $cur)} {
        status "Keine Aenderung \u2014 Kategorie ist bereits dort"
        return 0
    }
    if {[catch {::kb::store::categoryMove $G(store) $srcId $newParent} err]} {
        status "Verschieben fehlgeschlagen: $err"
        return 0
    }
    refreshCategories
    showAll
    return 1
}

# --- drag & drop re-parenting in the category tree --------------------------
# Drag a category onto another to make it a child; drop on empty space to move
# it to the top level. The target row is highlighted while dragging. Cycles and
# no-op moves (already under that parent) are rejected with a clear message.
proc ::kbgui::_dndSetup {tree} {
    variable G
    set G(dndSrc) -1
    set G(dndActive) 0
    set G(dndBusy) 0
    set bt [$tree bodytag]
    bind $bt <ButtonPress-1>   +[list ::kbgui::_dndPress   $tree]
    bind $bt <B1-Motion>       +[list ::kbgui::_dndMotion  $tree]
    bind $bt <ButtonRelease-1> +[list ::kbgui::_dndRelease $tree %x %y]
}

# Source row: read the selection tablelist just made for the real press -- this
# matches real click coordinates (its `containing` can be off by one row).
proc ::kbgui::_dndPress {tree} {
    variable G
    if {$G(dndBusy)} return
    set sel [$tree curselection]
    set G(dndSrc) [expr {[llength $sel] ? [lindex $sel 0] : -1}]
    set G(dndActive) 0
}

proc ::kbgui::_dndMotion {tree} {
    variable G
    if {$G(dndBusy) || $G(dndSrc) < 0} return
    set G(dndActive) 1
    $tree configure -cursor hand2
}

# Target row: resolve it with a real click at the release point (same reason),
# guarding against the synthetic events re-entering these handlers.
proc ::kbgui::_dndRelease {tree x y} {
    variable G
    if {$G(dndBusy)} return
    $tree configure -cursor {}
    if {!$G(dndActive)} return          ;# a plain click -> normal selection
    set G(dndActive) 0
    set src $G(dndSrc)
    set G(dndBusy) 1
    event generate [$tree bodypath] <Button-1> -x $x -y $y
    event generate [$tree bodypath] <ButtonRelease-1> -x $x -y $y
    update idletasks
    set G(dndBusy) 0
    set sel [$tree curselection]
    set tgt [expr {[llength $sel] ? [lindex $sel 0] : -1}]
    _applyDrop $src $tgt
}

# apply a drop of display row srcRow onto tgtRow (-1 = top level). Separated
# from the event handlers so it is testable without synthetic mouse events.
proc ::kbgui::_applyDrop {srcRow tgtRow} {
    variable G
    if {$srcRow < 0} return
    set srcId   [lindex [$G(tree) get $srcRow] 1]
    set srcName [_catLabel $srcId]
    if {$tgtRow < 0} {
        set newParent ""; set tgtName "oberste Ebene"
    } elseif {$tgtRow == $srcRow} {
        return
    } else {
        set newParent [lindex [$G(tree) get $tgtRow] 1]
        set tgtName [_catLabel $newParent]
    }
    if {[moveCategoryTo $srcId $newParent]} {
        status "Verschoben: \"$srcName\" -> $tgtName"
    }
}

# current parent id of a category ("" = top level)
proc ::kbgui::_categoryParent {id} {
    variable G
    if {[info exists G(catparent)] && [dict exists $G(catparent) $id]} {
        return [dict get $G(catparent) $id]
    }
    return ""
}

# --- right-click context menu on the category tree --------------------------
proc ::kbgui::_menuSetup {tree} {
    variable G
    set m $tree.ctx
    catch {destroy $m}
    menu $m -tearoff 0
    $m add command -label "Neue Unterkategorie\u2026" -command [list ::kbgui::_ctxNewChild]
    $m add command -label "Umbenennen\u2026"          -command [list ::kbgui::_ctxRename]
    $m add command -label "Verschieben\u2026"          -command [list ::kbgui::moveCategory]
    $m add separator
    $m add command -label "Loeschen"                  -command [list ::kbgui::_ctxDelete]
    set G(ctxmenu) $m
    set G(ctxCat) ""
    bind [$tree bodytag] <Button-3> +[list ::kbgui::_ctxPopup $tree %x %y %X %Y]
}

proc ::kbgui::_ctxPopup {tree x y X Y} {
    variable G
    # keep an existing multi-selection; otherwise select the row under the cursor
    if {[llength [$tree curselection]] <= 1} {
        event generate [$tree bodypath] <Button-1> -x $x -y $y
        event generate [$tree bodypath] <ButtonRelease-1> -x $x -y $y
        update idletasks
    }
    set sel [$tree curselection]
    if {![llength $sel]} return
    set G(ctxCat) [lindex [$tree get [lindex $sel 0]] 1]
    tk_popup $G(ctxmenu) $X $Y
}

proc ::kbgui::_ctxNewChild {} {
    variable G
    if {$G(ctxCat) eq ""} return
    set n [_promptName "Neue Unterkategorie unter \"[_catLabel $G(ctxCat)]\"" ""]
    if {$n ne ""} { _newChildDo $G(ctxCat) $n }
}
proc ::kbgui::_ctxRename {} {
    variable G
    if {$G(ctxCat) eq ""} return
    set n [_promptName "Kategorie umbenennen" [_catName $G(ctxCat)]]
    if {$n ne ""} { _renameDo $G(ctxCat) $n }
}
proc ::kbgui::_ctxDelete {} {
    variable G
    set ids [_selectedCatIds]
    if {![llength $ids]} return
    set n [llength $ids]
    if {$n == 1} {
        set msg "Kategorie \"[_catLabel [lindex $ids 0]]\" loeschen?"
    } else {
        set msg "$n Kategorien loeschen?"
    }
    append msg "\n\nUnterkategorien und Eintraege wandern jeweils zur Elternkategorie."
    if {[tk_messageBox -parent [winfo toplevel $G(tree)] -type yesno -icon question \
            -title "Kategorie loeschen" -message $msg]} {
        _deleteCatsDo $ids
    }
}

# ids of all categories selected in the tree (falls back to the ctx category)
proc ::kbgui::_selectedCatIds {} {
    variable G
    set ids {}
    foreach r [$G(tree) curselection] { lappend ids [lindex [$G(tree) get $r] 1] }
    if {![llength $ids] && $G(ctxCat) ne ""} { set ids [list $G(ctxCat)] }
    return $ids
}

# --- the work, separated from the prompts so it is testable -----------------
proc ::kbgui::_newChildDo {parentId name} {
    variable G
    set name [string trim $name]
    if {$name eq ""} return
    ::kb::store::categoryAdd $G(store) $name $parentId
    refreshCategories; showAll
    status "Unterkategorie angelegt: $name"
}
proc ::kbgui::_renameDo {id name} {
    variable G
    set name [string trim $name]
    if {$name eq ""} return
    ::kb::store::categoryRename $G(store) $id $name
    refreshCategories; showAll
    status "Umbenannt: $name"
}
proc ::kbgui::_deleteCatDo {id} {
    variable G
    ::kb::store::categoryDelete $G(store) $id
    if {$G(curCat) eq $id} { set G(curCat) "" }
    refreshCategories; showAll
    status "Kategorie geloescht"
}

# delete several categories at once; testable without a dialog.
proc ::kbgui::_deleteCatsDo {ids} {
    variable G
    foreach id $ids { catch {::kb::store::categoryDelete $G(store) $id} }
    if {$G(curCat) in $ids} { set G(curCat) "" }
    refreshCategories; showAll
    status "[llength $ids] Kategorie[expr {[llength $ids] == 1 ? {} : {n}}] geloescht"
    return [llength $ids]
}

# modal single-line prompt; returns the trimmed text, or "" on cancel/empty.
proc ::kbgui::_promptName {title {default ""}} {
    variable G
    set dlg .kbprompt
    catch {destroy $dlg}
    toplevel $dlg
    wm title $dlg $title
    wm transient $dlg [winfo toplevel $G(tree)]
    set ::kbgui::_promptResult ""
    set ::kbgui::_promptVal $default
    ttk::label $dlg.l -text $title
    ttk::entry $dlg.e -textvariable ::kbgui::_promptVal -width 40
    ttk::frame $dlg.b
    ttk::button $dlg.b.ok -text OK -command {set ::kbgui::_promptResult ok}
    ttk::button $dlg.b.c  -text Abbrechen -command {set ::kbgui::_promptResult cancel}
    grid $dlg.b.ok $dlg.b.c -padx 4
    grid $dlg.l -sticky w  -padx 8 -pady {8 2}
    grid $dlg.e -sticky ew -padx 8
    grid $dlg.b -sticky e  -padx 8 -pady 8
    grid columnconfigure $dlg 0 -weight 1
    bind $dlg.e <Return> {set ::kbgui::_promptResult ok}
    bind $dlg   <Escape> {set ::kbgui::_promptResult cancel}
    after idle [list focus $dlg.e]
    catch {grab $dlg}
    tkwait variable ::kbgui::_promptResult
    catch {grab release $dlg}
    set val [string trim $::kbgui::_promptVal]
    destroy $dlg
    return [expr {$::kbgui::_promptResult eq "ok" ? $val : ""}]
}

# --- import a wissen-*.md via a file dialog ---------------------------------
proc ::kbgui::import {} {
    variable G
    set path [tk_getOpenFile -parent [winfo toplevel $G(list)] \
        -title "Wissensdatei importieren (wissen-*.md)" \
        -filetypes {{Markdown {.md .markdown}} {Alle *}}]
    if {$path eq ""} return
    importFile $path
}

# do the actual import + refresh (separated so it is testable without a dialog)
proc ::kbgui::importFile {path} {
    variable G
    if {[catch {::kb::import::file $G(store) $path} n]} {
        status "Import fehlgeschlagen: $n"
        return 0
    }
    refreshCategories
    if {$G(curCat) ne ""} { onCategoryId $G(curCat) } else { showAll }
    status "$n Eintraege importiert aus [file tail $path]"
    return $n
}

# --- export the whole store to a wissen-*.md via a file dialog --------------
proc ::kbgui::export {} {
    variable G
    set path [tk_getSaveFile -parent [winfo toplevel $G(list)] \
        -title "Wissensbasis als Markdown exportieren" -defaultextension .md \
        -filetypes {{Markdown {.md .markdown}} {Alle *}}]
    if {$path eq ""} return
    exportFile $path
}

proc ::kbgui::exportFile {path} {
    variable G
    if {[catch {::kb::export::file $G(store) $path} n]} {
        status "Export fehlgeschlagen: $n"
        return 0
    }
    status "Exportiert nach [file tail $path] ($n Zeichen)"
    return $n
}

proc ::kbgui::delete {} {
    variable G
    set ids [_selectedEntryIds]
    if {![llength $ids]} { status "Kein Eintrag gewaehlt"; return }
    set n [llength $ids]
    if {$n == 1} {
        set e [::kb::store::entryGet $G(store) [lindex $ids 0]]
        set msg "Eintrag \"[expr {$e ne "" ? [dict get $e title] : "?"}]\" loeschen?"
    } else {
        set msg "$n Eintraege loeschen?"
    }
    if {![tk_messageBox -parent [winfo toplevel $G(list)] -type yesno \
            -icon question -title "Loeschen" -message $msg]} return
    _deleteEntries $ids
    status "Geloescht: $n Eintrag[expr {$n == 1 ? {} : {e}}]"
}

# entry ids currently selected in the list (falls back to the active entry)
proc ::kbgui::_selectedEntryIds {} {
    variable G
    set ids {}
    foreach r [$G(list).tbl curselection] {
        if {$r >= 0 && $r < [llength $G(ids)]} { lappend ids [lindex $G(ids) $r] }
    }
    if {![llength $ids] && $G(curEntry) ne ""} { set ids [list $G(curEntry)] }
    return $ids
}

# delete the given entry ids + refresh; testable without a dialog.
proc ::kbgui::_deleteEntries {ids} {
    variable G
    foreach id $ids { ::kb::store::entryDelete $G(store) $id }
    ::kb::store::pruneTags $G(store)
    _refreshTagList
    _clearPreview
    if {$G(curCat) ne ""} { onCategoryId $G(curCat) } else { showAll }
    return [llength $ids]
}

# --- main -------------------------------------------------------------------
proc ::kbgui::main {{dbfile ""}} {
    if {$dbfile eq ""} {
        set dir [file join [expr {[info exists ::env(XDG_DATA_HOME)] ?
            $::env(XDG_DATA_HOME) : [file join $::env(HOME) .local share]}] knowledge-base]
        file mkdir $dir
        set dbfile [file join $dir wissen.db]
    }
    set store [::kb::store::openSqlite $dbfile]
    build . $store
}

if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    ::kbgui::main [lindex $argv 0]
}
