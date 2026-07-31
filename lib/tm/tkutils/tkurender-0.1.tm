# tkutils::tkurender -- shared render core for tkudesigner / tkuload.
# Description: shared render core for tkudesigner / tkuload.
# Category: Tk · widgets
#
# Catalogue (type -> palette spec), the in-memory design model, deserialize,
# and the live render engine (renderNode/renderChildren + helpers). The editor
# app (tkudesigner) and the headless loader (tkuload) both build on this.
#
# Pure Tk/ttk; runs on Tcl/Tk 8.6 and 9.0. errorCode {TKUTILS DESIGNER ...}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkurender {
    namespace export addNode deleteNode deserialize isContainer labelOf newModel nodeGeom nodeLayout nodeName nodeOpt nodeType optspecOf pkgAvail pkgFor renderChildren serialize setGeom setLayout setName setOpt setStretch
    variable D                ;# the design model + ui state
    variable PAL              ;# palette catalogue
    variable selectCmd ""     ;# editor hook: {*}$selectCmd <id> on <Button-1>

    # ---- catalogue: type -> {category label kind optspec} -----------------
    # kind: container | leaf | chrome
    # optspec: list of {option editor default}  editor in {string int bool choice}
    #          choice carries its values appended: {option choice DEFAULT v1 v2 ...}
    array set PAL {}
    proc defType {type category label kind optspec} {
        variable PAL
        set PAL($type) [list $category $label $kind $optspec]
    }

    # the window root content (not shown in the palette)
    defType root        _root     "Window"        container {}

    # containers
    defType frame       Container "Frame"        container {{relief choice flat flat raised sunken groove ridge solid} {padding int 0}}
    defType labelframe  Container "LabelFrame"    container {{text string "Group"} {padding int 6}}
    defType panedwindow Container "PanedWindow"   container {{orient choice horizontal horizontal vertical}}
    defType notebook    Container "Notebook"      container {}
    # chrome
    defType menubar     Chrome    "Menubar"       chrome {}
    defType menu        Chrome    "Menu"          chrome {{label string "Menu"}}
    defType menuitem    Chrome    "Menu item"     chrome {{label string "Item"} {kind choice command command separator check}}
    defType toolbar     Chrome    "Toolbar"       chrome {{relief choice raised flat raised groove}}
    defType toolbutton  Chrome    "Tool button"   chrome {{text string "Btn"}}
    defType statusbar   Chrome    "Statusbar"     chrome {{text string "Ready"}}
    # leaf widgets
    defType label       Widget    "Label"         leaf {{text string "Label"} {anchor choice w w center e} {justify choice left left center right} {font string ""} {foreground string ""} {wraplength int 0} {state choice normal normal disabled}}
    defType button      Widget    "Button"        leaf {{text string "Button"} {state choice normal normal disabled}}
    defType entry       Widget    "Entry"         leaf {{width int 20} {font string ""} {foreground string ""} {justify choice left left center right} {show string ""} {state choice normal normal readonly disabled}}
    defType checkbutton Widget    "Checkbutton"   leaf {{text string "Check"} {state choice normal normal disabled}}
    defType combobox    Widget    "Combobox"      leaf {{width int 18} {values string "a b c"} {font string ""} {foreground string ""} {justify choice left left center right} {state choice normal normal readonly disabled}}
    defType listbox     Widget    "Listbox"       leaf {{width int 18} {height int 5} {font string ""} {foreground string ""} {state choice normal normal disabled}}
    defType treeview    Widget    "Treeview"      leaf {{height int 6} {items string ""}}
    defType text        Widget    "Text"          leaf {{width int 30} {height int 6} {font string ""} {foreground string ""} {state choice normal normal disabled}}
    defType canvas      Widget    "Canvas"        leaf {{width int 240} {height int 140} {background string "#ffffff"}}
    # more ttk widgets
    defType radiobutton Widget    "Radiobutton"   leaf {{text string "Option"} {state choice normal normal disabled}}
    defType spinbox     Widget    "Spinbox"       leaf {{width int 10} {font string ""} {foreground string ""} {show string ""} {state choice normal normal readonly disabled}}
    defType scale       Widget    "Scale"         leaf {{orient choice horizontal horizontal vertical} {state choice normal normal disabled}}
    defType progressbar Widget    "Progressbar"   leaf {{value int 40}}
    defType separator   Widget    "Separator"     leaf {{orient choice horizontal horizontal vertical}}
    # advanced (need external packages -- themed variants only)
    defType tablelist        Advanced "Tablelist"       leaf      {{columns string "Name City"} {height int 6}}
    defType scrollarea       Advanced "Scrollarea"      container {}
    defType scrollableframe  Advanced "Scrollableframe" container {}
    defType scrollednotebook Advanced "ScrolledNotebook" container {}
    defType plainnotebook    Advanced "PlainNotebook"    container {}
    defType pagesman         Advanced "PagesMan"         container {}
    # tkutils widgets (themed mega-widgets from the tkutils library)
    defType tkutoolbar   tkutils "TkuToolbar" chrome {{relief choice flat flat raised groove}}
    defType tkulabeled   tkutils "Labeled"    leaf {{label string "Name:"} {ltype choice entry entry combo spin check text}}
    defType tkuform      tkutils "Form"       leaf {{fields string "{name a label A type entry} {name b label B type entry}"}}
    defType tkunumentry  tkutils "NumEntry"   leaf {}
    defType tkudateentry tkutils "DateEntry"  leaf {}
    defType tkutimeentry tkutils "TimeEntry"  leaf {}
    defType tkutags      tkutils "Tags"       leaf {}
    defType tkusearchbar tkutils "SearchBar"  leaf {}
    defType tkustatus    tkutils "Status"     leaf {}

    proc isContainer {type} { variable PAL; expr {[lindex $PAL($type) 2] eq "container"} }
    proc optspecOf  {type} { variable PAL; lindex $PAL($type) 3 }
    proc labelOf    {type} { variable PAL; lindex $PAL($type) 1 }

    # external package needed for a type ("" = core Tk/ttk). themed variants only:
    # loading both Tablelist and Tablelist_tile (or Scrollutil/_tile) is unsupported.
    proc pkgFor {type} {
        switch -- $type {
            tablelist { return tablelist_tile }
            scrollarea - scrollableframe - scrollednotebook - plainnotebook - pagesman { return scrollutil_tile }
            tkutoolbar - tkulabeled - tkuform - tkunumentry - tkudateentry -
            tkutimeentry - tkutags - tkusearchbar - tkustatus { return tkutils::$type }
            default { return "" }
        }
    }
    # one loud warning per missing package -- the signal that must NOT be silent
    variable pkgWarned
    proc warnPkg {pkg err} {
        variable pkgWarned
        if {[info exists pkgWarned($pkg)]} return
        set pkgWarned($pkg) 1
        puts stderr "tkudesigner: Paket '$pkg' nicht ladbar: $err"
        if {[string match tkutils::* $pkg] || [string match tclutils::* $pkg]} {
            puts stderr "  -> TKUTILS_TM / TCLUTILS_TM gesetzt? (siehe startdemo.sh)"
        } elseif {$pkg in {tablelist_tile scrollutil_tile}} {
            puts stderr "  -> tablelist / scrollutil nicht in TCLLIBPATH bzw. auto_path"
        }
    }
    proc pkgAvail {type} {
        set p [pkgFor $type]
        if {$p eq ""} { return 1 }
        if {![catch {package require $p} err]} { return 1 }
        warnPkg $p $err
        return 0
    }
}

