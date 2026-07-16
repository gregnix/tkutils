#!/usr/bin/env wish
# tkudesigner -- a visual Tcl/Tk GUI designer (DESIGN ONLY, no code export).
# The shared render core now lives in the package tkutils::tkurender; this file
# is the editor application layer (palette, hierarchy, properties, undo, I/O).
#
# Pure Tk/ttk, runs on Tcl/Tk 8.6 and 9.0.

package require Tcl 8.6-
package require Tk 8.6-

# tclutils/tkutils modules: shared path bootstrap (env override + platform defaults)
if {![namespace exists ::tkupaths]} {
    source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]
}
package require tkutils::tkurender
package require tkutils::tkuwheel
namespace eval ::tkudesigner { namespace path ::tkurender }

proc ::tkudesigner::applyName {id var} {
    upvar #0 $var v
    if {[nodeName $id] eq [string trim $v]} return
    recordUndo
    setName $id $v
    refreshTree
}

# ===========================================================================
# Preview  (a real Toplevel .pv = the designed window)
# ===========================================================================
proc ::tkudesigner::rebuildPreview {} {
    namespace upvar ::tkurender D D
    set pv .pv
    if {![winfo exists $pv]} {
        toplevel $pv
        wm geometry $pv +560+120
        bind $pv <Destroy> {if {"%W" eq ".pv"} {::tkudesigner::onPreviewClosed}}
    }
    wm title $pv $D(title)
    array unset D wpath,*       ;# node id -> rendered Tk widget path
    # wipe: detach the menubar FIRST (else destroy fails while it is the active
    # -menu, survives, and the next render collides on the same name)
    catch {$pv configure -menu {}}
    catch {destroy $pv.menubar}
    foreach c [winfo children $pv] { destroy $c }

    # render the root content directly into pv
    renderChildren $D(root) $pv $pv
    highlightSelection
    refreshStatus "Preview rebuilt"
}
proc ::tkudesigner::applyTabLabel {id var} {
    upvar #0 $var v
    set cur ""; catch {set cur [nodeOpt $id text]}
    if {$cur eq $v} return
    recordUndo
    setOpt $id text $v
    rebuildPreview
    refreshTree
}
proc ::tkudesigner::selectFromPreview {id} {
    namespace upvar ::tkurender D D
    if {![info exists D(tv)]} return   ;# no editor (e.g. built via tkuload)
    set D(sel) $id
    syncTreeSelection
    showProps
    highlightSelection
}
proc ::tkudesigner::onPreviewClosed {} {
    refreshStatus "Preview window closed -- use View > Show preview to reopen"
}

# Tk path of the widget rendered for a node ("" if none, e.g. menubar/menu)
proc ::tkudesigner::previewWidgetOf {id} {
    namespace upvar ::tkurender D D
    if {[info exists D(wpath,$id)]} { return $D(wpath,$id) }
    return ""
}

# draw a thin coloured outline around the selected widget in the preview
proc ::tkudesigner::highlightSelection {} {
    namespace upvar ::tkurender D D
    if {[info exists D(markers)]} { foreach m $D(markers) { catch {destroy $m} } }
    set D(markers) {}
    set id $D(sel)
    if {$id eq "" || $id eq $D(root)} return
    set w [previewWidgetOf $id]
    if {$w eq "" || ![winfo exists $w]} return
    update idletasks
    if {![winfo ismapped $w]} return
    set parent [winfo parent $w]
    set x  [winfo x $w]; set y  [winfo y $w]
    set ww [winfo width $w]; set wh [winfo height $w]
    if {$ww <= 2 || $wh <= 2} return
    set col #ff3b30
    set t 2
    foreach {nm px py pw ph} [list \
            t  $x                   $y                   $ww $t  \
            b  $x                   [expr {$y+$wh-$t}]   $ww $t  \
            l  $x                   $y                   $t  $wh \
            r  [expr {$x+$ww-$t}]   $y                   $t  $wh] {
        set m $parent.__sel_$nm
        catch {destroy $m}
        frame $m -background $col -borderwidth 0 -highlightthickness 0 -takefocus 0
        place $m -x $px -y $py -width $pw -height $ph
        raise $m
        lappend D(markers) $m
    }
}

