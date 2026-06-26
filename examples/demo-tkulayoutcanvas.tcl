#!/usr/bin/env wish
# Demo: tkutils::tkulayoutcanvas — generic block layout designer (no host app).

set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
set tclTm [file normalize [file join $here .. .. tclutils lib tm]]
catch {tcl::tm::path add $tclTm}

package require tkutils::tkulayoutcanvas 0.1

wm title . "tkulayoutcanvas demo"
wm geometry . 900x620

pack [ttk::label .hint -padding 8 -anchor w -text \
    "Drag blocks on the page. Auto-Y blocks (footer) keep y=0. Edits snap to 5 mm."] -fill x

set ::defs {
    header  {label Header  w 170 h 15}
    address {label Address w 80  h 25}
    body    {label Body    w 170 h 45}
    footer  {label Footer  w 170 h 10 lockedY 1}
}
set ::blocks {
    header  {label Header  x 20 y 25 w 170 h 15 show 1}
    address {label Address x 120 y 50 w 80 h 25 show 1}
    body    {label Body    x 20 y 80 w 170 h 45 show 1}
    footer  {label Footer  x 20 y 0  w 170 h 10 show 1 lockedY 1}
}

::tkutils::tkulayoutcanvas::widget .lc -blocks $::blocks -definitions $::defs \
    -paper a4 -gridmm 5 -scale 3.2 \
    -onchange {apply {{p b} {
        .status configure -text "Blocks: [dict size $b] — last change from [winfo name $p]"
    }}}
pack .lc -fill both -expand 1 -padx 8 -pady 4

ttk::frame .bar
pack .bar -fill x -padx 8 -pady 4
ttk::button .bar.dump -text "Print blocks dict" -command {
    puts "=== blocks ==="
    puts [::tkutils::tkulayoutcanvas::getBlocks .lc]
}
ttk::button .bar.preset -text "Apply preset (header x=30)" -command {
    ::tkutils::tkulayoutcanvas::mergePreset .lc {header {x 30 show 1}}
}
pack .bar.dump .bar.preset -side left -padx 4
ttk::label .status -padding {8 4} -anchor w -text "Ready."
pack .status -fill x

vwait forever
