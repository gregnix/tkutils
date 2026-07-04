#!/usr/bin/env wish
# ===========================================================================
# Demo / tool: dhash -- perceptual image hashing. Generates three sample
# images (an original, a brightened + noisy "re-saved" copy, and a genuinely
# different one), hashes each with tkutils::tkudhash, and shows the 64-bit
# dHash plus the pairwise Hamming distances -- small distance = same picture.
# Belongs to tkutils; the hashing core is tclutils::tudhash.
#
#   wish demo-tkudhash.tcl
#   tclsh demo-tkudhash.tcl --selftest
#   tclsh demo-tkudhash.tcl --shot out.png
# ===========================================================================

set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
tcl::tm::path add [file normalize [file join $here .. .. tclutils lib tm]]

package require Tk
package require tkutils::tkudhash

# --- build sample images in memory ----------------------------------------
proc sampleImage {w h {shift 0} {noise 0} {mode grad}} {
    set img [image create photo -width $w -height $h]
    for {set y 0} {$y < $h} {incr y} {
        set row {}
        for {set x 0} {$x < $w} {incr x} {
            if {$mode eq "grad"} {
                set v [expr {($x * 2 + $y) % 256 + $shift}]
            } else {
                set v [expr {(255 - $x * 2 + $y * 5) % 256}]
            }
            if {$noise} { set v [expr {$v + int(rand()*$noise) - $noise/2}] }
            set v [expr {$v < 0 ? 0 : ($v > 255 ? 255 : $v)}]
            lappend row [format "#%02x%02x%02x" $v $v $v]
        }
        $img put [list $row] -to 0 $y
    }
    return $img
}

set tmp [file join [pwd] .dhash-demo]
file mkdir $tmp
proc save {img name} {
    global tmp
    set p [file join $tmp $name]
    $img write $p -format png
    return $p
}

set imgO [sampleImage 160 120 0 0]
set imgR [sampleImage 160 120 8 10]
set imgD [sampleImage 160 120 0 0 other]
set pO [save $imgO orig.png]
set pR [save $imgR resaved.png]
set pD [save $imgD other.png]

set hO [::tkutils::tkudhash::fromFile $pO]
set hR [::tkutils::tkudhash::fromFile $pR]
set hD [::tkutils::tkudhash::fromFile $pD]
set dOR [::tkutils::tkudhash::distance $hO $hR]
set dOD [::tkutils::tkudhash::distance $hO $hD]

# --- headless modes --------------------------------------------------------
proc report {} {
    global hO hR hD dOR dOD
    puts "original : $hO"
    puts "re-saved : $hR   distance to original: $dOR  (near-duplicate)"
    puts "different: $hD   distance to original: $dOD"
}

if {[lindex $argv 0] eq "--selftest"} {
    report
    if {$dOR <= 10 && $dOD > 15} { puts "SELFTEST OK" ; exit 0 }
    puts "SELFTEST FAILED"; exit 1
}

# --- GUI -------------------------------------------------------------------
wm title . "dHash demo"
set i 0
foreach {img hash label dist} [list \
        $imgO $hO "original" "" \
        $imgR $hR "re-saved (brighter + noise)" "distance $dOR -> [expr {$dOR<=10 ? {near-duplicate} : {different}}]" \
        $imgD $hD "different image" "distance $dOD -> [expr {$dOD<=10 ? {near-duplicate} : {different}}]"] {
    set f [ttk::frame .c$i -padding 8]
    grid $f -row 0 -column $i -sticky n
    ttk::label $f.img -image $img -relief solid
    ttk::label $f.lbl -text $label
    ttk::label $f.hsh -text $hash -font TkFixedFont
    ttk::label $f.dst -text $dist -foreground gray30
    grid $f.img $f.lbl $f.hsh $f.dst -sticky w
    grid $f.lbl -pady {6 0}
    incr i
}

if {[lindex $argv 0] eq "--shot"} {
    set out [lindex $argv 1]
    if {$out eq ""} { set out dhash.png }
    update; after 300
    if {![catch {package require Img}]} {
        set g [image create photo -format window -data .]
        $g write $out -format png
        puts "wrote $out"
    }
    exit 0
}