# ===========================================================================
# Designer UI  (palette | tree | properties + status)
# ===========================================================================
proc ::tkudesigner::buildUI {} {
    set ::tkurender::selectCmd ::tkudesigner::selectFromPreview
    namespace upvar ::tkurender D D
    wm title . "tkudesigner -- GUI design"
    wm geometry . 600x660+10+80

    # menubar of the designer itself
    set mb [menu .menu -tearoff 0]
    . configure -menu $mb
    set mf [menu $mb.file -tearoff 0]
    $mb add cascade -label "File" -menu $mf
    $mf add command -label "New"       -command ::tkudesigner::cmdNew
    $mf add command -label "Open..."   -command ::tkudesigner::cmdOpen
    $mf add command -label "Save..."   -command ::tkudesigner::cmdSave
    $mf add separator
    $mf add command -label "Quit"      -command {destroy .}
    set me [menu $mb.edit -tearoff 0]
    $mb add cascade -label "Edit" -menu $me
    $me add command -label "Undo" -accelerator "Ctrl+Z" -command ::tkudesigner::undo
    $me add command -label "Redo" -accelerator "Ctrl+Y" -command ::tkudesigner::redo
    bind . <Control-z> {::tkudesigner::undo; break}
    bind . <Control-Z> {::tkudesigner::redo; break}
    bind . <Control-y> {::tkudesigner::redo; break}
    set vm [menu $mb.view -tearoff 0]
    $mb add cascade -label "View" -menu $vm
    $vm add command -label "Show preview"    -command ::tkudesigner::rebuildPreview
    $vm add command -label "Window title..." -command ::tkudesigner::cmdTitle
    $vm add separator
    set tm [menu $vm.theme -tearoff 0]
    $vm add cascade -label "Theme" -menu $tm
    set ::tkurender::D(theme) [ttk::style theme use]
    foreach th [lsort [ttk::style theme names]] {
        $tm add radiobutton -label $th -value $th \
            -variable ::tkurender::D(theme) \
            -command [list ::tkudesigner::setTheme $th]
    }

    # toolbar
    set tb [ttk::frame .tb -padding 2]
    pack $tb -side top -fill x
    foreach {lbl cmd} {New cmdNew Open cmdOpen Save cmdSave Delete cmdDelete Preview rebuildPreview} {
        ttk::button $tb.b$lbl -text $lbl -command ::tkudesigner::$cmd
        pack $tb.b$lbl -side left -padx 1
    }

    # statusbar
    set sb [ttk::label .sb -relief sunken -anchor w -padding {4 2} -textvariable ::tkurender::D(status)]
    pack $sb -side bottom -fill x

    # main paned area
    set pw [ttk::panedwindow .pw -orient horizontal]
    pack $pw -side top -fill both -expand 1 -padx 2 -pady 2

    # left: palette + tree
    set left [ttk::frame $pw.left]
    $pw add $left -weight 1
    set lpw [ttk::panedwindow $left.lpw -orient vertical]
    pack $lpw -fill both -expand 1
    set ptop [ttk::frame $lpw.ptop]; $lpw add $ptop -weight 3
    set pbot [ttk::frame $lpw.pbot]; $lpw add $pbot -weight 2
    buildPalette $ptop
    buildTree $pbot

    # right: properties (scrollable)
    set right [ttk::labelframe $pw.right -text "Properties" -padding 4]
    $pw add $right -weight 1
    set D(propframe) [scrollableArea $right]
}
proc ::tkudesigner::scrollableArea {parent} {
    set cv [canvas $parent.c -highlightthickness 0 -borderwidth 0 -width 1 -height 1]
    set sb [ttk::scrollbar $parent.sb -orient vertical -command [list $cv yview]]
    $cv configure -yscrollcommand [list $sb set]
    pack $sb -side right -fill y
    pack $cv -side left -fill both -expand 1
    set inner [ttk::frame $cv.inner]
    set win [$cv create window 0 0 -anchor nw -window $inner]
    bind $inner <Configure> [list ::tkudesigner::palScroll $cv $inner]
    bind $cv    <Configure> [list $cv itemconfigure $win -width %w]
    # forward the wheel to the canvas; -dynamic 1 keeps buttons/fields added
    # later (see buildPalette / property editors) covered automatically.
    ::tkutils::tkuwheel::redirect $cv $inner -dynamic 1
    ::tkutils::tkuwheel::redirect $cv $cv
    after idle [list ::tkudesigner::palScroll $cv $inner]
    return $inner
}
proc ::tkudesigner::buildPalette {parent} {
    namespace upvar ::tkurender PAL PAL
    set pf [ttk::labelframe $parent.pal -text "Palette  (add to selection)" -padding 2]
    pack $pf -fill both -expand 1 -padx 2 -pady 2
    set inner [scrollableArea $pf]
    # group by category in a fixed order
    foreach cat {Container Chrome Widget Advanced tkutils} {
        ttk::label $inner.h$cat -text $cat -font TkSmallCaptionFont
        pack $inner.h$cat -anchor w -pady {4 0}
        set row [ttk::frame $inner.r$cat]
        pack $row -fill x
        set i 0
        foreach type [lsort [array names PAL]] {
            if {[lindex $PAL($type) 0] ne $cat} continue
            set b $row.b$type
            set lbl [lindex $PAL($type) 1]
            set avail [pkgAvail $type]
            if {!$avail} { append lbl " (n/a)" }
            ttk::button $b -text $lbl -width 14 \
                -command [list ::tkudesigner::cmdAdd $type]
            if {!$avail} { $b state disabled }
            grid $b -row [expr {$i/2}] -column [expr {$i%2}] -sticky ew -padx 1 -pady 1
            incr i
        }
        grid columnconfigure $row 0 -weight 1
        grid columnconfigure $row 1 -weight 1
    }
    # Wheel coverage of the freshly created buttons is handled automatically
    # by the -dynamic redirect in scrollableArea.
}
# update the scroll region to the inner frame's *current* requested size
proc ::tkudesigner::palScroll {cv inner} {
    $cv configure -scrollregion [list 0 0 [winfo reqwidth $inner] [winfo reqheight $inner]]
}
proc ::tkudesigner::buildTree {parent} {
    namespace upvar ::tkurender D D
    set tf [ttk::labelframe $parent.tree -text "Hierarchy" -padding 2]
    pack $tf -side top -fill both -expand 1 -padx 2 -pady 2
    set tv [ttk::treeview $tf.tv -show tree -selectmode browse]
    set vsb [ttk::scrollbar $tf.vsb -orient vertical -command [list $tf.tv yview]]
    $tv configure -yscrollcommand [list $vsb set]
    grid $tv $vsb -sticky nsew
    grid rowconfigure $tf 0 -weight 1
    grid columnconfigure $tf 0 -weight 1
    set D(tv) $tv
    $tv tag configure dropInto  -background #cfe8cf
    $tv tag configure dropAfter -background #cfe3ff
    bind $tv <<TreeviewSelect>> ::tkudesigner::onTreeSelect
    # drag & drop to reparent / reorder (added alongside the class bindings)
    bind $tv <ButtonPress-1>   {+::tkudesigner::dragStart %x %y}
    bind $tv <B1-Motion>       {+::tkudesigner::dragMotion %x %y}
    bind $tv <ButtonRelease-1> {+::tkudesigner::dragDrop %x %y}
}

