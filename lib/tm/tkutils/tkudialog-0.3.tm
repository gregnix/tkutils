# tkutils::tkudialog -- dialogs with copyable message text
# Description: dialogs with copyable message text
# Category: Tk · widgets
#
# Unlike tk_messageBox, the message is shown in a selectable text area and can be
# copied (Ctrl-C or the Copy button). A generic, extensible builder (show/build)
# plus ready-made variants (info/warning/error/confirm/input). Pure Tk; no
# tclutils engine required. Tcl/Tk 8.6+ and 9.x compatible.
#
# 0.3 -- keyboard, structured buttons, msgcat, focus/grab (2026-10-02):
#   * Return activates -default (first button if unset); Escape activates -cancel
#     (No/Cancel if present). Default button uses ttk -default active.
#   * -buttons accepts {Label} or {id Label}; result is always the id (plain
#     Label => id equals Label, so 0.2 callers keep working).
#   * Standard titles/labels go through msgcat when available.
#   * Modal show restores previous focus and grab.
#   * -detailcollapsed 1 starts with Details folded; -maxheight caps text height.
#   * _msgHeight estimates wrapped lines from length and -width.
#
# 0.2 -- placement and options, measured 2026-09-19 (see older file).

package require Tcl 8.6-
package require Tk 8.6-
catch {package require msgcat}

namespace eval ::tkutils {}
namespace eval ::tkutils::tkudialog {
    namespace export build show showInfo showWarning showError confirm input \
        getText getDetail result copyText choose form
    variable state
    variable counter 0
    variable buildOpts {-title "" -message "" -icon "" -detail "" -buttons OK
                        -entry 0 -initial "" -parent "" -default "" -cancel ""
                        -detailcollapsed 0 -width 48 -maxheight 20}
    variable inputOpts {-title "" -message "" -initial "" -parent ""}
    variable formOpts  {-title "" -parent ""}
}

proc ::tkutils::tkudialog::_ {s} {
    if {[llength [info commands ::msgcat::mc]]} {
        return [::msgcat::mc $s]
    }
    return $s
}

proc ::tkutils::tkudialog::_opts {defaults args} {
    if {[llength $args] % 2} {
        return -code error -errorcode {TKUTILS TKUDIALOG OPTION} \
            "missing value for option \"[lindex $args end]\""
    }
    set o $defaults
    foreach {k v} $args {
        if {![dict exists $defaults $k]} {
            return -code error -errorcode [list TKUTILS TKUDIALOG OPTION $k] \
                "unknown option \"$k\"\nKnown: [join [dict keys $defaults] { }]"
        }
        dict set o $k $v
    }
    return $o
}

proc ::tkutils::tkudialog::_parent {p} {
    if {$p ne ""} {
        if {![winfo exists $p]} {
            return -code error -errorcode [list TKUTILS TKUDIALOG PARENT $p] \
                "bad window path name \"$p\" given as -parent"
        }
        return [winfo toplevel $p]
    }
    set f [focus]
    if {$f ne "" && [winfo exists $f]} { return [winfo toplevel $f] }
    if {[winfo exists .]} { return . }
    return ""
}

proc ::tkutils::tkudialog::_transient {win parent} {
    if {$parent ne "" && $parent ne $win && [winfo viewable $parent]} {
        wm transient $win $parent
    }
}

proc ::tkutils::tkudialog::_cleanup {win w} {
    variable state
    if {$w eq $win} { array unset state $win,* }
}

proc ::tkutils::tkudialog::_newName {} {
    variable counter
    return ".tkudialog[incr counter]"
}

proc ::tkutils::tkudialog::_iconImage {icon} {
    switch -- $icon {
        info     { return ::tk::icons::information }
        warning  { return ::tk::icons::warning }
        error    { return ::tk::icons::error }
        question { return ::tk::icons::question }
        default  { return "" }
    }
}

# Estimate visible lines for a wrapping text widget of -width columns.
proc ::tkutils::tkudialog::_msgHeight {text {width 48} {max 20}} {
    if {$width < 8} { set width 8 }
    if {$max < 1} { set max 1 }
    set lines 0
    foreach para [split $text \n] {
        set len [string length $para]
        if {$len == 0} {
            incr lines
            continue
        }
        incr lines [expr {($len + $width - 1) / $width}]
    }
    if {$lines < 1} { set lines 1 }
    if {$lines > $max} { set lines $max }
    return $lines
}

