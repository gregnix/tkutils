# tkutils::tkudialog -- dialogs with copyable message text
#
# Unlike tk_messageBox, the message is shown in a selectable text area and can be
# copied (Ctrl-C or the Copy button). A generic, extensible builder (show/build)
# plus ready-made variants (info/warning/error/confirm/input). Pure Tk; no
# tclutils engine required. Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkudialog {
    namespace export build show showInfo showWarning showError confirm input \
        getText getDetail result copyText choose form
    variable state
    variable counter 0
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
    array set o {
        -title "" -message "" -icon "" -detail "" -buttons OK
        -entry 0 -initial "" -parent ""
    }
    array set o $args

    toplevel $win
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

proc ::tkutils::tkudialog::_center {win} {
    update idletasks
    set w [winfo reqwidth $win]
    set h [winfo reqheight $win]
    set x [expr {([winfo screenwidth $win] - $w) / 2}]
    set y [expr {([winfo screenheight $win] - $h) / 2}]
    wm geometry $win +$x+$y
}

# Generic modal dialog. Builds at $win, grabs, waits, returns the clicked label.
proc ::tkutils::tkudialog::show {win args} {
    variable state
    build $win {*}$args
    _center $win
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
    set win [_newName]
    array set o {-title Input -message "" -initial ""}
    array set o $args
    build $win -title $o(-title) -message $o(-message) -entry 1 \
        -initial $o(-initial) -buttons {OK Cancel}
    _center $win
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
    set win [_newName]
    array set o {-title Form -parent ""}
    array set o $args

    toplevel $win
    wm title $win $o(-title)
    if {$o(-parent) ne "" && [winfo exists $o(-parent)]} {
        wm transient $win $o(-parent)
    }
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

    _center $win
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

package provide tkutils::tkudialog 0.1