# ----- tree population -----------------------------------------------------
proc ::tkudesigner::refreshTree {} {
    namespace upvar ::tkurender D D
    set tv $D(tv)
    $tv delete [$tv children {}]
    insertTreeNode $D(root) {}
    syncTreeSelection
}
proc ::tkudesigner::insertTreeNode {id parentItem} {
    namespace upvar ::tkurender D D
    set type [nodeType $id]
    set lbl $type
    set opts [dict get $D(nodes) $id opts]
    if {[dict exists $opts text]}  { append lbl "  \u201c[dict get $opts text]\u201d" }
    if {[dict exists $opts label]} { append lbl "  \u201c[dict get $opts label]\u201d" }
    set nm [nodeName $id]
    if {$nm ne ""} { append lbl "  ($nm)" }
    $D(tv) insert $parentItem end -id $id -text $lbl -open 1
    foreach cid [dict get $D(kids) $id] { insertTreeNode $cid $id }
}
proc ::tkudesigner::syncTreeSelection {} {
    namespace upvar ::tkurender D D
    if {![info exists D(tv)]} return
    if {$D(sel) ne "" && [$D(tv) exists $D(sel)]} {
        $D(tv) selection set $D(sel)
        $D(tv) see $D(sel)
    }
}
proc ::tkudesigner::onTreeSelect {} {
    namespace upvar ::tkurender D D
    set s [$D(tv) selection]
    if {[llength $s]} { set D(sel) [lindex $s 0]; showProps; highlightSelection }
}

# ----- drag & drop (reparent / reorder) ------------------------------------
proc ::tkudesigner::isDescendant {a b} {
    # true if a is b or a lies inside b's subtree
    namespace upvar ::tkurender D D
    set cur $a
    while {$cur ne ""} {
        if {$cur eq $b} { return 1 }
        set cur [dict get $D(parent) $cur]
    }
    return 0
}

