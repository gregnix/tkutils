#!/usr/bin/env wish
# ===========================================================================
# Demo / tool: Tk unit converter -- converts between Tk screen distances
# (pixels, points "p", millimetres "m", centimetres "c", inches "i") for the
# current display, using winfo fpixels. Handy when picking -padx/-pady/-width
# values. Includes a live converter and a reference table. Belongs to tkutils.
#
#   wish demo-tkunits.tcl
#   tclsh demo-tkunits.tcl --selftest
#   tclsh demo-tkunits.tcl --shot out.png
# ===========================================================================

package require Tk
package require tablelist

wm title . "Tk unit converter"

# Tk distance suffix per unit name
set ::suffix {px "" pt p mm m cm c inch i}

# value+unit -> pixels (float) via Tk's own parser
proc toPixels {val unit} {
    set sfx [dict get $::suffix $unit]
    return [winfo fpixels . "$val$sfx"]
}

# pixels -> dict of all units
proc fromPixels {px} {
    set ppi [winfo fpixels . 1i]
    set ppm [winfo fpixels . 1m]
    return [dict create \
        px   $px \
        pt   [expr {$px / ($ppi/72.0)}] \
        mm   [expr {$px / $ppm}] \
        cm   [expr {$px / ($ppm*10.0)}] \
        inch [expr {$px / $ppi}]]
}

set ::ppi [format %.1f [winfo fpixels . 1i]]

frame .top
label .top.dpi -text "Display: $::ppi px/inch   (winfo fpixels . 1i)" -fg #336
pack .top.dpi -anchor w
pack .top -fill x -padx 6 -pady 4

# ---- live converter ----
labelframe .conv -text "Convert"
set ::val 10
ttk::combobox .conv.unit -textvariable ::unit -width 6 -state readonly \
    -values {px pt mm cm inch}
entry .conv.e -textvariable ::val -width 10
label .conv.eq -text "="
label .conv.out -textvariable ::out -anchor w -fg #225
grid [label .conv.l -text "Value:"] .conv.e .conv.unit .conv.eq -padx 3 -pady 4 -sticky w
grid .conv.out -row 1 -column 0 -columnspan 4 -sticky w -padx 6 -pady {0 6}
pack .conv -fill x -padx 6 -pady 4

proc convert {args} {
    if {![string is double -strict $::val]} { set ::out "(enter a number)"; return }
    set px [toPixels $::val $::unit]
    set d [fromPixels $px]
    set ::out [format "%.1f px   |   %.2f pt   |   %.2f mm   |   %.3f cm   |   %.4f inch" \
        [dict get $d px] [dict get $d pt] [dict get $d mm] [dict get $d cm] [dict get $d inch]]
}
bind .conv.e <KeyRelease> convert
bind .conv.unit <<ComboboxSelected>> convert
set ::unit mm

# ---- reference table ----
labelframe .ref -text "Reference"
tablelist::tablelist .ref.t \
    -columns {10 "Tk spec" left 9 "px" right 9 "pt" right 9 "mm" right 9 "cm" right 9 "inch" right} \
    -stretch all -height 9 -stripebackground #f4f4f4 \
    -yscrollcommand {.ref.vsb set}
ttk::scrollbar .ref.vsb -orient vertical -command {.ref.t yview}
foreach c {1 2 3 4 5} { .ref.t columnconfigure $c -formatcommand {format %.2f} }
grid .ref.t   -row 0 -column 0 -sticky nsew
grid .ref.vsb -row 0 -column 1 -sticky ns
grid rowconfigure .ref 0 -weight 1
grid columnconfigure .ref 0 -weight 1
pack .ref -fill both -expand 1 -padx 6 -pady 4

proc fillRef {} {
    .ref.t delete 0 end
    foreach {val unit spec} {
        1   px   1     10  px  10    1   pt   1p
        12  pt   12p   1   mm  1m    2   mm   2m
        1   cm   1c    1   inch 1i   0.5 inch 0.5i
    } {
        set px [toPixels $val $unit]
        set d [fromPixels $px]
        .ref.t insert end [list $spec \
            [dict get $d px] [dict get $d pt] [dict get $d mm] \
            [dict get $d cm] [dict get $d inch]]
    }
}
fillRef
convert

set mode [lindex $argv 0]
if {$mode eq "--selftest"} {
    update idletasks
    puts "ppi: $::ppi"
    puts "1 inch -> [fromPixels [toPixels 1 inch]]"
    puts "ref rows: [.ref.t size]   1i row: [.ref.t get end]"
    exit 0
} elseif {$mode eq "--shot"} {
    wm geometry . 560x420
    update idletasks; update; after 300; update
    catch {exec import -window root [lindex $argv 1]}
    exit 0
}
