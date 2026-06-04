#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
# locate the tclutils dependency for in-tree/dev use
# (installed systems already have tclutils on the module path)
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
package require tkutils::tkvcard
package require tclutils::tuvcard
wm title . "tkvcard demo"
set w [::tkutils::tkvcard::widget .w]
pack $w -fill both -expand 1

# Build Alice with an inline photo generated at runtime.
set g [image create photo -width 96 -height 96]
for {set y 0} {$y < 96} {incr y} {
    set c [format "#%02x40%02x" [expr {$y*255/96}] [expr {255-$y*255/96}]]
    $g put $c -to 0 $y 96 [expr {$y+1}]
}
set tmp [file join $here _demo_face.png]
$g write $tmp -format png; image delete $g
set ch [open $tmp rb]; set png [read $ch]; close $ch; file delete $tmp

set alice [::tclutils::tuvcard::addProperty {} FN "Alice Smith"]
set alice [::tclutils::tuvcard::addProperty $alice EMAIL alice@example.com {TYPE work}]
set alice [::tclutils::tuvcard::addProperty $alice ORG "Example GmbH"]
set alice [::tclutils::tuvcard::setPhoto $alice image/png $png]
set bob [::tclutils::tuvcard::addProperty {} FN "Bob Jones"]
set bob [::tclutils::tuvcard::addProperty $bob EMAIL bob@example.com]
set bob [::tclutils::tuvcard::setPhotoUri $bob https://example.com/bob.jpg]

::tkutils::tkvcard::setCards $w [list $alice $bob]

if {![info exists ::env(DEMO_NOLOOP)]} { vwait forever }
