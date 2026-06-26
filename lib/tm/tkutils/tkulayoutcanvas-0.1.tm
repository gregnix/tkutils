# tkutils::tkulayoutcanvas -- visual block layout designer on a Tk canvas
#
# Megawidget for coarse document layout: place named blocks on a paper-sized
# canvas in millimetres, snap to a grid, edit visibility and geometry in a side
# panel. Uses tclutils::tulayout for mm/px math and preset merging.
# Pure Tk. Tcl/Tk 8.6+ and 9.x compatible.
#
#   tkulayoutcanvas::widget .lc -paper a4 -blocks $blocks -definitions $defs \
#       -onchange {apply {{p blocks} { ... }}}
#   tkulayoutcanvas::getBlocks .lc
#   tkulayoutcanvas::setBlocks .lc $blocks
#   tkulayoutcanvas::select .lc $blockId
#   tkulayoutcanvas::getCanvas .lc
#   tkulayoutcanvas::redraw .lc
#   tkulayoutcanvas::configure .lc -gridmm 10
#
# Error codes: {TKUTILS TKULAYOUTCANVAS <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tulayout 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkulayoutcanvas {
    namespace export widget configure cget getBlocks setBlocks select \
        getCanvas redraw mergePreset
    variable state
    variable defaults {
        -paper a4
        -orientation portrait
        -margin 20.0
        -gridmm 5.0
        -scale 3.0
        -blocks {}
        -definitions {}
        -blockorder {}
        -onchange {}
        -showgrid 1
        -properties 1
        -width 640
        -height 480
    }
}

proc ::tkutils::tkulayoutcanvas::_require {path} {
    variable state
    if {![info exists state($path,-paper)]} {
        return -code error -errorcode {TKUTILS TKULAYOUTCANVAS NOWIDGET} \
            "unknown layout canvas '$path'"
    }
}

proc ::tkutils::tkulayoutcanvas::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    array unset state $path,*
}

proc ::tkutils::tkulayoutcanvas::_optKeys {} {
    variable defaults
    set out {}
    foreach {k v} $defaults { lappend out $k }
    return $out
}