# ===========================================================================
# Model
# ===========================================================================
proc ::tkurender::clearModelKeys {} {
    variable D
    foreach k [array names D] {
        if {$k in {tv propframe status undo redo theme}} continue
        unset D($k)
    }
}
proc ::tkurender::newModel {} {
    variable D
    clearModelKeys
    set D(seq) 0
    set D(nodes) [dict create]      ;# id -> {type opts geom}
    set D(kids)  [dict create]      ;# id -> list of child ids
    set D(parent) [dict create]     ;# id -> parent id ("" for root)
    set D(sel) ""
    set D(file) ""
    set D(title) "Untitled window"
    # root content frame
    set root [addNode root "" 1]
    set D(root) $root
    set D(sel) $root
}

# create a node of $type under $parent; returns id. internal=1 skips select.
proc ::tkurender::addNode {type parent {internal 0}} {
    variable D
    if {$parent ne "" && ![dict exists $D(nodes) $parent]} {
        return -code error -errorcode {TKUTILS DESIGNER PARENT} "no such parent: $parent"
    }
    set id n[incr D(seq)]
    set opts [dict create]
    foreach spec [optspecOf $type] {
        lassign $spec o ed def
        dict set opts $o $def
    }
    set geom [dict create manager pack side top fill none expand 0 padx 2 pady 2 \
                          x 10 y 10 anchor nw \
                          row 0 column 0 sticky "" columnspan 1 rowspan 1]
    dict set D(nodes) $id [dict create type $type opts $opts geom $geom \
                               layout pack colstretch {} rowstretch {} name ""]
    dict set D(kids) $id [list]
    dict set D(parent) $id $parent
    if {$parent ne ""} {
        dict lappend D(kids) $parent $id
    }
    if {!$internal} { set D(sel) $id }
    return $id
}
proc ::tkurender::deleteNode {id} {
    variable D
    if {$id eq $D(root)} { return }    ;# never delete root
    foreach k [dict get $D(kids) $id] { deleteNode $k }
    set p [dict get $D(parent) $id]
    if {$p ne "" && [dict exists $D(kids) $p]} {
        dict set D(kids) $p [lsearch -all -inline -not -exact [dict get $D(kids) $p] $id]
    }
    dict unset D(nodes) $id
    dict unset D(kids) $id
    dict unset D(parent) $id
    if {$D(sel) eq $id} { set D(sel) [expr {$p ne "" ? $p : $D(root)}] }
}
proc ::tkurender::nodeType {id} { variable D; dict get $D(nodes) $id type }
proc ::tkurender::nodeOpt  {id o} { variable D; dict get $D(nodes) $id opts $o }
proc ::tkurender::setOpt   {id o v} { variable D; dict set D(nodes) $id opts $o $v }
proc ::tkurender::nodeGeom {id k} { variable D; dict get $D(nodes) $id geom $k }
proc ::tkurender::setGeom  {id k v} { variable D; dict set D(nodes) $id geom $k $v }
# geom accessor that tolerates keys missing in older saved files
proc ::tkurender::geomOr {id k def} {
    variable D
    set g [dict get $D(nodes) $id geom]
    expr {[dict exists $g $k] ? [dict get $g $k] : $def}
}
# child-layout of a container node (how it arranges its children); default pack
proc ::tkurender::nodeLayout {id} {
    variable D
    set n [dict get $D(nodes) $id]
    expr {[dict exists $n layout] ? [dict get $n layout] : "pack"}
}
proc ::tkurender::setLayout {id v} { variable D; dict set D(nodes) $id layout $v }
# symbolic widget name (host-app handle); empty by default
proc ::tkurender::nodeName {id} {
    variable D
    set n [dict get $D(nodes) $id]
    expr {[dict exists $n name] ? [dict get $n name] : ""}
}
proc ::tkurender::setName {id v} { variable D; dict set D(nodes) $id name [string trim $v] }
# which = colstretch | rowstretch ; list of indices that get grid -weight 1
proc ::tkurender::nodeStretch {id which} {
    variable D
    set n [dict get $D(nodes) $id]
    expr {[dict exists $n $which] ? [dict get $n $which] : {}}
}
proc ::tkurender::setStretch {id which v} { variable D; dict set D(nodes) $id $which $v }

