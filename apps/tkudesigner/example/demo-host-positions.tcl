#!/usr/bin/env wish
# Host-side wiring patterns for a loaded .tkd (as lieferschein would do).
# Loads line_items_editor.tkd and connects, purely via byName handles:
#   * click / select a position row  -> fill the edit fields
#   * "Uebernehmen"                   -> write the edit fields back into the row
#   * any change                      -> recompute Netto / MwSt / Gesamt
# None of this lives in the .tkd or in tkuload -- it is the host's own logic.
#
#   wish review/demo-host-positions.tcl
package require Tcl 8.6-
package require Tk 8.6-

set here [file dirname [file normalize [info script]]]
set app01 [file normalize [file join [file dirname [file normalize [info script]]] ..]]
source [file join [file dirname [file normalize [info script]]] .. .. _lib paths.tcl]
package require tkutils::tkuload

wm title . "Positionen -- Host-Demo (tkuload)"
set host [ttk::frame .h]; pack $host -fill both -expand 1
set ::ui [::tkuload::buildFromFile $host \
              [file join $here line_items_editor.tkd]]

set ::selectedRow ""

proc num {v} { expr {[string is double -strict $v] ? $v : 0} }

# recompute the totals from the table's Gesamt column
proc recalc {} {
    set tbl [::tkuload::widgetByName $::ui tblPositionen]
    set netto 0.0
    foreach r [$tbl get 0 end] { set netto [expr {$netto + [num [lindex $r end]]}] }
    set mwst [expr {$netto * 0.19}]
    ::tkuload::setValue $::ui numNetto  [format %.2f $netto]
    ::tkuload::setValue $::ui numMwSt   [format %.2f $mwst]
    ::tkuload::setValue $::ui numGesamt [format %.2f [expr {$netto + $mwst}]]
}

# table row selected -> copy its cells into the edit fields
proc editFromSelection {} {
    set tbl [::tkuload::widgetByName $::ui tblPositionen]
    set i [$tbl curselection]
    if {$i eq ""} return
    lassign [$tbl get $i] pos art bez menge einh ep mw gesamt
    ::tkuload::setValue $::ui entArtikelNr   $art
    ::tkuload::setValue $::ui entBezeichnung $bez
    ::tkuload::setValue $::ui numMenge       $menge
    ::tkuload::setValue $::ui cbEinheit      $einh
    ::tkuload::setValue $::ui numEinzelpreis $ep
    ::tkuload::setValue $::ui cbMwSt         $mw
    set ::selectedRow $i
}

# "Uebernehmen" -> write the edit fields back into the selected row
proc applyEdit {} {
    if {$::selectedRow eq ""} return
    set tbl [::tkuload::widgetByName $::ui tblPositionen]
    set art   [::tkuload::getValue $::ui entArtikelNr]
    set bez   [::tkuload::getValue $::ui entBezeichnung]
    set menge [num [::tkuload::getValue $::ui numMenge]]
    set einh  [::tkuload::getValue $::ui cbEinheit]
    set ep    [num [::tkuload::getValue $::ui numEinzelpreis]]
    set mw    [::tkuload::getValue $::ui cbMwSt]
    set gesamt [format %.2f [expr {$menge * $ep}]]
    set i $::selectedRow
    foreach {col val} [list 1 $art 2 $bez 3 $menge 4 $einh \
                            5 [format %.2f $ep] 6 $mw 7 $gesamt] {
        $tbl cellconfigure $i,$col -text $val
    }
    recalc
}

# --- seed the table with sample positions ----------------------------------
set rows {}
foreach p {
    {AT-001 "Stahlstaebe 2m"      4 Stk 56.00 19}
    {AT-011 "Schrauben M8 (100er)" 2 Pkg 34.50 19}
    {DL-002  "Montage"              3 Std 45.00 19}
} {
    lassign $p art bez menge einh ep mw
    lappend rows [list [expr {[llength $rows]+1}] $art $bez $menge $einh \
                       [format %.2f $ep] $mw [format %.2f [expr {$menge*$ep}]]]
}
::tkuload::setValue $::ui tblPositionen $rows
recalc

# --- HOST-SIDE BINDINGS (the point of this demo) ---------------------------
set tbl [::tkuload::widgetByName $::ui tblPositionen]
bind $tbl <<TablelistSelect>> { editFromSelection }
bind [$tbl bodypath] <Double-1> { editFromSelection }
[::tkuload::widgetByName $::ui btnUebernehmen] configure -command applyEdit

puts "host wired: select a row to edit, change a field, press Uebernehmen."
