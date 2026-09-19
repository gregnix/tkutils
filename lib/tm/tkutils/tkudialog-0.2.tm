# tkutils::tkudialog -- dialogs with copyable message text
# Description: dialogs with copyable message text
# Category: Tk · widgets
#
# Unlike tk_messageBox, the message is shown in a selectable text area and can be
# copied (Ctrl-C or the Copy button). A generic, extensible builder (show/build)
# plus ready-made variants (info/warning/error/confirm/input). Pure Tk; no
# tclutils engine required. Tcl/Tk 8.6+ and 9.x compatible.
#
# 0.2 -- placement and options, measured 2026-09-19:
#   * -parent was accepted but not used: no wm transient, and every modal
#     dialog opened in the middle of the screen (parent at 900,600 -> dialog at
#     431,466). On a second monitor that is the wrong screen. Now the dialog is
#     transient to its parent and centred over it.
#   * Without -parent the parent is the toplevel that has the focus, else "."
#     -- like tk_messageBox. Callers that never passed -parent (ctrlutils
#     cufileops) get the right monitor too.
#   * Unknown options were swallowed by `array set` (-parnet built a dialog,
#     rc 0). They are now an error that lists the known options.
#
# What the placement does NOT see: Tk reports the size of ONE screen. On
# Windows that is the primary monitor, so a parent on a second monitor lies
# outside it. Clamping is therefore only done when the parent lies completely
# on the screen Tk reports; otherwise the dialog is centred over the parent
# unclamped (a dialog wider than its parent may overhang that monitor).

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkudialog {
    namespace export build show showInfo showWarning showError confirm input \
        getText getDetail result copyText choose form
    variable state
    variable counter 0
    # option sets with defaults, one per entry point
    variable buildOpts {-title "" -message "" -icon "" -detail "" -buttons OK
                        -entry 0 -initial "" -parent ""}
    variable inputOpts {-title Input -message "" -initial "" -parent ""}
    variable formOpts  {-title Form -parent ""}
}

# _opts defaults args -- validate options against DEFAULTS (a dict); returns
# the merged dict. Unknown option -> error naming the known ones.
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

# _parent p -- the toplevel a dialog belongs to, or "" if there is none worth
# using. An explicit -parent that does not exist is an error (tk_messageBox
# does the same); without -parent: the focus toplevel, else ".".
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

# _transient win parent -- only to a VIEWABLE parent: a dialog transient to a
# withdrawn toplevel stays invisible under some window managers.
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

proc ::tkutils::tkudialog::_msgHeight {text} {
    set n [llength [split $text \n]]
    if {$n < 1} { set n 1 }
    if {$n > 12} { set n 12 }
    return $n
}

# Programmatically pick a button (sets the result variable).
proc ::tkutils::tkudialog::choose {win label} {
    variable state
    if {[info exists state($win,result)]} { set state($win,result) $label }
    return
}