proc ::tkutils::tkulayoutcanvas::widget {path args} {
    variable state
    variable defaults
    if {[winfo exists $path]} {
        return -code error -errorcode {TKUTILS TKULAYOUTCANVAS EXISTS} \
            "widget path '$path' already exists"
    }
    array set opts $defaults
    foreach {k v} $args {
        if {![info exists opts($k)]} {
            return -code error -errorcode {TKUTILS TKULAYOUTCANVAS OPTION} \
                "unknown option '$k'"
        }
        set opts($k) $v
    }

    ttk::frame $path
    bind $path <Destroy> [list ::tkutils::tkulayoutcanvas::_cleanup $path %W]

    foreach k [_optKeys] { set state($path,$k) $opts($k) }
    set state($path,sel) ""
    set state($path,drag) ""
    set state($path,dragX) 0
    set state($path,dragY) 0
    set state($path,syncing) 0
    lassign [::tclutils::tulayout::pageSize $opts(-paper) $opts(-orientation)] pw ph
    set state($path,pageWmm) $pw
    set state($path,pageHmm) $ph

    if {[llength $opts(-definitions)]} {
        set state($path,blocks) [::tclutils::tulayout::ensureBlocks \
            $opts(-blocks) $opts(-definitions)]
    } elseif {[llength $opts(-blocks)]} {
        set state($path,blocks) [::tclutils::tulayout::validateBlocks $opts(-blocks)]
    } else {
        set state($path,blocks) [dict create]
    }

    ttk::panedwindow $path.pw -orient horizontal
    pack $path.pw -fill both -expand 1

    ttk::frame $path.pw.view
    $path.pw add $path.pw.view -weight 3

    canvas $path.pw.view.cv -width $opts(-width) -height $opts(-height) \
        -bg "#e8e8e8" -highlightthickness 1 -highlightbackground "#bbb" \
        -xscrollcommand [list $path.pw.view.xsb set] \
        -yscrollcommand [list $path.pw.view.ysb set]
    ttk::scrollbar $path.pw.view.xsb -orient horizontal \
        -command [list $path.pw.view.cv xview]
    ttk::scrollbar $path.pw.view.ysb -orient vertical \
        -command [list $path.pw.view.cv yview]
    grid $path.pw.view.cv -row 0 -column 0 -sticky nsew
    grid $path.pw.view.ysb -row 0 -column 1 -sticky ns
    grid $path.pw.view.xsb -row 1 -column 0 -sticky ew
    grid rowconfigure $path.pw.view 0 -weight 1
    grid columnconfigure $path.pw.view 0 -weight 1

    if {$opts(-properties)} {
        ttk::labelframe $path.pw.props -text "Block" -padding 6
        $path.pw add $path.pw.props -weight 1

        listbox $path.pw.props.list -exportselection 0 -height 12 \
            -yscrollcommand [list $path.pw.props.lsb set]
        ttk::scrollbar $path.pw.props.lsb -orient vertical \
            -command [list $path.pw.props.list yview]
        grid $path.pw.props.list -row 0 -column 0 -sticky nsew
        grid $path.pw.props.lsb -row 0 -column 1 -sticky ns

        ttk::frame $path.pw.props.form
        grid $path.pw.props.form -row 1 -column 0 -columnspan 2 -sticky ew -pady {8 0}

        set row 0
        foreach {lbl key from to width} {
            "X (mm):" x 0 300 8
            "Y (mm):" y 0 400 8
            "W (mm):" w 1 300 8
            "H (mm):" h 1 120 8
        } {
            ttk::label $path.pw.props.form.l$key -text $lbl
            ttk::spinbox $path.pw.props.form.s$key -from $from -to $to -width $width \
                -command [list ::tkutils::tkulayoutcanvas::_onSpin $path $key]
            bind $path.pw.props.form.s$key <Return> \
                [list ::tkutils::tkulayoutcanvas::_onSpin $path $key]
            bind $path.pw.props.form.s$key <FocusOut> \
                [list ::tkutils::tkulayoutcanvas::_onSpin $path $key]
            grid $path.pw.props.form.l$key -row $row -column 0 -sticky w -pady 2
            grid $path.pw.props.form.s$key -row $row -column 1 -sticky ew -pady 2
            incr row
        }
        ttk::checkbutton $path.pw.props.form.show -text "Visible" \
            -command [list ::tkutils::tkulayoutcanvas::_onShow $path]
        grid $path.pw.props.form.show -row $row -column 0 -columnspan 2 -sticky w -pady 4

        grid rowconfigure $path.pw.props 0 -weight 1
        grid columnconfigure $path.pw.props 0 -weight 1
        grid columnconfigure $path.pw.props.form 1 -weight 1

        bind $path.pw.props.list <<ListboxSelect>> \
            [list ::tkutils::tkulayoutcanvas::_onListSelect $path]
    }

    _bindCanvas $path
    redraw $path
    return $path
}

proc ::tkutils::tkulayoutcanvas::configure {path args} {
    _require $path
    variable state
    if {![llength $args]} {
        set out {}
        foreach k [_optKeys] { dict set out $k $state($path,$k) }
        return $out
    }
    if {[llength $args] == 1} {
        set k [lindex $args 0]
        if {![info exists state($path,$k)]} {
            return -code error -errorcode {TKUTILS TKULAYOUTCANVAS OPTION} \
                "unknown option '$k'"
        }
        return $state($path,$k)
    }
    foreach {k v} $args {
        if {![info exists state($path,$k)]} {
            return -code error -errorcode {TKUTILS TKULAYOUTCANVAS OPTION} \
                "unknown option '$k'"
        }
        set state($path,$k) $v
    }
    if {"-paper" in $args || "-orientation" in $args} {
        lassign [::tclutils::tulayout::pageSize $state($path,-paper) \
            $state($path,-orientation)] pw ph
        set state($path,pageWmm) $pw
        set state($path,pageHmm) $ph
    }
    if {"-blocks" in $args} {
        setBlocks $path $state($path,-blocks)
        return
    }
    redraw $path
}