# render the children of model-node $mid into Tk-parent $tkparent.
# $pv is the toplevel (for menubar attachment).
proc ::tkurender::renderChildren {mid tkparent pv} {
    variable D
    foreach cid [dict get $D(kids) $mid] {
        renderNode $cid $tkparent $pv
    }
}
proc ::tkurender::renderNode {id tkparent pv} {
    variable D
    set type [nodeType $id]
    set w $tkparent.w$id

    switch -- $type {
        menubar {
            set mb [menu $pv.menubar -tearoff 0]
            $pv configure -menu $mb
            foreach cid [dict get $D(kids) $id] { renderMenu $cid $mb }
            return
        }
        toolbar {
            ttk::frame $w -relief [nodeOpt $id relief] -borderwidth 1 -padding 2
            catch {pack $w -side top -fill x}
            set D(wpath,$id) $w
            foreach cid [dict get $D(kids) $id] {
                set type2 [nodeType $cid]
                if {$type2 eq "toolbutton"} {
                    ttk::button $w.b$cid -text [nodeOpt $cid text] -width 6
                    pack $w.b$cid -side left -padx 1
                    set D(wpath,$cid) $w.b$cid
                    bindSelect $w.b$cid $cid
                }
            }
            bindSelect $w $id
            return
        }
        statusbar {
            ttk::label $w -text [nodeOpt $id text] -relief sunken -anchor w -padding {4 2}
            catch {pack $w -side bottom -fill x}
            set D(wpath,$id) $w
            bindSelect $w $id
            return
        }
        tkutoolbar {
            if {![pkgAvail tkutoolbar] || [catch {tkutils::tkutoolbar::widget $w}]} {
                ttk::frame $w -relief raised -borderwidth 1 -padding 2
                ttk::label $w.na -text "tkutoolbar n/a"; pack $w.na -side left
            } else {
                foreach cid [dict get $D(kids) $id] {
                    if {[nodeType $cid] eq "toolbutton"} {
                        if {![catch {tkutils::tkutoolbar::addButton $w b$cid [nodeOpt $cid text] {}} bp]} {
                            set D(wpath,$cid) $bp
                            bindSelect $bp $cid
                        }
                    }
                }
            }
            catch {pack $w -side top -fill x}
            set D(wpath,$id) $w
            bindSelect $w $id
            return
        }
        frame       { ttk::frame $w -relief [nodeOpt $id relief] -borderwidth 1 -padding [nodeOpt $id padding] }
        labelframe  { ttk::labelframe $w -text [nodeOpt $id text] -padding [nodeOpt $id padding] }
        panedwindow { ttk::panedwindow $w -orient [nodeOpt $id orient] }
        notebook    { ttk::notebook $w }
        label       { ttk::label $w -text [nodeOpt $id text] -anchor [nodeOpt $id anchor] }
        button      { ttk::button $w -text [nodeOpt $id text] }
        entry       { ttk::entry $w -width [nodeOpt $id width] }
        checkbutton { ttk::checkbutton $w -text [nodeOpt $id text] }
        combobox    { ttk::combobox $w -width [nodeOpt $id width] -values [nodeOpt $id values] }
        listbox     { listbox $w -width [nodeOpt $id width] -height [nodeOpt $id height] }
        treeview    {
            ttk::treeview $w -height [nodeOpt $id height] -show tree
            set its ""; catch {set its [nodeOpt $id items]}
            if {$its ne ""} { catch {insertTreeItems $w {} $its} }
        }
        text        { text $w -width [nodeOpt $id width] -height [nodeOpt $id height] -highlightthickness 0 }
        canvas      { canvas $w -width [nodeOpt $id width] -height [nodeOpt $id height] \
                          -background [nodeOpt $id background] -highlightthickness 1 \
                          -relief sunken -borderwidth 1 }
        radiobutton { ttk::radiobutton $w -text [nodeOpt $id text] -value 1 }
        spinbox     { ttk::spinbox $w -from 0 -to 100 -width [nodeOpt $id width] }
        scale       { ttk::scale $w -from 0 -to 100 -value 40 -orient [nodeOpt $id orient] }
        progressbar { ttk::progressbar $w -mode determinate -value [nodeOpt $id value] -length 140 }
        separator   { ttk::separator $w -orient [nodeOpt $id orient] }
        tablelist {
            if {[pkgAvail tablelist]} {
                set titles [nodeOpt $id columns]
                set cols {}
                foreach t $titles { lappend cols 0 $t left }
                if {$cols eq ""} { set cols {0 Col left}; set titles Col }
                tablelist::tablelist $w -columns $cols -height [nodeOpt $id height] -stretch all
                set ncol [llength $titles]
                $w insert end [lrepeat $ncol "abc"]
                $w insert end [lrepeat $ncol "xyz"]
            } else {
                ttk::label $w -text "tablelist_tile missing" -relief solid -padding 6
            }
        }
        scrollarea {
            if {[pkgAvail scrollarea]} { scrollutil::scrollarea $w } \
            else { ttk::frame $w -relief solid -borderwidth 1 -padding 6 }
        }
        scrollableframe {
            if {[pkgAvail scrollableframe]} { scrollutil::scrollableframe $w } \
            else { ttk::frame $w -relief solid -borderwidth 1 -padding 6 }
        }
        scrollednotebook {
            if {[pkgAvail scrollednotebook]} { scrollutil::scrollednotebook $w } \
            else { ttk::frame $w -relief solid -borderwidth 1 -padding 6 }
        }
        plainnotebook {
            if {[pkgAvail plainnotebook]} { scrollutil::plainnotebook $w } \
            else { ttk::frame $w -relief solid -borderwidth 1 -padding 6 }
        }
        pagesman {
            if {[pkgAvail pagesman]} { scrollutil::pagesman $w } \
            else { ttk::frame $w -relief solid -borderwidth 1 -padding 6 }
        }
        tkunumentry  { tkuLeaf $w tkunumentry {tkutils::tkunumentry::widget $w} }
        tkudateentry { tkuLeaf $w tkudateentry {tkutils::tkudateentry::widget $w} }
        tkutimeentry { tkuLeaf $w tkutimeentry {tkutils::tkutimeentry::widget $w} }
        tkutags      { tkuLeaf $w tkutags {tkutils::tkutags::widget $w} }
        tkusearchbar { tkuLeaf $w tkusearchbar {tkutils::tkusearchbar::widget $w} }
        tkustatus    { tkuLeaf $w tkustatus {tkutils::tkustatus::widget $w} }
        tkulabeled   { tkuLeaf $w tkulabeled {tkutils::tkulabeled::add $w [nodeOpt $id ltype] -label [nodeOpt $id label]} }
        tkuform      { tkuLeaf $w tkuform {tkutils::tkuform::widget $w [nodeOpt $id fields]} }
        default     { ttk::label $w -text "?$type?" }
    }

    # apply common appearance options where the widget supports them
    applyAppearance $id $w

    # attach into parent according to the PARENT container type
    set pid [dict get $D(parent) $id]
    set ptype [expr {$tkparent eq $pv ? "frame" : [nodeType $pid]}]
    switch -- $ptype {
        panedwindow { catch {$tkparent add $w} }
        notebook    { $tkparent add $w -text [nodeLabelFor $id] }
        scrollednotebook { catch {$tkparent add $w -text [nodeLabelFor $id]} }
        plainnotebook    { catch {$tkparent add $w -text [nodeLabelFor $id]} }
        pagesman         { catch {$tkparent add $w} }
        scrollarea  { catch {$tkparent setwidget $w} }
        default {
            if {[catch {applyPlacement $id $w [nodeLayout $pid]} e]} {
                refreshStatus "Layout clash in [nodeType $pid]: pack/grid cannot mix"
            }
        }
    }
    bindSelect $w $id
    set D(wpath,$id) $w

    # recurse for containers -- children go into the container's content area
    if {[isContainer $type]} {
        set master [childParentOf $type $w]
        renderChildren $id $master $pv
        if {[usesGenericLayout $type] && [nodeLayout $id] eq "grid"} {
            applyGridWeights $id $master
        }
    }
}