# may $src become a child of container node $dst?
proc ::tkudesigner::canDrop {src dst} {
    namespace upvar ::tkurender D D
    if {$src eq "" || $dst eq ""} { return 0 }
    if {$src eq $D(root)} { return 0 }
    if {$src eq $dst} { return 0 }
    if {[isDescendant $dst $src]} { return 0 }   ;# no drop into own subtree
    set st [nodeType $src]
    set dt [nodeType $dst]
    switch -- $st {
        menu     { return [expr {$dt eq "menubar"}] }
        menuitem { return [expr {$dt eq "menu"}] }
        toolbutton { return [expr {$dt eq "toolbar"}] }
        menubar  { return [expr {$dst eq $D(root)}] }
    }
    if {$dt in {menubar menu}} { return 0 }
    if {$dt eq "scrollarea"} {
        set others [lsearch -all -inline -not -exact [dict get $D(kids) $dst] $src]
        if {[llength $others] >= 1} { return 0 }
    }
    return [expr {[isContainer $dt] || $dt eq "toolbar" || $dst eq $D(root)}]
}
proc ::tkudesigner::detach {id} {
    namespace upvar ::tkurender D D
    set p [dict get $D(parent) $id]
    if {$p ne ""} {
        dict set D(kids) $p [lsearch -all -inline -not -exact [dict get $D(kids) $p] $id]
    }
}
proc ::tkudesigner::moveInto {src dst} {
    namespace upvar ::tkurender D D
    detach $src
    dict lappend D(kids) $dst $src
    dict set D(parent) $src $dst
}
proc ::tkudesigner::moveAfter {src ref} {
    namespace upvar ::tkurender D D
    set newp [dict get $D(parent) $ref]
    detach $src
    set lst [dict get $D(kids) $newp]
    set idx [lsearch -exact $lst $ref]
    set lst [linsert $lst [expr {$idx+1}] $src]
    dict set D(kids) $newp $lst
    dict set D(parent) $src $newp
}
proc ::tkudesigner::dragStart {x y} {
    namespace upvar ::tkurender D D
    set D(drag,src)    [$D(tv) identify item $x $y]
    set D(drag,active) 0
    set D(drag,x) $x; set D(drag,y) $y
    set D(drag,tgt) ""
}
proc ::tkudesigner::dragMotion {x y} {
    namespace upvar ::tkurender D D
    if {![info exists D(drag,src)] || $D(drag,src) eq ""} return
    if {!$D(drag,active)} {
        if {abs($x-$D(drag,x)) < 4 && abs($y-$D(drag,y)) < 4} return
        set D(drag,active) 1
        $D(tv) configure -cursor hand2
    }
    set over [$D(tv) identify item $x $y]
    if {$over ne $D(drag,tgt)} {
        clearDropHint
        set D(drag,tgt) $over
        set src $D(drag,src)
        if {$over ne "" && $over ne $src && ![isDescendant $over $src]} {
            if {[canDrop $src $over]} {
                $D(tv) item $over -tags dropInto
                refreshStatus "\u2192 in \u201c[$D(tv) item $over -text]\u201d"
            } else {
                set p [dict get $D(parent) $over]
                if {$p ne "" && [canDrop $src $p]} {
                    $D(tv) item $over -tags dropAfter
                    refreshStatus "\u2192 nach \u201c[$D(tv) item $over -text]\u201d"
                } else {
                    refreshStatus "\u2717 hier nicht ablegbar"
                }
            }
        }
    }
}
proc ::tkudesigner::clearDropHint {} {
    namespace upvar ::tkurender D D
    if {[info exists D(drag,tgt)] && $D(drag,tgt) ne "" && [$D(tv) exists $D(drag,tgt)]} {
        $D(tv) item $D(drag,tgt) -tags {}
    }
}
proc ::tkudesigner::dragDrop {x y} {
    namespace upvar ::tkurender D D
    set wasActive [expr {[info exists D(drag,active)] && $D(drag,active)}]
    clearDropHint
    catch {$D(tv) configure -cursor {}}
    if {!$wasActive} { set D(drag,src) ""; return }   ;# was a click, not a drag
    set src $D(drag,src)
    set D(drag,active) 0; set D(drag,src) ""
    set tgt [$D(tv) identify item $x $y]
    if {$src eq "" || $tgt eq "" || $src eq $tgt} { return }
    if {[isDescendant $tgt $src]} { refreshStatus "Cannot drop into own subtree"; return }

    if {[canDrop $src $tgt]} {
        recordUndo
        moveInto $src $tgt
    } else {
        set p [dict get $D(parent) $tgt]
        if {$p ne "" && [canDrop $src $p]} {
            recordUndo
            moveAfter $src $tgt
        } else {
            refreshStatus "Cannot drop [nodeType $src] there"
            return
        }
    }
    set D(sel) $src
    rebuildPreview
    refreshTree
    showProps
    refreshStatus "Moved [labelOf [nodeType $src]]"
}

