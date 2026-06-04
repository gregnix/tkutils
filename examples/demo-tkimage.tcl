set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tkutils::tkimage

set v [::tkutils::tkimage::view .v]
ttk::frame .bar
ttk::button .bar.zin  -text "Zoom +" -command {::tkutils::tkimage::zoomIn .v}
ttk::button .bar.zout -text "Zoom -" -command {::tkutils::tkimage::zoomOut .v}
ttk::button .bar.z1   -text "1:1"    -command {::tkutils::tkimage::zoom1 .v}
ttk::button .bar.fit  -text "Fit"    -command {::tkutils::tkimage::fitView .v}
pack .bar.zin .bar.zout .bar.z1 .bar.fit -side left -padx 2
pack .bar -fill x -padx 6 -pady 6
pack .v -fill both -expand 1 -padx 6 -pady {0 6}
wm title . "tkimage viewer demo"

if {[llength $argv]} {
    ::tkutils::tkimage::openFile .v [lindex $argv 0]
} else {
    # build a sample gradient image so the demo shows something
    set g [image create photo -width 240 -height 160]
    for {set x 0} {$x < 240} {incr x} {
        set c [format "#%02x%02x80" [expr {$x*255/240}] [expr {255-$x*255/240}]]
        $g put $c -to $x 0 [expr {$x+1}] 160
    }
    set f [file join [file dirname [info script]] _tkimage_sample.png]
    $g write $f -format png; image delete $g
    ::tkutils::tkimage::openFile .v $f
}
if {![info exists ::env(DEMO_NOLOOP)]} { vwait forever }