# give the listed columns/rows a stretch weight so grid cells resize
proc ::tkurender::applyGridWeights {id master} {
    foreach c [nodeStretch $id colstretch] { catch {grid columnconfigure $master $c -weight 1} }
    foreach r [nodeStretch $id rowstretch] { catch {grid rowconfigure    $master $r -weight 1} }
}

# where children of a container widget actually live (Tk path)
proc ::tkurender::childParentOf {type w} {
    if {$type eq "scrollableframe"} {
        if {![catch {$w contentframe} cf]} { return $cf }
    }
    return $w
}
proc ::tkurender::renderMenu {id parentMenu} {
    variable D
    set type [nodeType $id]
    if {$type eq "menu"} {
        set m $parentMenu.m$id
        menu $m -tearoff 0
        $parentMenu add cascade -label [nodeOpt $id label] -menu $m
        foreach cid [dict get $D(kids) $id] { renderMenu $cid $m }
    } elseif {$type eq "menuitem"} {
        switch -- [nodeOpt $id kind] {
            separator { $parentMenu add separator }
            check     { $parentMenu add checkbutton -label [nodeOpt $id label] }
            default   { $parentMenu add command -label [nodeOpt $id label] }
        }
    }
}
proc ::tkurender::nodeLabelFor {id} {
    if {[catch {nodeOpt $id text} t]} { set t "" }
    if {$t eq ""} { set t [labelOf [nodeType $id]] }
    return $t
}
# tab label for a notebook page = its 'text' opt (empty if unset)
proc ::tkurender::tabLabelOf {id} {
    variable D
    set opts [dict get $D(nodes) $id opts]
    expr {[dict exists $opts text] ? [dict get $opts text] : ""}
}