proc ::tkutils::tkulayoutcanvas::cget {path opt} {
    return [configure $path $opt]
}

proc ::tkutils::tkulayoutcanvas::getCanvas {path} {
    _require $path
    return $path.pw.view.cv
}

proc ::tkutils::tkulayoutcanvas::getBlocks {path} {
    _require $path
    variable state
    return $state($path,blocks)
}

proc ::tkutils::tkulayoutcanvas::setBlocks {path blocks} {
    _require $path
    variable state
    if {[llength $state($path,-definitions)]} {
        set state($path,blocks) [::tclutils::tulayout::ensureBlocks \
            $blocks $state($path,-definitions)]
    } elseif {[llength $blocks]} {
        set state($path,blocks) [::tclutils::tulayout::validateBlocks $blocks]
    } else {
        set state($path,blocks) [dict create]
    }
    set state($path,-blocks) $state($path,blocks)
    redraw $path
}

proc ::tkutils::tkulayoutcanvas::select {path id} {
    _require $path
    variable state
    if {$id ne "" && ![dict exists $state($path,blocks) $id]} {
        return -code error -errorcode {TKUTILS TKULAYOUTCANVAS BLOCK} \
            "unknown block '$id'"
    }
    set state($path,sel) $id
    _syncList $path
    _syncProps $path
    redraw $path
}

proc ::tkutils::tkulayoutcanvas::mergePreset {path preset args} {
    _require $path
    variable state
    set merged [::tclutils::tulayout::mergeBlocks $state($path,blocks) $preset {*}$args]
    setBlocks $path $merged
    return $merged
}

proc ::tkutils::tkulayoutcanvas::redraw {path} {
    _require $path
    variable state
    set c [getCanvas $path]
    $c delete all

    set s $state($path,-scale)
    set pw $state($path,pageWmm)
    set ph $state($path,pageHmm)
    set pwpx [::tclutils::tulayout::mmToPx $pw $s]
    set phpx [::tclutils::tulayout::mmToPx $ph $s]

    $c create rectangle 0 0 $pwpx $phpx -fill white -outline "#888" -width 1 -tags page

    set m $state($path,-margin)
    set mx [::tclutils::tulayout::mmToPx $m $s]
    $c create rectangle $mx $mx [expr {$pwpx - $mx}] [expr {$phpx - $mx}] \
        -outline "#ccc" -dash {4 3} -width 1 -tags margin

    if {$state($path,-showgrid)} {
        _drawGrid $path $c $pwpx $phpx $s
    }

    _paintBlocks $path

    set order [::tclutils::tulayout::blockOrder $state($path,blocks) \
        $state($path,-definitions)]
    if {[llength $state($path,-blockorder)]} {
        set order $state($path,-blockorder)
    }
    $c configure -scrollregion [list 0 0 $pwpx $phpx]
    _fillList $path $order
    _syncProps $path
}

proc ::tkutils::tkulayoutcanvas::_paintBlocks {path} {
    _require $path
    variable state
    set c [getCanvas $path]
    $c delete block

    set s $state($path,-scale)
    set order [::tclutils::tulayout::blockOrder $state($path,blocks) \
        $state($path,-definitions)]
    if {[llength $state($path,-blockorder)]} {
        set order $state($path,-blockorder)
    }

    set autoSlot 0
    foreach id $order {
        if {![dict exists $state($path,blocks) $id]} continue
        set b [dict get $state($path,blocks) $id]
        if {[dict exists $b show] && ![dict get $b show]} continue
        _drawBlock $path $c $id $b $s $autoSlot
        if {[::tclutils::tulayout::isAutoY $b]} { incr autoSlot }
    }
}

proc ::tkutils::tkulayoutcanvas::_drawGrid {path c pwpx phpx scale} {
    variable state
    set g $state($path,-gridmm)
    set step [::tclutils::tulayout::mmToPx $g $scale]
    set x 0.0
    while {$x <= $pwpx} {
        $c create line $x 0 $x $phpx -fill "#f0f0f0" -tags grid
        set x [expr {$x + $step}]
    }
    set y 0.0
    while {$y <= $phpx} {
        $c create line 0 $y $pwpx $y -fill "#f0f0f0" -tags grid
        set y [expr {$y + $step}]
    }
}

