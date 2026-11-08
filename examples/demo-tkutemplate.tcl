#!/usr/bin/env wish
# Demo: tkutils::tkutemplate -- edit a delivery-note template, preview it as PDF.
#
# The preview needs pdf4tcllib (pdf4tcltemplate) and pdf4tcl; they are
# looked for beside this checkout (../pdf4tcllib/lib, ../pdf4tcl) or via
# PDF4TCLLIB_TM. Without them everything but "Preview" works.

set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    catch {tcl::tm::path add [file normalize [file join $here .. .. tclutils lib tm]]}
}
if {[info exists ::env(PDF4TCLLIB_TM)]} {
    tcl::tm::path add $::env(PDF4TCLLIB_TM)
} else {
    catch {tcl::tm::path add [file normalize [file join $here .. .. pdf4tcllib lib]]}
}
foreach d [list [file join $here .. .. pdf4tcl] [file join $here .. .. pdf4tcl pkg]] {
    if {[file isdirectory $d]} { lappend auto_path [file normalize $d] }
}

package require tkutils::tkutemplate 0.1

set template {
    paper a4  margin 20  size 10
    theme {accent {0.15 0.30 0.20} muted {0.40 0.40 0.40}}
    blocks {
        firm     {x 20 y 18 w 110 size 18 bold 1 color accent}
        sender   {x 20 y 45 w 85 size 7 color muted}
        address  {x 20 y 50 w 85 size 11 list 1}
        refs     {type pairs x 125 y 50 w 65 labelw 30 size 9}
        title    {x 20 y 95 w 170 size 15 bold 1 color accent text "Delivery note {number}"}
        items    {type table x 20 y 108 w 170 size 9 zebra 1
                  cols {{key pos title Pos w 12 align right} {key text title Item}
                        {key qty title Qty w 22 align right} {key unit title Unit w 16}}}
        note     {x 20 y 0 w 170 gap 8 color muted}
        foot     {x 20 y 282 w 170 size 8 color muted page all align center
                  text "{firm} -- page {page} of {pages}"}
    }
}
set rows {}
for {set i 1} {$i <= 25} {incr i} {
    lappend rows [list pos $i text "Item $i" qty [expr {$i * 10}] unit pcs]
}
set sample [dict create \
    firm    "Example Nursery" \
    sender  "Example Nursery · Garden Lane 1 · 12345 Greenfield" \
    address {"Flower Shop Miller" "" "Main Street 5" "54321 Town"} \
    refs    {Number LS-0007 Date 2026-11-08 Customer K12} \
    number  LS-0007 \
    items   $rows \
    note    "Please check the goods on delivery.\nThank you for your order."]

wm title . "tkutemplate demo"
wm geometry . 1120x800
ttk::label .info -padding 6 -anchor w
pack .info -side bottom -fill x
pack [tkutils::tkutemplate::widget .te -template $template -sample $sample \
    -onchange {apply {{p t} {
        .info configure -text "[dict size [dict get $t blocks]] blocks -- changed"
    }}}] -fill both -expand 1
.info configure -text "Drag blocks, edit them on the right, Preview draws the PDF."