# ----- property panel ------------------------------------------------------
proc ::tkudesigner::showProps {} {
    namespace upvar ::tkurender D D
    namespace upvar ::tkurender PAL PAL
    set f $D(propframe)
    foreach c [winfo children $f] { destroy $c }
    set id $D(sel)
    if {$id eq ""} return
    set type [nodeType $id]

    ttk::label $f.kind -text "[labelOf $type]   ($id)" -font TkHeadingFont
    pack $f.kind -anchor w -pady {0 6}

    # --- property grid: two columns "Eigenschaft | Wert" -------------------
    set g [ttk::frame $f.grid]
    pack $g -fill x
    grid columnconfigure $g 0 -minsize 92 -weight 0
    grid columnconfigure $g 1 -weight 1
    ttk::label $g.h0 -text "Eigenschaft" -anchor w -font TkCaptionFont
    ttk::label $g.h1 -text "Wert"        -anchor w -font TkCaptionFont
    grid $g.h0 $g.h1 -sticky ew -padx 2 -pady {0 2}
    ttk::separator $g.hsep -orient horizontal
    grid $g.hsep -column 0 -columnspan 2 -sticky ew -pady {0 3}

    # symbolic name (handle for host apps / the loader's byName map)
    if {$id ne $D(root)} {
        ttk::label $g.lname -text "name" -anchor e
        set nvar ::tkurender::D(edit,_name)
        set $nvar [nodeName $id]
        ttk::entry $g.ename -textvariable $nvar
        bind $g.ename <Return>   [list ::tkudesigner::applyName $id $nvar]
        bind $g.ename <FocusOut> [list ::tkudesigner::applyName $id $nvar]
        grid $g.lname $g.ename -sticky ew -padx 2 -pady 1
        grid configure $g.lname -sticky e
    }

    # option editors
    foreach spec [optspecOf $type] {
        lassign $spec o ed def
        ttk::label $g.l$o -text $o -anchor e
        set var ::tkurender::D(edit,$o)
        set $var [nodeOpt $id $o]
        switch -- $ed {
            bool {
                ttk::checkbutton $g.e$o -variable $var \
                    -command [list ::tkudesigner::applyOpt $id $o $var]
            }
            choice {
                set vals [lrange $spec 3 end]
                ttk::combobox $g.e$o -state readonly -values $vals -textvariable $var
                bind $g.e$o <<ComboboxSelected>> [list ::tkudesigner::applyOpt $id $o $var]
            }
            default {
                ttk::entry $g.e$o -textvariable $var
                bind $g.e$o <Return>   [list ::tkudesigner::applyOpt $id $o $var]
                bind $g.e$o <FocusOut> [list ::tkudesigner::applyOpt $id $o $var]
            }
        }
        grid $g.l$o $g.e$o -sticky ew -padx 2 -pady 1
        grid configure $g.l$o -sticky e
    }

    # geometry / arrangement (not for chrome that self-packs, not for root)
    if {$type ni {menubar menu menuitem toolbar toolbutton statusbar} && $id ne $D(root)} {
        showGeomEditor $f $id
    }
    # Wheel coverage of the freshly created property fields is handled
    # automatically by the -dynamic redirect on the propframe (scrollableArea).
    after idle [list ::tkudesigner::palScroll [winfo parent $f] $f]
}
proc ::tkudesigner::showGeomEditor {f id} {
    namespace upvar ::tkurender D D
    set pid [dict get $D(parent) $id]
    set ptype [expr {$pid eq "" ? "root" : [nodeType $pid]}]

    ttk::separator $f.gsep -orient horizontal; pack $f.gsep -fill x -pady 6
    if {[usesGenericLayout $ptype]} {
        set plyt [nodeLayout $pid]
        ttk::label $f.gh -text "Placement  (parent uses $plyt)" -font TkHeadingFont
        pack $f.gh -anchor w
        switch -- $plyt {
            grid {
                geomRow    $f $id row 6
                geomRow    $f $id column 6
                geomChoice $f $id sticky [list "" n s e w ns ew nsew]
                geomRow    $f $id columnspan 6
                geomRow    $f $id rowspan 6
                geomRow    $f $id padx 6
                geomRow    $f $id pady 6
            }
            place {
                geomRow    $f $id x 6
                geomRow    $f $id y 6
                geomChoice $f $id anchor {nw n ne w center e sw s se}
            }
            default {
                geomChoice $f $id side {top bottom left right}
                geomChoice $f $id fill {none x y both}
                geomChoice $f $id expand {0 1}
                geomRow    $f $id padx 6
                geomRow    $f $id pady 6
            }
        }
    } else {
        ttk::label $f.gh -text "Managed by parent ($ptype)" -font TkHeadingFont
        pack $f.gh -anchor w
        if {$ptype in {notebook scrollednotebook plainnotebook}} {
            set row [ttk::frame $f.gtab]; pack $row -fill x -pady 2
            ttk::label $row.l -text "tab label" -width 10 -anchor w; pack $row.l -side left
            set var ::tkurender::D(edit,tablabel)
            set ::tkurender::D(edit,tablabel) [tabLabelOf $id]
            ttk::entry $row.e -textvariable $var -width 16
            bind $row.e <Return>   [list ::tkudesigner::applyTabLabel $id $var]
            bind $row.e <FocusOut> [list ::tkudesigner::applyTabLabel $id $var]
            pack $row.e -side left
        }
    }

    # if THIS node lays out its own children generically, offer a child-layout
    if {[usesGenericLayout [nodeType $id]] && $id ne $D(root)} {
        ttk::separator $f.lsep -orient horizontal; pack $f.lsep -fill x -pady 6
        ttk::label $f.lh -text "Child layout" -font TkHeadingFont; pack $f.lh -anchor w
        set var ::tkurender::D(edit,layout)
        set ::tkurender::D(edit,layout) [nodeLayout $id]
        set lr [ttk::frame $f.lrow]; pack $lr -fill x -pady 2
        ttk::label $lr.l -text "layout" -width 10 -anchor w; pack $lr.l -side left
        ttk::combobox $lr.e -state readonly -values {pack grid place} -textvariable $var -width 10
        bind $lr.e <<ComboboxSelected>> [list ::tkudesigner::applyChildLayout $id $var]
        pack $lr.e -side left
        if {[nodeLayout $id] eq "grid"} {
            stretchRow $f $id colstretch "stretch cols"
            stretchRow $f $id rowstretch "stretch rows"
        }
    }
}
# editor for a space-separated list of column/row indices that should expand
proc ::tkudesigner::stretchRow {f id which label} {
    set row [ttk::frame $f.s$which]; pack $row -fill x -pady 1
    ttk::label $row.l -text $label -width 12 -anchor w; pack $row.l -side left
    set var ::tkurender::D(edit,s,$which)
    set ::tkurender::D(edit,s,$which) [nodeStretch $id $which]
    ttk::entry $row.e -textvariable $var -width 10
    bind $row.e <Return>   [list ::tkudesigner::applyStretch $id $which $var]
    bind $row.e <FocusOut> [list ::tkudesigner::applyStretch $id $which $var]
    pack $row.e -side left
}
proc ::tkudesigner::applyStretch {id which var} {
    upvar #0 $var v
    if {[nodeStretch $id $which] eq $v} return
    recordUndo
    setStretch $id $which $v
    rebuildPreview
}
proc ::tkudesigner::geomVal {id k} {
    switch -- $k {
        row - column - x - y - padx - pady - expand { return [geomOr $id $k 0] }
        columnspan - rowspan { return [geomOr $id $k 1] }
        default { return [geomOr $id $k ""] }
    }
}
proc ::tkudesigner::geomRow {f id k w} {
    set row [ttk::frame $f.g$k]; pack $row -fill x -pady 1
    ttk::label $row.l -text $k -width 10 -anchor w; pack $row.l -side left
    set var ::tkurender::D(edit,g,$k)
    set ::tkurender::D(edit,g,$k) [::tkudesigner::geomVal $id $k]
    ttk::entry $row.e -textvariable $var -width $w
    bind $row.e <Return>   [list ::tkudesigner::applyGeomEdit $id $k $var]
    bind $row.e <FocusOut> [list ::tkudesigner::applyGeomEdit $id $k $var]
    pack $row.e -side left
}
proc ::tkudesigner::geomChoice {f id k vals} {
    set row [ttk::frame $f.g$k]; pack $row -fill x -pady 1
    ttk::label $row.l -text $k -width 10 -anchor w; pack $row.l -side left
    set var ::tkurender::D(edit,g,$k)
    set ::tkurender::D(edit,g,$k) [::tkudesigner::geomVal $id $k]
    ttk::combobox $row.e -state readonly -values $vals -textvariable $var -width 10
    bind $row.e <<ComboboxSelected>> [list ::tkudesigner::applyGeomEdit $id $k $var]
    pack $row.e -side left
}
proc ::tkudesigner::applyOpt {id o var} {
    upvar #0 $var v
    set cur ""; catch {set cur [nodeOpt $id $o]}
    if {$cur eq $v} return
    recordUndo
    setOpt $id $o $v
    rebuildPreview
    refreshTree
}
proc ::tkudesigner::applyChildLayout {id var} {
    upvar #0 $var v
    if {[nodeLayout $id] eq $v} return
    recordUndo
    setLayout $id $v
    rebuildPreview
    showProps
}
proc ::tkudesigner::applyGeomEdit {id k var} {
    upvar #0 $var v
    set cur ""; catch {set cur [dict get [dict get $::tkurender::D(nodes) $id] geom $k]}
    if {$cur eq $v} return
    recordUndo
    setGeom $id $k $v
    rebuildPreview
}