# Normalize -buttons: each item is Label or {id Label} -> list of {id label}.
proc ::tkutils::tkudialog::_parseButtons {buttons} {
    set out {}
    foreach b $buttons {
        if {[llength $b] >= 2} {
            lappend out [list [lindex $b 0] [lindex $b 1]]
        } else {
            lappend out [list $b $b]
        }
    }
    if {![llength $out]} { set out [list [list OK OK]] }
    return $out
}

proc ::tkutils::tkudialog::choose {win id} {
    variable state
    if {[info exists state($win,result)]} { set state($win,result) $id }
    return
}

proc ::tkutils::tkudialog::_toggleDetail {win} {
    variable state
    if {![winfo exists $win.detail]} return
    if {[winfo manager $win.detail] ne ""} {
        pack forget $win.detail
        if {[winfo exists $win.detailtoggle]} {
            $win.detailtoggle configure -text "[_ {Details}] >>"
        }
    } else {
        pack $win.detail -fill both -expand 1 -padx 12 -pady {0 6} \
            -after $win.top
        if {[winfo exists $win.detailtoggle]} {
            $win.detailtoggle configure -text "[_ {Details}] <<"
        }
    }
}

# Build a (non-modal) dialog toplevel at $win.
proc ::tkutils::tkudialog::build {win args} {
    variable state
    variable buildOpts
    array set o [_opts $buildOpts {*}$args]
    set parent [_parent $o(-parent)]
    set btns [_parseButtons $o(-buttons)]
    set defaultId $o(-default)
    if {$defaultId eq ""} { set defaultId [lindex $btns 0 0] }
    set cancelId $o(-cancel)
    if {$cancelId eq ""} {
        foreach pair $btns {
            lassign $pair id lab
            if {$id in {No Cancel no cancel} || $lab in {No Cancel}} {
                set cancelId $id
                break
            }
        }
    }

    toplevel $win
    _transient $win $parent
    set state($win,parent) $parent
    set title $o(-title)
    if {$title ne ""} { wm title $win $title }
    set state($win,result) ""
    set state($win,message) $o(-message)
    set state($win,detail) $o(-detail)
    set state($win,defaultId) $defaultId
    set state($win,cancelId) $cancelId
    bind $win <Destroy> [list ::tkutils::tkudialog::_cleanup $win %W]
    wm protocol $win WM_DELETE_WINDOW \
        [list ::tkutils::tkudialog::choose $win $cancelId]

    ttk::frame $win.top -padding 12
    set col 0
    set img [_iconImage $o(-icon)]
    if {$img ne ""} {
        ttk::label $win.top.icon -image $img
        grid $win.top.icon -row 0 -column 0 -sticky n -padx {0 12}
        set col 1
    }
    set wcols $o(-width)
    set maxh $o(-maxheight)
    text $win.top.msg -wrap word -width $wcols \
        -height [_msgHeight $o(-message) $wcols $maxh] \
        -relief flat -highlightthickness 0 -padx 4 -pady 4
    $win.top.msg insert end $o(-message)
    $win.top.msg configure -state disabled
    grid $win.top.msg -row 0 -column $col -sticky nsew
    grid columnconfigure $win.top $col -weight 1
    grid rowconfigure $win.top 0 -weight 1
    pack $win.top -fill both -expand 1

    if {$o(-entry)} {
        ttk::entry $win.e
        $win.e insert 0 $o(-initial)
        pack $win.e -fill x -padx 12 -pady {0 6}
        bind $win.e <Return> [list ::tkutils::tkudialog::choose $win $defaultId]
        set state($win,entryFocus) 1
    }

    if {$o(-detail) ne ""} {
        if {$o(-detailcollapsed)} {
            ttk::button $win.detailtoggle -text "[_ {Details}] >>" \
                -command [list ::tkutils::tkudialog::_toggleDetail $win]
            pack $win.detailtoggle -anchor w -padx 12 -pady {0 4}
        }
        set lf [ttk::labelframe $win.detail -text [_ Details] -padding 6]
        text $lf.txt -wrap word -width $wcols \
            -height [_msgHeight $o(-detail) $wcols $maxh] \
            -relief flat -highlightthickness 0 \
            -yscrollcommand [list $lf.ys set]
        ttk::scrollbar $lf.ys -orient vertical -command [list $lf.txt yview]
        $lf.txt insert end $o(-detail)
        $lf.txt configure -state disabled
        grid $lf.txt $lf.ys -sticky nsew
        grid rowconfigure $lf 0 -weight 1
        grid columnconfigure $lf 0 -weight 1
        if {!$o(-detailcollapsed)} {
            pack $lf -fill both -expand 1 -padx 12 -pady {0 6}
        }
    }

    ttk::frame $win.btns -padding {12 0 12 12}
    ttk::button $win.btns.copy -text [_ Copy] \
        -command [list ::tkutils::tkudialog::copyText $win]
    pack $win.btns.copy -side left
    set i 0
    set defaultBtn ""
    foreach pair $btns {
        lassign $pair id lab
        ttk::button $win.btns.b$i -text $lab \
            -command [list ::tkutils::tkudialog::choose $win $id]
        if {$id eq $defaultId} {
            catch {$win.btns.b$i configure -default active}
            set defaultBtn $win.btns.b$i
        } else {
            catch {$win.btns.b$i configure -default normal}
        }
        pack $win.btns.b$i -side right -padx 4
        incr i
    }
    set state($win,defaultBtn) $defaultBtn
    pack $win.btns -fill x -side bottom

    bind $win <Return> [list ::tkutils::tkudialog::choose $win $defaultId]
    bind $win <KP_Enter> [list ::tkutils::tkudialog::choose $win $defaultId]
    if {$cancelId ne ""} {
        bind $win <Escape> [list ::tkutils::tkudialog::choose $win $cancelId]
    } else {
        bind $win <Escape> [list ::tkutils::tkudialog::choose $win ""]
    }
    # Key events with focus on children still reach the dialog via bindtags
    # on the button frame / entry; also bind children that usually steal keys.
    foreach child [list $win.btns $win.top] {
        if {![winfo exists $child]} continue
        bind $child <Return> [list ::tkutils::tkudialog::choose $win $defaultId]
        bind $child <KP_Enter> [list ::tkutils::tkudialog::choose $win $defaultId]
        if {$cancelId ne ""} {
            bind $child <Escape> [list ::tkutils::tkudialog::choose $win $cancelId]
        }
    }
    if {[winfo exists $win.btns]} {
        foreach b [winfo children $win.btns] {
            bind $b <Return> [list ::tkutils::tkudialog::choose $win $defaultId]
            bind $b <KP_Enter> [list ::tkutils::tkudialog::choose $win $defaultId]
            if {$cancelId ne ""} {
                bind $b <Escape> [list ::tkutils::tkudialog::choose $win $cancelId]
            }
        }
    }
    return $win
}