proc ::tkutils::tkulayoutcanvas::_previewY {path b autoSlot} {
    variable state
    if {![::tclutils::tulayout::isAutoY $b]} {
        return [dict get $b y]
    }
    set m $state($path,-margin)
    return [expr {$m + 12.0 * $autoSlot}]
}

proc ::tkutils::tkulayoutcanvas::_blockLabel {path id b} {
    if {[dict exists $b label] && [dict get $b label] ne ""} {
        return [dict get $b label]
    }
    return $id
}

proc ::tkutils::tkulayoutcanvas::_autoSlotFor {path id} {
    variable state
    set order [::tclutils::tulayout::blockOrder $state($path,blocks) \
        $state($path,-definitions)]
    if {[llength $state($path,-blockorder)]} { set order $state($path,-blockorder) }
    set slot 0
    foreach bid $order {
        if {$bid eq $id} { return $slot }
        if {![dict exists $state($path,blocks) $bid]} continue
        set ob [dict get $state($path,blocks) $bid]
        if {[dict exists $ob show] && ![dict get $ob show]} continue
        if {[::tclutils::tulayout::isAutoY $ob]} { incr slot }
    }
    return 0
}

proc ::tkutils::tkulayoutcanvas::_blockBoxPx {path b scale {autoSlot 0}} {
    set xmm [dict get $b x]
    set ymm [_previewY $path $b $autoSlot]
    set wmm [dict get $b w]
    set hmm [expr {[dict exists $b h] ? [dict get $b h] : 8.0}]
    set x0 [::tclutils::tulayout::mmToPx $xmm $scale]
    set y0 [::tclutils::tulayout::mmToPx $ymm $scale]
    set x1 [::tclutils::tulayout::mmToPx [expr {$xmm + $wmm}] $scale]
    set y1 [::tclutils::tulayout::mmToPx [expr {$ymm + $hmm}] $scale]
    return [list $x0 $y0 $x1 $y1]
}

proc ::tkutils::tkulayoutcanvas::_positionBlock {path id} {
    variable state
    set c [getCanvas $path]
    set b [dict get $state($path,blocks) $id]
    set s $state($path,-scale)
    set slot [_autoSlotFor $path $id]
    lassign [_blockBoxPx $path $b $s $slot] x0 y0 x1 y1
    foreach item [$c find withtag block_$id] {
        switch [$c type $item] {
            rectangle { $c coords $item $x0 $y0 $x1 $y1 }
            text      { $c coords $item [expr {$x0 + 3}] [expr {$y0 + 2}] }
        }
    }
}

proc ::tkutils::tkulayoutcanvas::_drawBlock {path c id b scale autoSlot} {
    variable state
    set auto [::tclutils::tulayout::isAutoY $b]
    lassign [_blockBoxPx $path $b $scale $autoSlot] x0 y0 x1 y1

    set sel [expr {$id eq $state($path,sel)}]
    if {$auto} {
        set col [expr {$sel ? "#c62828" : "#6a6a6a"}]
        set dash {6 3}
    } else {
        set col [expr {$sel ? "#d62828" : "#3060c0"}]
        set dash {3 2}
    }
    set tag block_$id
    set fill [expr {$auto ? "#f3f3f3" : "#e3f2fd"}]
    $c create rectangle $x0 $y0 $x1 $y1 -fill $fill -outline $col \
        -width [expr {$sel ? 2 : 1}] -dash $dash -tags [list block $tag]
    set lbl [_blockLabel $path $id $b]
    if {$auto} { append lbl " (auto Y)" }
    $c create text [expr {$x0 + 3}] [expr {$y0 + 2}] -anchor nw -fill $col \
        -font {TkDefaultFont 8} -text $lbl -tags [list block $tag label_$id]
}