# ===========================================================================
# Commands
# ===========================================================================
# ----- undo / redo (full-model snapshots) ----------------------------------
proc ::tkudesigner::snapshot {} {
    namespace upvar ::tkurender D D
    return [dict create title $D(title) root $D(root) seq $D(seq) \
        nodes $D(nodes) kids $D(kids) parent $D(parent) sel $D(sel)]
}
proc ::tkudesigner::recordUndo {} {
    namespace upvar ::tkurender D D
    lappend D(undo) [snapshot]
    if {[llength $D(undo)] > 100} { set D(undo) [lrange $D(undo) end-99 end] }
    set D(redo) {}
}
proc ::tkudesigner::restoreSnapshot {snap} {
    namespace upvar ::tkurender D D
    dict for {k v} $snap { set D($k) $v }
    if {![dict exists $D(nodes) $D(sel)]} { set D(sel) $D(root) }
    rebuildPreview
    refreshTree
    showProps
}
proc ::tkudesigner::undo {} {
    namespace upvar ::tkurender D D
    if {![info exists D(undo)] || ![llength $D(undo)]} {
        refreshStatus "Nothing to undo"; return
    }
    lappend D(redo) [snapshot]
    set snap [lindex $D(undo) end]
    set D(undo) [lrange $D(undo) 0 end-1]
    restoreSnapshot $snap
    refreshStatus "Undo ([llength $D(undo)] left)"
}
proc ::tkudesigner::redo {} {
    namespace upvar ::tkurender D D
    if {![info exists D(redo)] || ![llength $D(redo)]} {
        refreshStatus "Nothing to redo"; return
    }
    lappend D(undo) [snapshot]
    set snap [lindex $D(redo) end]
    set D(redo) [lrange $D(redo) 0 end-1]
    restoreSnapshot $snap
    refreshStatus "Redo"
}
proc ::tkudesigner::resetHistory {} {
    namespace upvar ::tkurender D D
    set D(undo) {}; set D(redo) {}
}
proc ::tkudesigner::cmdAdd {type} {
    namespace upvar ::tkurender D D
    recordUndo
    set target $D(sel)
    # if selection cannot contain children, add to its parent (or root)
    if {![canContain $target $type]} {
        set p [dict get $D(parent) $target]
        set target [expr {$p ne "" ? $p : $D(root)}]
        if {![canContain $target $type]} { set target $D(root) }
    }
    if {[catch {addNode $type $target} id]} {
        refreshStatus "Cannot add $type here"
        return
    }
    rebuildPreview
    refreshTree
    showProps
    refreshStatus "Added [labelOf $type]"
}