proc ::tkutils::tkudialog::getText {win} {
    variable state
    return $state($win,message)
}
proc ::tkutils::tkudialog::getDetail {win} {
    variable state
    return $state($win,detail)
}
proc ::tkutils::tkudialog::result {win} {
    variable state
    if {[info exists state($win,result)]} { return $state($win,result) }
    return ""
}

proc ::tkutils::tkudialog::copyText {win} {
    variable state
    set txt $state($win,message)
    if {$state($win,detail) ne ""} { append txt "\n\n" $state($win,detail) }
    clipboard clear -displayof $win
    clipboard append -displayof $win $txt
    return $txt
}

proc ::tkutils::tkudialog::_geometry {w h sw sh px py pw ph viewable} {
    if {!$viewable} {
        set x [expr {($sw - $w) / 2}]
        set y [expr {($sh - $h) / 2}]
        set clamp 1
    } else {
        set x [expr {$px + ($pw - $w) / 2}]
        set y [expr {$py + ($ph - $h) / 2}]
        set clamp [expr {$px >= 0 && $py >= 0 && $px + $pw <= $sw && $py + $ph <= $sh}]
    }
    if {$clamp} {
        if {$x + $w > $sw} { set x [expr {$sw - $w}] }
        if {$y + $h > $sh} { set y [expr {$sh - $h}] }
        if {$x < 0} { set x 0 }
        if {$y < 0} { set y 0 }
    }
    return [list $x $y]
}

