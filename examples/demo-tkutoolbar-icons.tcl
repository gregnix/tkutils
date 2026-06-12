#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
package require tkutils::tkutoolbar
package require tkutils::tkuicon
wm title . "tkutoolbar with icons"

set out [ttk::label .out -anchor w -padding 8 -text "Click a button"]

# Icons come from tkuicon (tksvg on 8.6 / native SVG on Tk 9). Without SVG
# support we fall back to text so the demo still runs everywhere.
set haveIcons [::tkutils::tkuicon::hassvg]
proc icon {name} {
    if {![::tkutils::tkuicon::hassvg]} { return "" }
    if {[catch {::tkutils::tkuicon::create $name 20 -color "#333333"} img]} { return "" }
    return $img
}

# Build one toolbar in a given button style with icon buttons + a toggle + a dropdown.
proc buildBar {parent style {orient horizontal} {suffix ""}} {
    set pp [expr {$parent eq "." ? "" : $parent}]
    set tb [::tkutils::tkutoolbar::widget $pp.tb_$style$suffix -buttonstyle $style -orient $orient]
    ::tkutils::tkutoolbar::addButton $tb new  "New"  {.out configure -text "New"}  -icon [icon new]  -tooltip "New (Ctrl+N)"
    ::tkutils::tkutoolbar::addButton $tb open "Open" {.out configure -text "Open"} -icon [icon folder] -tooltip "Open"
    ::tkutils::tkutoolbar::addButton $tb save "Save" {.out configure -text "Save"} -icon [icon save] -tooltip "Save (Ctrl+S)"
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addToggle $tb bold "Bold" ::bold($style$suffix) \
        -icon [icon bold] -command [list .out configure -text "Bold ($style $orient)"]
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addDropdown $tb fmt "Format" -icon [icon list] -menu {
        {"Heading" {.out configure -text "Heading"}}
        {"Body"    {.out configure -text "Body"}}
    }
    return $tb
}

if {!$haveIcons} {
    pack [ttk::label .note -padding {8 8 8 0} -foreground "#a00" -anchor w -text \
        "No SVG support here -- showing text buttons. Install tksvg (Tk 8.6) or run on Tk 9 for icons."] -fill x
}

pack [ttk::label .l1 -padding {8 6 8 0} -anchor w \
    -text "flat (Toolbutton) -- button edges appear only on hover:"] -fill x
pack [buildBar . flat] -fill x -padx 8

pack [ttk::label .l2 -padding {8 10 8 0} -anchor w \
    -text "raised (TButton) -- every button has a visible border:"] -fill x
pack [buildBar . raised] -fill x -padx 8

# A vertical toolbar (raised, icons) beside a content area.
pack [ttk::label .l3 -padding {8 10 8 0} -anchor w \
    -text "vertical (-orient vertical) -- stacks top-to-bottom, buttons fill width:"] -fill x
set row [ttk::frame .row -padding {8 2 8 2}]
pack $row -fill both -expand 1
pack [buildBar $row raised vertical _v] -side left -fill y
pack [ttk::label $row.area -relief groove -padding 16 -anchor center \
    -text "content area"] -side left -fill both -expand 1 -padx {8 0}

pack $out -fill x -pady {8 0}

# A control row to switch display mode on both bars at once.
set ctl [ttk::frame .ctl -padding 8]
pack $ctl -fill x
foreach m {both icon text} {
    ttk::button $ctl.m$m -text "Show: $m" -command [list apply {{m} {
        ::tkutils::tkutoolbar::setDisplayMode .tb_flat $m
        ::tkutils::tkutoolbar::setDisplayMode .tb_raised $m
        catch {::tkutils::tkutoolbar::setDisplayMode .row.tb_raised_v $m}
    }} $m]
    pack $ctl.m$m -side left -padx 4
}

vwait forever
