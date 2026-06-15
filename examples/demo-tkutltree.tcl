#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutltree -- build a multi-column tablelist tree from nested
# data and read it back. Free column mapping: each node's fields fill several
# columns; children form the hierarchy.
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir

package require Tk
package require tablelist
package require tkutils::tkutltree

wm title . "tkutltree demo"

set data {
    {name "Project" size 0 type folder children {
        {name "src" size 0 type folder children {
            {name "main.tcl"  size 2048 type file}
            {name "util.tcl"  size 1536 type file}
        }}
        {name "docs" size 0 type folder children {
            {name "README.md" size  890 type file}
        }}
        {name "LICENSE" size 1071 type file}
    }}
}

tablelist::tablelist .t \
    -columns {0 "Name" left  0 "Size" right  0 "Type" left} \
    -treecolumn 0 -stretch all -stripebackground #eef -height 12
pack .t -fill both -expand 1

::tkutils::tkutltree::fromData .t $data -fields {name size type}
.t expandall

if {[lindex $argv 0] eq "--selftest"} {
    update idletasks
    set back [::tkutils::tkutltree::toData .t -fields {name size type}]
    puts "top-level nodes: [llength $back]"
    puts "root children:   [llength [dict get [lindex $back 0] children]]"
    puts $back
    exit 0
}