proc ::tkutils::tkudialog::_place {win {parent ""}} {
    variable state
    update idletasks
    set w [winfo reqwidth $win]
    set h [winfo reqheight $win]
    set viewable [expr {$parent ne "" && [winfo exists $parent] && [winfo viewable $parent]}]
    set px 0; set py 0; set pw 0; set ph 0
    if {$viewable} {
        set px [winfo rootx $parent]; set py [winfo rooty $parent]
        set pw [winfo width $parent]; set ph [winfo height $parent]
    }
    lassign [_geometry $w $h [winfo screenwidth $win] [winfo screenheight $win] \
        $px $py $pw $ph $viewable] x y
    wm geometry $win +$x+$y
    set state($win,target) [list $x $y]
    if {[winfo ismapped $win]} {
        after 100 [list ::tkutils::tkudialog::_correct $win]
    } else {
        bind $win <Map> [list ::tkutils::tkudialog::_mapped $win %W]
    }
    return [list $x $y]
}

proc ::tkutils::tkudialog::_mapped {win w} {
    if {$w ne $win} return
    bind $win <Map> {}
    after 100 [list ::tkutils::tkudialog::_correct $win]
}

proc ::tkutils::tkudialog::_correct {win} {
    variable state
    if {![winfo exists $win] || ![info exists state($win,target)]} return
    lassign $state($win,target) x y
    set dx [expr {[winfo rootx $win] - $x}]
    set dy [expr {[winfo rooty $win] - $y}]
    if {($dx == 0 && $dy == 0) || abs($dx) >= 100 || abs($dy) >= 100} return
    wm geometry $win +[expr {$x - $dx}]+[expr {$y - $dy}]
}

# Modal run: place, grab, focus default (or entry), wait, restore focus/grab.
proc ::tkutils::tkudialog::_runModal {win} {
    variable state
    set prevFocus [focus]
    set prevGrab ""
    catch {set prevGrab [grab current $win]}
    _place $win $state($win,parent)
    catch {grab set $win}
    if {[info exists state($win,entryFocus)] && [winfo exists $win.e]} {
        focus $win.e
    } elseif {[info exists state($win,defaultBtn)] \
            && $state($win,defaultBtn) ne "" \
            && [winfo exists $state($win,defaultBtn)]} {
        focus $state($win,defaultBtn)
    } else {
        focus $win
    }
    vwait ::tkutils::tkudialog::state($win,result)
    set r ""
    if {[info exists state($win,result)]} { set r $state($win,result) }
    catch {grab release $win}
    if {$prevGrab ne "" && [winfo exists $prevGrab]} {
        catch {grab set $prevGrab}
    }
    if {$prevFocus ne "" && [winfo exists $prevFocus]} {
        catch {focus $prevFocus}
    }
    catch {destroy $win}
    return $r
}

proc ::tkutils::tkudialog::show {win args} {
    build $win {*}$args
    return [_runModal $win]
}

proc ::tkutils::tkudialog::showInfo {message args} {
    return [show [_newName] -icon info -title [_ Information] \
        -message $message -buttons [list [list ok [_ OK]]] -default ok {*}$args]
}
proc ::tkutils::tkudialog::showWarning {message args} {
    return [show [_newName] -icon warning -title [_ Warning] \
        -message $message -buttons [list [list ok [_ OK]]] -default ok {*}$args]
}
proc ::tkutils::tkudialog::showError {message args} {
    set collapsed 0
    # Long details default to collapsed when -detail is passed without override.
    foreach {k v} $args {
        if {$k eq "-detail" && $v ne ""} { set collapsed 1 }
        if {$k eq "-detailcollapsed"} { set collapsed $v }
    }
    return [show [_newName] -icon error -title [_ Error] \
        -message $message -buttons [list [list ok [_ OK]]] -default ok \
        -detailcollapsed $collapsed {*}$args]
}