proc ::tkutils::tkulayoutcanvas::_bindCanvas {path} {
    variable state
    if {[info exists state($path,bound)]} return
    set state($path,bound) 1
    set c [getCanvas $path]
    bind $c <ButtonPress-1>   +[list ::tkutils::tkulayoutcanvas::_canvasPress $path %x %y]
    bind $c <B1-Motion>       +[list ::tkutils::tkulayoutcanvas::_canvasMotion $path %x %y]
    bind $c <ButtonRelease-1> +[list ::tkutils::tkulayoutcanvas::_canvasRelease $path]
}

proc ::tkutils::tkulayoutcanvas::_blockAt {path x y} {
    set c [getCanvas $path]
    set cx [$c canvasx $x]
    set cy [$c canvasy $y]
    foreach item [lreverse [$c find overlapping $cx $cy $cx $cy]] {
        foreach t [$c gettags $item] {
            if {[string match block_* $t]} {
                return [string range $t 6 end]
            }
        }
    }
    return ""
}

proc ::tkutils::tkulayoutcanvas::_canvasPress {path x y} {
    set id [_blockAt $path $x $y]
    if {$id ne ""} { _dragStart $path $id $x $y }
}

proc ::tkutils::tkulayoutcanvas::_canvasMotion {path x y} {
    _dragMove $path $x $y
}

proc ::tkutils::tkulayoutcanvas::_canvasRelease {path} {
    _dragEnd $path
}

proc ::tkutils::tkulayoutcanvas::_dragStart {path id x y} {
    variable state
    set c [getCanvas $path]
    set b [dict get $state($path,blocks) $id]
    set state($path,drag) $id
    set state($path,dragX0) [$c canvasx $x]
    set state($path,dragY0) [$c canvasy $y]
    set state($path,dragOrigX) [dict get $b x]
    if {[::tclutils::tulayout::isAutoY $b]} {
        set state($path,dragOrigY) 0
    } else {
        set state($path,dragOrigY) [dict get $b y]
    }
    set state($path,sel) $id
    _syncList $path
    _paintBlocks $path
    catch {$c raise block_$id}
}

proc ::tkutils::tkulayoutcanvas::_dragMove {path x y} {
    variable state
    set id $state($path,drag)
    if {$id eq ""} return
    set c [getCanvas $path]
    set cx [$c canvasx $x]
    set cy [$c canvasy $y]
    set s $state($path,-scale)
    set dx [::tclutils::tulayout::pxToMm [expr {$cx - $state($path,dragX0)}] $s]
    set dy [::tclutils::tulayout::pxToMm [expr {$cy - $state($path,dragY0)}] $s]

    set b [dict get $state($path,blocks) $id]
    set nx [expr {$state($path,dragOrigX) + $dx}]
    set ny [expr {$state($path,dragOrigY) + $dy}]
    if {$nx < 0} { set nx 0 }
    if {$ny < 0} { set ny 0 }
    dict set b x $nx
    if {![::tclutils::tulayout::isAutoY $b]} {
        dict set b y $ny
    }
    dict set state($path,blocks) $id $b
    _positionBlock $path $id
}

proc ::tkutils::tkulayoutcanvas::_dragEnd {path} {
    variable state
    set id $state($path,drag)
    if {$id eq ""} return
    set state($path,drag) ""

    set b [dict get $state($path,blocks) $id]
    set nx [::tclutils::tulayout::snap [dict get $b x] -grid $state($path,-gridmm)]
    if {$nx < 0} { set nx 0 }
    dict set b x $nx
    if {![::tclutils::tulayout::isAutoY $b]} {
        set ny [::tclutils::tulayout::snap [dict get $b y] -grid $state($path,-gridmm)]
        if {$ny < 0} { set ny 0 }
        dict set b y $ny
    }
    dict set state($path,blocks) $id $b
    set state($path,-blocks) $state($path,blocks)
    _positionBlock $path $id
    _syncProps $path
    _fireOnChange $path
}

proc ::tkutils::tkulayoutcanvas::_fireOnChange {path} {
    variable state
    if {$state($path,-onchange) ne ""} {
        uplevel #0 [list {*}$state($path,-onchange) $path $state($path,blocks)]
    }
}