# insert static demo items into a designer treeview.
# spec = list of nodes; a node is either a bare label (leaf) or a two-element
# list {label {child child ...}} whose children follow the same format.
proc ::tkurender::insertTreeItems {tw parent spec} {
    foreach node $spec {
        if {[llength $node] == 2} {
            lassign $node label children
        } else {
            set label $node
            set children {}
        }
        set iid [$tw insert $parent end -text $label]
        if {[llength $children]} { insertTreeItems $tw $iid $children }
    }
}
proc ::tkurender::applyAppearance {id w} {
    variable D
    set opts [dict get $D(nodes) $id opts]
    foreach o {font foreground justify wraplength show state} {
        if {![dict exists $opts $o]} continue
        set v [dict get $opts $o]
        if {$o ne "state" && $v eq ""} continue
        catch {$w configure -$o $v}
    }
}
proc ::tkurender::applyPlacement {id w mgr} {
    variable D
    set g [dict get $D(nodes) $id geom]
    switch -- $mgr {
        place {
            place $w -x [dict get $g x] -y [dict get $g y] -anchor [dict get $g anchor]
        }
        grid {
            grid $w -row [geomOr $id row 0] -column [geomOr $id column 0] \
                    -sticky [geomOr $id sticky ""] \
                    -columnspan [geomOr $id columnspan 1] -rowspan [geomOr $id rowspan 1] \
                    -padx [dict get $g padx] -pady [dict get $g pady]
        }
        default {
            pack $w -side [dict get $g side] -fill [dict get $g fill] \
                    -expand [dict get $g expand] -padx [dict get $g padx] -pady [dict get $g pady]
        }
    }
}
proc ::tkurender::tkuLeaf {w type script} {
    if {![pkgAvail $type]} {            ;# warns once, with package name + hint
        ttk::label $w -text "\u26a0 [pkgFor $type] fehlt" -relief solid -padding 4
        return
    }
    if {[catch {uplevel 1 $script} err]} {
        catch {destroy $w}
        puts stderr "tkudesigner: '$type' konnte nicht erstellt werden: $err"
        ttk::label $w -text "\u26a0 $type n/a" -relief solid -padding 4
    }
}
proc ::tkurender::bindSelect {w id} {
    variable D
    variable selectCmd
    # no editor hook (loader/embedded) -> no selection binding at all
    if {$selectCmd eq "" || ([info exists D(embedded)] && $D(embedded))} return
    bind $w <Button-1> [list {*}$selectCmd $id]
}

