#!/usr/bin/env wish
# ===========================================================================
# Demo / tool: color viewer -- shows all tclutils::tucolor named colors in a
# tablelist with a color swatch per row, plus hex / RGB / HSV columns. Sortable
# (tkutlsort), searchable (tkutlfind, type in the box) and copyable
# (tkutlclip, Ctrl+C). Belongs to tkutils.
#
#   wish demo-color-viewer.tcl
#   tclsh demo-color-viewer.tcl --selftest        ;# print, no GUI
#   tclsh demo-color-viewer.tcl --shot out.png    ;# render to PNG and exit
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _root [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain \
            [file join [file dirname $_root] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c; break
    }
}

package require Tk
package require tablelist
package require tclutils::tucolor
catch {package require tkutils::tkutlsort}
catch {package require tkutils::tkutlfind}
catch {package require tkutils::tkutlclip}

wm title . "tucolor -- color viewer"

frame .top
label .top.l -text "Find:"
entry .top.e -textvariable ::q -width 22
label .top.n -textvariable ::status
pack .top.l .top.e .top.n -side left -padx 3
pack .top -fill x -pady 3

tablelist::tablelist .t \
    -columns {6 "" center  20 "Name" left  9 "Hex" left \
              5 "R" right  5 "G" right  5 "B" right \
              5 "H" right  5 "S" right  5 "V" right} \
    -stretch all -height 22 -labelcommand tablelist::sortByColumn \
    -stripebackground #f4f4f4
pack .t -fill both -expand 1

foreach name [::tclutils::tucolor::names] {
    lassign [::tclutils::tucolor::rgb $name]   r g b
    lassign [::tclutils::tucolor::toHsv $name] h s v
    set hex [::tclutils::tucolor::hex $name]
    .t insert end [list "" $name $hex $r $g $b $h $s $v]
    set row [expr {[.t size] - 1}]
    .t cellconfigure $row,0 -background $hex
}
set ::status "[.t size] colors"

catch {::tkutils::tkutlsort::columns .t \
    {1 string 2 string 3 integer 4 integer 5 integer 6 integer 7 integer 8 integer}}
catch {::tkutils::tkutlclip::installBindings .t}

if {[llength [info commands ::tkutils::tkutlfind::find]]} {
    proc doFind {} {
        set n [::tkutils::tkutlfind::find .t $::q -columns {1 2}]
        set ::status "$n match(es) for \"$::q\""
    }
    bind .top.e <KeyRelease> doFind
    bind .top.e <Return>     { ::tkutils::tkutlfind::next .t }
}

# --- headless helpers ---
set mode [lindex $argv 0]
if {$mode eq "--selftest"} {
    update idletasks
    puts "colors: [.t size]"
    puts "sample: [.t get 0]  ...  [.t get end]"
    exit 0
} elseif {$mode eq "--shot"} {
    set png [lindex $argv 1]
    wm geometry . 760x560
    update idletasks; update; after 400; update
    catch {exec import -window root $png}
    exit 0
}