# Build a (non-modal) dialog toplevel at $win. Options:
#   -title t  -message m  -icon info|warning|error|question  -detail d
#   -buttons {labels...} (default OK)  -entry 0|1  -initial s  -parent w
proc ::tkutils::tkudialog::build {win args} {
    variable state
    variable buildOpts
    array set o [_opts $buildOpts {*}$args]
    set parent [_parent $o(-parent)]

    toplevel $win
    _transient $win $parent
    set state($win,parent) $parent
    if {$o(-title) ne ""} { wm title $win $o(-title) }
    set state($win,result) ""
    set state($win,message) $o(-message)
    set state($win,detail) $o(-detail)
    bind $win <Destroy> [list ::tkutils::tkudialog::_cleanup $win %W]
    wm protocol $win WM_DELETE_WINDOW [list ::tkutils::tkudialog::choose $win ""]

    ttk::frame $win.top -padding 12
    set col 0
    set img [_iconImage $o(-icon)]
    if {$img ne ""} {
        ttk::label $win.top.icon -image $img
        grid $win.top.icon -row 0 -column 0 -sticky n -padx {0 12}
        set col 1
    }
    text $win.top.msg -wrap word -width 48 -height [_msgHeight $o(-message)] \
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
        bind $win.e <Return> [list ::tkutils::tkudialog::choose $win \
            [lindex $o(-buttons) 0]]
        after idle [list focus $win.e]
    }

    if {$o(-detail) ne ""} {
        set lf [ttk::labelframe $win.detail -text "Details" -padding 6]
        text $lf.txt -wrap word -width 48 -height [_msgHeight $o(-detail)] \
            -relief flat -highlightthickness 0 \
            -yscrollcommand [list $lf.ys set]
        ttk::scrollbar $lf.ys -orient vertical -command [list $lf.txt yview]
        $lf.txt insert end $o(-detail)
        $lf.txt configure -state disabled
        grid $lf.txt $lf.ys -sticky nsew
        grid rowconfigure $lf 0 -weight 1
        grid columnconfigure $lf 0 -weight 1
        pack $lf -fill both -expand 1 -padx 12 -pady {0 6}
    }

    ttk::frame $win.btns -padding {12 0 12 12}
    ttk::button $win.btns.copy -text "Copy" \
        -command [list ::tkutils::tkudialog::copyText $win]
    pack $win.btns.copy -side left
    set i 0
    foreach b $o(-buttons) {
        ttk::button $win.btns.b$i -text $b \
            -command [list ::tkutils::tkudialog::choose $win $b]
        pack $win.btns.b$i -side right -padx 4
        incr i
    }
    pack $win.btns -fill x -side bottom
    return $win
}

# Return the message / detail text (for copying or inspection).
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

# Copy the message (and detail, if any) to the clipboard. Returns the text.
proc ::tkutils::tkudialog::copyText {win} {
    variable state
    set txt $state($win,message)
    if {$state($win,detail) ne ""} { append txt "\n\n" $state($win,detail) }
    clipboard clear -displayof $win
    clipboard append -displayof $win $txt
    return $txt
}

# _geometry w h parent sw sh px py pw ph viewable -- pure placement rule,
# returns {x y}. Centred over a viewable parent, else over the screen.
# Clamped to the screen (all four sides) only when the parent lies completely
# on it -- see the note at the top of this file.
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

# _place win ?parent? -- position a built dialog (see _geometry).
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
    # x/y is where the dialog's CONTENT should be. Most window managers put the
    # FRAME there, so the content ends up shifted by border and title bar
    # (measured: icewm +5+23, fluxbox +1+22, metacity +0+36; openbox and a
    # bare X server place the content itself). The offset cannot be known in
    # advance -- openbox treats transient dialogs differently from their
    # parents -- so it is measured once the dialog is mapped and corrected.
    set state($win,target) [list $x $y]
    # The `update idletasks` above usually maps the new toplevel already (Tk
    # maps toplevels at idle time), so a <Map> binding set now would never
    # fire -- measured. Schedule the check directly when it is mapped.
    if {[winfo ismapped $win]} {
        after 100 [list ::tkutils::tkudialog::_correct $win]
    } else {
        bind $win <Map> [list ::tkutils::tkudialog::_mapped $win %W]
    }
    return [list $x $y]
}

# _mapped win w -- first <Map> of the dialog itself: let the window manager
# finish placing it, then correct once.
proc ::tkutils::tkudialog::_mapped {win w} {
    if {$w ne $win} return
    bind $win <Map> {}
    after 100 [list ::tkutils::tkudialog::_correct $win]
}

# _correct win -- move the dialog so that its content sits at the target.
# Only offsets of decoration size (< 100 px) are corrected: a larger one means
# the window manager placed the dialog on purpose (e.g. kept it on screen),
# and fighting it would make things worse.
proc ::tkutils::tkudialog::_correct {win} {
    variable state
    if {![winfo exists $win] || ![info exists state($win,target)]} return
    lassign $state($win,target) x y
    set dx [expr {[winfo rootx $win] - $x}]
    set dy [expr {[winfo rooty $win] - $y}]
    if {($dx == 0 && $dy == 0) || abs($dx) >= 100 || abs($dy) >= 100} return
    wm geometry $win +[expr {$x - $dx}]+[expr {$y - $dy}]
}