# is $type allowed inside container node $cid?
proc ::tkudesigner::canContain {cid type} {
    namespace upvar ::tkurender D D
    if {$cid eq ""} { return 0 }
    set ct [nodeType $cid]
    switch -- $type {
        menu     { return [expr {$ct eq "menubar"}] }
        menuitem { return [expr {$ct eq "menu"}] }
        toolbutton { return [expr {$ct eq "toolbar" || $ct eq "tkutoolbar"}] }
    }
    # chrome bars + structural containers + root accept normal children
    if {$ct eq "menubar" || $ct eq "menu"} { return 0 }
    if {$ct eq "scrollarea" && [llength [dict get $D(kids) $cid]] >= 1} { return 0 }
    return [expr {[isContainer $ct] || $ct eq "toolbar" || $cid eq $D(root)}]
}
proc ::tkudesigner::cmdDelete {} {
    namespace upvar ::tkurender D D
    if {$D(sel) eq $D(root)} { refreshStatus "Cannot delete the root"; return }
    set t [labelOf [nodeType $D(sel)]]
    recordUndo
    deleteNode $D(sel)
    rebuildPreview
    refreshTree
    showProps
    refreshStatus "Deleted $t"
}
proc ::tkudesigner::cmdNew {} {
    recordUndo
    newModel
    rebuildPreview
    refreshTree
    showProps
    refreshStatus "New design"
}
proc ::tkudesigner::setTheme {name} {
    namespace upvar ::tkurender D D
    if {[catch {ttk::style theme use $name} err]} {
        refreshStatus "Theme '$name' not available: $err"
        return
    }
    set D(theme) $name
    rebuildPreview
    refreshStatus "Theme: $name"
}
proc ::tkudesigner::cmdTitle {} {
    namespace upvar ::tkurender D D
    set t [askString "Window title" $D(title)]
    if {$t ne ""} { set D(title) $t; rebuildPreview }
}
proc ::tkudesigner::cmdSave {} {
    namespace upvar ::tkurender D D
    set fn [tk_getSaveFile -defaultextension .tkd -filetypes {{Design {.tkd}} {All *}}]
    if {$fn eq ""} return
    set spec [serialize]
    set ch [open $fn w]
    puts $ch $spec
    close $ch
    set D(file) $fn
    refreshStatus "Saved design: [file tail $fn]"
}
proc ::tkudesigner::cmdOpen {} {
    namespace upvar ::tkurender D D
    set fn [tk_getOpenFile -filetypes {{Design {.tkd}} {All *}}]
    if {$fn eq ""} return
    set ch [open $fn r]; set spec [read $ch]; close $ch
    if {[catch {deserialize $spec} err]} {
        refreshStatus "Open failed: $err"; return
    }
    resetHistory
    rebuildPreview; refreshTree; showProps
    set D(file) $fn
    refreshStatus "Loaded design: [file tail $fn]"
}
proc ::tkudesigner::askString {title initial} {
    set t [toplevel .ask]
    wm title $t $title
    wm transient $t .
    ttk::label $t.l -text $title; pack $t.l -padx 8 -pady {8 2}
    set ::tkurender::D(askval) $initial
    ttk::entry $t.e -textvariable ::tkurender::D(askval) -width 30
    pack $t.e -padx 8 -pady 2; $t.e selection range 0 end; focus $t.e
    set bf [ttk::frame $t.bf]; pack $bf -pady 6
    ttk::button $bf.ok -text OK -command {set ::tkurender::D(askdone) 1}
    ttk::button $bf.ca -text Cancel -command {set ::tkurender::D(askdone) 0}
    pack $bf.ok $bf.ca -side left -padx 4
    bind $t.e <Return> {set ::tkurender::D(askdone) 1}
    grab $t; vwait ::tkurender::D(askdone)
    set ok $::tkurender::D(askdone)
    set val $::tkurender::D(askval)
    destroy $t
    return [expr {$ok ? $val : ""}]
}