proc ::tkutils::tkulayoutcanvas::_fillList {path order} {
    variable state
    if {!$state($path,-properties)} return
    set lb $path.pw.props.list
    set sel $state($path,sel)
    $lb delete 0 end
    set idx 0
    set selIdx -1
    foreach id $order {
        if {![dict exists $state($path,blocks) $id]} continue
        set b [dict get $state($path,blocks) $id]
        set vis [expr {![dict exists $b show] || [dict get $b show]}]
        set mark [expr {$vis ? "" : "(hidden) "}]
        $lb insert end "$mark[_blockLabel $path $id $b]"
        if {$id eq $sel} { set selIdx $idx }
        incr idx
    }
    if {$selIdx >= 0} {
        $lb selection clear 0 end
        $lb selection set $selIdx
        $lb see $selIdx
    }
}

proc ::tkutils::tkulayoutcanvas::_syncList {path} {
    variable state
    if {!$state($path,-properties)} return
    set order [::tclutils::tulayout::blockOrder $state($path,blocks) \
        $state($path,-definitions)]
    if {[llength $state($path,-blockorder)]} { set order $state($path,-blockorder) }
    set id $state($path,sel)
    set idx 0
    foreach bid $order {
        if {![dict exists $state($path,blocks) $bid]} continue
        if {$bid eq $id} {
            $path.pw.props.list selection clear 0 end
            $path.pw.props.list selection set $idx
            $path.pw.props.list see $idx
            return
        }
        incr idx
    }
}

proc ::tkutils::tkulayoutcanvas::_syncProps {path} {
    variable state
    if {!$state($path,-properties)} return
    set id $state($path,sel)
    set form $path.pw.props.form
    if {$id eq "" || ![dict exists $state($path,blocks) $id]} {
        foreach key {x y w h} { $form.s$key configure -state disabled }
        $form.show configure -state disabled
        return
    }
    set b [dict get $state($path,blocks) $id]
    set state($path,syncing) 1
    foreach key {x y w h} {
        $form.s$key configure -state normal
        $form.s$key delete 0 end
        $form.s$key insert 0 [dict get $b $key]
    }
    if {[::tclutils::tulayout::isAutoY $b]} {
        $form.sy configure -state disabled
    }
    $form.show configure -state normal
    set key [string map {. _} $path]
    set state(show_$key) [expr {[dict exists $b show] ? [dict get $b show] : 1}]
    $form.show configure -variable [namespace current]::state(show_$key)
    set state($path,syncing) 0
}

proc ::tkutils::tkulayoutcanvas::_onListSelect {path} {
    variable state
    set idx [lindex [$path.pw.props.list curselection] 0]
    if {$idx eq ""} return
    set order [::tclutils::tulayout::blockOrder $state($path,blocks) \
        $state($path,-definitions)]
    if {[llength $state($path,-blockorder)]} { set order $state($path,-blockorder) }
    set n -1
    foreach id $order {
        if {![dict exists $state($path,blocks) $id]} continue
        incr n
        if {$n == $idx} {
            select $path $id
            return
        }
    }
}

proc ::tkutils::tkulayoutcanvas::_onSpin {path key} {
    variable state
    if {$state($path,syncing)} return
    set id $state($path,sel)
    if {$id eq ""} return
    set v [$path.pw.props.form.s$key get]
    if {![string is double -strict $v]} return
    set v [::tclutils::tulayout::snap $v -grid $state($path,-gridmm)]
    if {$v < 0} { set v 0 }
    if {$key eq "w" && $v == 0} { set v 1 }
    dict set state($path,blocks) $id $key $v
    set state($path,-blocks) $state($path,blocks)
    redraw $path
    _fireOnChange $path
}

proc ::tkutils::tkulayoutcanvas::_onShow {path} {
    variable state
    if {$state($path,syncing)} return
    set id $state($path,sel)
    if {$id eq ""} return
    set key [string map {. _} $path]
    dict set state($path,blocks) $id show $state(show_$key)
    set state($path,-blocks) $state($path,blocks)
    redraw $path
    _fireOnChange $path
}

package provide tkutils::tkulayoutcanvas 0.1