# containers that arrange children via pack/grid/place (vs. add/setwidget)
proc ::tkurender::usesGenericLayout {type} {
    expr {$type in {root frame labelframe scrollableframe}}
}

# design persistence (NOT code generation): a plain Tcl dict spec
proc ::tkurender::serialize {} {
    variable D
    return [dict create version 1 title $D(title) root $D(root) seq $D(seq) \
        nodes $D(nodes) kids $D(kids) parent $D(parent)]
}
proc ::tkurender::deserialize {spec} {
    variable D
    foreach k {title root seq nodes kids parent} {
        if {![dict exists $spec $k]} {
            return -code error -errorcode {TKUTILS DESIGNER SPEC} "missing key: $k"
        }
    }
    clearModelKeys
    set D(title)  [dict get $spec title]
    set D(root)   [dict get $spec root]
    set D(seq)    [dict get $spec seq]
    set D(nodes)  [dict get $spec nodes]
    set D(kids)   [dict get $spec kids]
    set D(parent) [dict get $spec parent]
    set D(sel)    $D(root)
    set D(file)   ""
    # migrate older files: backfill opts/keys added to the catalogue since save
    dict for {id node} $D(nodes) {
        set type [dict get $node type]
        if {[info exists ::tkurender::PAL($type)]} {
            set opts [dict get $node opts]
            foreach spec [optspecOf $type] {
                lassign $spec o ed def
                if {![dict exists $opts $o]} { dict set opts $o $def }
            }
            dict set node opts $opts
        }
        foreach {k dflt} {layout pack colstretch {} rowstretch {} name ""} {
            if {![dict exists $node $k]} { dict set node $k $dflt }
        }
        dict set D(nodes) $id $node
    }
}
proc ::tkurender::refreshStatus {msg} { variable D; set D(status) $msg }

package provide tkutils::tkurender 0.1
