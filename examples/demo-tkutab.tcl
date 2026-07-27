#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require Tk
package require tkutils::tkutab

wm title . "tkutab demo"
wm geometry . 520x360

set ::counter 0

proc newTab {} {
    incr ::counter
    set f [::tkutils::tkutab::add .tabs "Tab $::counter"]
    ttk::label $f.l -text "This is tab #$::counter\n\nMiddle-click a tab to close it.\nPress + to add another." \
        -anchor center -justify center
    pack $f.l -fill both -expand 1 -padx 20 -pady 20
    return $f
}

::tkutils::tkutab::widget .tabs \
    -onnew    {newTab} \
    -onclose  {apply {f {puts "closed $f"}}} \
    -onselect {apply {f {wm title . "tkutab demo -- [::tkutils::tkutab::count .tabs] tab(s)"}}}
pack .tabs -fill both -expand 1

# open two tabs to start
newTab
newTab