# Yes/No confirmation. Returns 1 for yes, 0 otherwise (id-based).
proc ::tkutils::tkudialog::confirm {message args} {
    set r [show [_newName] -icon question -title [_ Confirm] \
        -message $message \
        -buttons [list [list yes [_ Yes]] [list no [_ No]]] \
        -default yes -cancel no {*}$args]
    return [expr {$r eq "yes" || $r eq "Yes"}]
}

proc ::tkutils::tkudialog::input {args} {
    variable state
    variable inputOpts
    set defaults $inputOpts
    dict set defaults -title [_ Input]
    array set o [_opts $defaults {*}$args]
    set win [_newName]
    build $win -title $o(-title) -message $o(-message) -entry 1 \
        -initial $o(-initial) \
        -buttons [list [list ok [_ OK]] [list cancel [_ Cancel]]] \
        -default ok -cancel cancel -parent $o(-parent)
    set prevFocus [focus]
    set prevGrab ""
    catch {set prevGrab [grab current $win]}
    _place $win $state($win,parent)
    catch {grab set $win}
    focus $win.e
    vwait ::tkutils::tkudialog::state($win,result)
    set ok [expr {[info exists state($win,result)] && $state($win,result) eq "ok"}]
    set txt ""
    if {[winfo exists $win.e]} { set txt [$win.e get] }
    catch {grab release $win}
    if {$prevGrab ne "" && [winfo exists $prevGrab]} {
        catch {grab set $prevGrab}
    }
    if {$prevFocus ne "" && [winfo exists $prevFocus]} {
        catch {focus $prevFocus}
    }
    catch {destroy $win}
    return [expr {$ok ? $txt : ""}]
}

# Modal form dialog. Embeds a tkuform built from $fieldspec with OK/Cancel.
# Returns the values dict on OK, or "" on Cancel. Options: -title, -parent.
proc ::tkutils::tkudialog::form {fieldspec args} {
    variable state
    package require tkutils::tkuform 0.1
    variable formOpts
    set defaults $formOpts
    dict set defaults -title [_ Form]
    array set o [_opts $defaults {*}$args]
    set parent [_parent $o(-parent)]
    set win [_newName]

    toplevel $win
    wm title $win $o(-title)
    _transient $win $parent
    set state($win,parent) $parent
    set state($win,result) ""
    set state($win,message) ""
    set state($win,detail) ""
    bind $win <Destroy> [list ::tkutils::tkudialog::_cleanup $win %W]

    set f [::tkutils::tkuform::widget $win.form $fieldspec]
    pack $f -side top -fill both -expand 1 -padx 4 -pady 4

    set bf [ttk::frame $win.bf -padding 6]
    ttk::button $bf.ok -text [_ OK] -default active \
        -command [list ::tkutils::tkudialog::choose $win ok]
    ttk::button $bf.cancel -text [_ Cancel] \
        -command [list ::tkutils::tkudialog::choose $win cancel]
    pack $bf.cancel $bf.ok -side right -padx 2
    pack $bf -side bottom -fill x
    bind $win <Return> [list ::tkutils::tkudialog::choose $win ok]
    bind $win <KP_Enter> [list ::tkutils::tkudialog::choose $win ok]
    bind $win <Escape> [list ::tkutils::tkudialog::choose $win cancel]
    wm protocol $win WM_DELETE_WINDOW \
        [list ::tkutils::tkudialog::choose $win cancel]

    set prevFocus [focus]
    set prevGrab ""
    catch {set prevGrab [grab current $win]}
    _place $win $parent
    catch {grab set $win}
    catch {
        set names [::tkutils::tkuform::fieldNames $f]
        if {[llength $names]} {
            focus [::tkutils::tkuform::widgetOf $f [lindex $names 0]]
        } else {
            focus $bf.ok
        }
    }
    vwait ::tkutils::tkudialog::state($win,result)
    set ok [expr {[info exists state($win,result)] && $state($win,result) eq "ok"}]
    set vals ""
    if {$ok} { set vals [::tkutils::tkuform::values $f] }
    catch {grab release $win}
    if {$prevGrab ne "" && [winfo exists $prevGrab]} {
        catch {grab set $prevGrab}
    }
    if {$prevFocus ne "" && [winfo exists $prevFocus]} {
        catch {focus $prevFocus}
    }
    catch {destroy $win}
    return $vals
}

package provide tkutils::tkudialog 0.3