# Generic modal dialog. Builds at $win, grabs, waits, returns the clicked label.
proc ::tkutils::tkudialog::show {win args} {
    variable state
    build $win {*}$args
    _place $win $state($win,parent)
    catch {grab set $win}
    focus $win
    vwait ::tkutils::tkudialog::state($win,result)
    set r ""
    if {[info exists state($win,result)]} { set r $state($win,result) }
    catch {grab release $win}
    catch {destroy $win}
    return $r
}

proc ::tkutils::tkudialog::showInfo {message args} {
    return [show [_newName] -icon info -title Information \
        -message $message -buttons OK {*}$args]
}
proc ::tkutils::tkudialog::showWarning {message args} {
    return [show [_newName] -icon warning -title Warning \
        -message $message -buttons OK {*}$args]
}
proc ::tkutils::tkudialog::showError {message args} {
    return [show [_newName] -icon error -title Error \
        -message $message -buttons OK {*}$args]
}

# Yes/No confirmation. Returns 1 for Yes, 0 otherwise.
proc ::tkutils::tkudialog::confirm {message args} {
    set r [show [_newName] -icon question -title Confirm \
        -message $message -buttons {Yes No} {*}$args]
    return [expr {$r eq "Yes"}]
}

# Prompt for a line of text. Returns the text, or "" if cancelled.
proc ::tkutils::tkudialog::input {args} {
    variable state
    variable inputOpts
    array set o [_opts $inputOpts {*}$args]
    set win [_newName]
    build $win -title $o(-title) -message $o(-message) -entry 1 \
        -initial $o(-initial) -buttons {OK Cancel} -parent $o(-parent)
    _place $win $state($win,parent)
    catch {grab set $win}
    focus $win
    vwait ::tkutils::tkudialog::state($win,result)
    set ok [expr {[info exists state($win,result)] && $state($win,result) eq "OK"}]
    set txt ""
    if {[winfo exists $win.e]} { set txt [$win.e get] }
    catch {grab release $win}
    catch {destroy $win}
    return [expr {$ok ? $txt : ""}]
}

# Modal form dialog. Embeds a tkuform built from $fieldspec with OK/Cancel.
# Returns the values dict on OK, or "" on Cancel. Options: -title, -parent.
proc ::tkutils::tkudialog::form {fieldspec args} {
    variable state
    package require tkutils::tkuform 0.1
    variable formOpts
    array set o [_opts $formOpts {*}$args]
    set parent [_parent $o(-parent)]
    set win [_newName]

    toplevel $win
    wm title $win $o(-title)
    _transient $win $parent
    set state($win,result) ""

    set f [::tkutils::tkuform::widget $win.form $fieldspec]
    pack $f -side top -fill both -expand 1 -padx 4 -pady 4

    set bf [ttk::frame $win.bf -padding 6]
    ttk::button $bf.ok     -text "OK" \
        -command [list ::tkutils::tkudialog::choose $win OK]
    ttk::button $bf.cancel -text "Cancel" \
        -command [list ::tkutils::tkudialog::choose $win Cancel]
    pack $bf.cancel $bf.ok -side right -padx 2
    pack $bf -side bottom -fill x
    bind $win <Escape> [list ::tkutils::tkudialog::choose $win Cancel]

    _place $win $parent
    catch {grab set $win}
    # focus the first field if there is one
    catch {
        set names [::tkutils::tkuform::fieldNames $f]
        if {[llength $names]} {
            focus [::tkutils::tkuform::widgetOf $f [lindex $names 0]]
        } else {
            focus $win
        }
    }
    vwait ::tkutils::tkudialog::state($win,result)
    set ok [expr {[info exists state($win,result)] && $state($win,result) eq "OK"}]
    set vals ""
    if {$ok} { set vals [::tkutils::tkuform::values $f] }
    catch {grab release $win}
    catch {destroy $win}
    return $vals
}

package provide tkutils::tkudialog 0.2