# ===========================================================================
# Sample design (for first run + selftest)
# ===========================================================================
proc ::tkudesigner::loadSample {} {
    namespace upvar ::tkurender D D
    newModel
    set D(title) "My application"
    # menubar
    set mb [addNode menubar $D(root) 1]
    set m1 [addNode menu $mb 1]; setOpt $m1 label "File"
    set i1 [addNode menuitem $m1 1]; setOpt $i1 label "New"
    set i2 [addNode menuitem $m1 1]; setOpt $i2 label "Open"
    set i3 [addNode menuitem $m1 1]; setOpt $i3 kind separator
    set i4 [addNode menuitem $m1 1]; setOpt $i4 label "Quit"
    set m2 [addNode menu $mb 1]; setOpt $m2 label "Edit"
    # toolbar
    set tb [addNode toolbar $D(root) 1]
    foreach t {New Open Save} { set b [addNode toolbutton $tb 1]; setOpt $b text $t }
    # body: a labelframe form
    set lf [addNode labelframe $D(root) 1]; setOpt $lf text "Customer"
    setLayout $lf grid; setStretch $lf colstretch 1
    set l1 [addNode label $lf 1]; setOpt $l1 text "Name:"
    setGeom $l1 row 0; setGeom $l1 column 0; setGeom $l1 sticky e
    set e1 [addNode entry $lf 1]
    setGeom $e1 row 0; setGeom $e1 column 1; setGeom $e1 sticky ew
    set l2 [addNode label $lf 1]; setOpt $l2 text "City:"
    setGeom $l2 row 1; setGeom $l2 column 0; setGeom $l2 sticky e
    set e2 [addNode combobox $lf 1]; setOpt $e2 values "Berlin Hamburg Vreden"
    setGeom $e2 row 1; setGeom $e2 column 1; setGeom $e2 sticky ew
    set chk [addNode checkbutton $lf 1]; setOpt $chk text "active"
    setGeom $chk row 2; setGeom $chk column 1; setGeom $chk sticky w
    set rb  [addNode radiobutton $lf 1]; setOpt $rb text "business"
    setGeom $rb row 3; setGeom $rb column 1; setGeom $rb sticky w
    set scl [addNode scale $lf 1]
    setGeom $scl row 4; setGeom $scl column 0; setGeom $scl columnspan 2; setGeom $scl sticky ew
    # a tablelist inside a scrollarea
    set sa [addNode scrollarea $D(root) 1]
    set tl [addNode tablelist $sa 1]; setOpt $tl columns "Name City Sum"
    # a scrolled notebook with two pages
    set nb [addNode scrollednotebook $D(root) 1]
    set p1 [addNode frame $nb 1]; setOpt $p1 text "Details"
    set la [addNode label $p1 1]; setOpt $la text "page one content"
    set p2 [addNode frame $nb 1]; setOpt $p2 text "Notes"
    set lb [addNode label $p2 1]; setOpt $lb text "page two content"
    # statusbar
    set sb [addNode statusbar $D(root) 1]; setOpt $sb text "Ready."
    set D(sel) $lf
}

# ===========================================================================
# main / selftest
# ===========================================================================
# (1) buildApp assembles the UI and loads the default (sample) model, then
#     returns -- no argv handling, no event loop. build-app packages it with
#     -launch '::tkudesigner::buildApp .'.
proc ::tkudesigner::buildApp {{parent .}} {
    buildUI
    loadSample
    resetHistory
    rebuildPreview
    refreshTree
    showProps
    refreshStatus "Ready -- pick a palette item to add to the selection."
    return .
}

# CLI entry: build the UI, then apply command-line options.
#   --open FILE   load a saved design instead of the sample
#   --shot FILE   grab a screenshot and exit
proc ::tkudesigner::main {argv} {
    buildApp
    set oi [lsearch -exact $argv --open]
    if {$oi >= 0} {
        set fn [lindex $argv [expr {$oi+1}]]
        set ch [open $fn r]; set spec [read $ch]; close $ch
        deserialize $spec
        resetHistory; rebuildPreview; refreshTree; showProps
    } elseif {[llength $argv] && "--sample" ni $argv && "--shot" ni $argv} {
        newModel
        resetHistory; rebuildPreview; refreshTree; showProps
    }

    set si [lsearch -exact $argv --shot]
    if {$si >= 0} {
        set out [lindex $argv [expr {$si+1}]]
        if {$out eq ""} { set out designer.png }
        update idletasks; after 500; update
        # (3) Img's window grab -- self-contained, cross-platform; falls back to
        #     ImageMagick's import only if img::window is unavailable.
        if {![catch {package require img::window}]} {
            set p [image create photo -format window -data .]
            $p write $out -format png; image delete $p
        } else {
            catch {exec import -window root $out}
        }
        after 200
        exit 0
    }
}

# (1) argv0 guard: run the CLI entry when this file is the main program. Inside a
#     zipkit it does NOT fire (main.tcl sources the file); build-app uses
#     -launch '::tkudesigner::buildApp .'.
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    package require Tk 8.6-
    ::tkudesigner::main $argv
}

