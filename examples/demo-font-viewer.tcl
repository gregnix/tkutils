#!/usr/bin/env wish
# ===========================================================================
# Demo / tool: font viewer -- browse the available font families, preview text
# in any of them at a chosen size / weight / slant, and read the font metrics
# (ascent / descent / linespace). A reference helper for Tk programmers.
# Belongs to tkutils.
#
#   wish demo-font-viewer.tcl
#   tclsh demo-font-viewer.tcl --selftest
#   tclsh demo-font-viewer.tcl --shot out.png
# ===========================================================================

package require Tk

wm title . "Font viewer"

# sample text: ASCII pangram + accented chars built from code points
# (never literal non-ASCII in the source, to stay encoding-safe)
set ::extra [join [lmap c {196 214 220 228 246 252 223 8364} {format %c $c}] ""]
set ::sample "The quick brown fox 0123456789 $::extra"
set ::size 18
set ::bold 0
set ::italic 0
set ::underline 0

font create previewFont

# ---- left: family list with filter ----
frame .left
label .left.l -text "Families ([llength [font families]]):"
entry .left.f -textvariable ::filter
listbox .left.lb -width 28 -height 22 -yscrollcommand {.left.sb set} \
    -exportselection 0
scrollbar .left.sb -command {.left.lb yview}
grid .left.l  -row 0 -column 0 -columnspan 2 -sticky w
grid .left.f  -row 1 -column 0 -columnspan 2 -sticky ew
grid .left.lb -row 2 -column 0 -sticky nsew
grid .left.sb -row 2 -column 1 -sticky ns
grid rowconfigure .left 2 -weight 1
grid columnconfigure .left 0 -weight 1
pack .left -side left -fill y -padx 4 -pady 4

# ---- right: controls + preview + metrics ----
frame .right
frame .right.ctl
label .right.ctl.sl -text "Size:"
spinbox .right.ctl.sp -from 6 -to 96 -width 4 -textvariable ::size \
    -command applyFont
checkbutton .right.ctl.b -text "Bold"      -variable ::bold      -command applyFont
checkbutton .right.ctl.i -text "Italic"    -variable ::italic    -command applyFont
checkbutton .right.ctl.u -text "Underline" -variable ::underline -command applyFont
pack .right.ctl.sl .right.ctl.sp .right.ctl.b .right.ctl.i .right.ctl.u \
    -side left -padx 3
pack .right.ctl -fill x -pady 4

label .right.fam -textvariable ::famLabel -anchor w -fg #336
pack .right.fam -fill x -padx 4

entry .right.txt -textvariable ::sample
pack .right.txt -fill x -padx 4 -pady 4
bind .right.txt <KeyRelease> {.right.prev configure -text $::sample}

label .right.prev -textvariable ::sample -font previewFont -anchor w \
    -justify left -wraplength 460 -height 4 -relief sunken -bg white
pack .right.prev -fill both -expand 1 -padx 4 -pady 4

label .right.met -textvariable ::metrics -anchor w -fg #555
label .right.spec -textvariable ::spec -anchor w -fg #555
pack .right.met .right.spec -fill x -padx 4
pack .right -side left -fill both -expand 1

# ---- logic ----
proc currentFamily {} {
    set sel [.left.lb curselection]
    if {[llength $sel] == 0} { return "" }
    return [.left.lb get [lindex $sel 0]]
}

proc applyFont {} {
    set fam [currentFamily]
    if {$fam eq ""} return
    set weight [expr {$::bold ? "bold" : "normal"}]
    set slant  [expr {$::italic ? "italic" : "roman"}]
    font configure previewFont -family $fam -size $::size \
        -weight $weight -slant $slant -underline $::underline
    set ::famLabel "$fam  ${::size}pt $weight $slant"
    array set m [font metrics previewFont]
    set ::metrics "metrics: ascent $m(-ascent)  descent $m(-descent)  linespace $m(-linespace)  fixed $m(-fixed)"
    set ::spec "spec: \[font create f -family {$fam} -size $::size -weight $weight -slant $slant\]"
}
bind .left.lb <<ListboxSelect>> applyFont

proc fillFamilies {} {
    .left.lb delete 0 end
    foreach fam [lsort -dictionary [font families]] {
        if {$::filter eq "" || [string match -nocase *$::filter* $fam]} {
            .left.lb insert end $fam
        }
    }
    if {[.left.lb size] > 0} { .left.lb selection set 0; applyFont }
}
trace add variable ::filter write {apply {{a b c} {fillFamilies}}}
fillFamilies

set mode [lindex $argv 0]
if {$mode eq "--selftest"} {
    puts "families: [llength [font families]]"
    puts "first:    [.left.lb get 0]"
    applyFont
    puts $::metrics
    exit 0
} elseif {$mode eq "--shot"} {
    # pick a known family if present for a stable shot
    foreach want {DejaVuSans Helvetica TkDefaultFont} {
        set idx [lsearch -exact [.left.lb get 0 end] $want]
        if {$idx >= 0} { .left.lb selection clear 0 end; .left.lb selection set $idx; .left.lb see $idx; applyFont; break }
    }
    set ::size 22; applyFont
    wm geometry . 800x520
    update idletasks; update; after 400; update
    catch {exec import -window root [lindex $argv 1]}
    exit 0
}
