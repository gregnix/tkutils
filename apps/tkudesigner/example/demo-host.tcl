#!/usr/bin/env wish
# End-to-end host integration: load a .tkd, fill it from data via byName,
# compute sums, and read the form back -- exactly how a host application would
# consume a tkudesigner design through tkuload.
#
#   wish example/demo-host.tcl
package require Tcl 8.6-
package require Tk 8.6-

set here [file dirname [file normalize [info script]]]
source [file join $here .. .. _lib paths.tcl]
package require tkutils::tkuload

wm title . "Faktura -- Host-Demo (tkuload)"
set host [ttk::frame .h]
pack $host -fill both -expand 1
set ui [::tkuload::buildFromFile $host [file join $here modern_faktura_complete.tkd]]

# --- a document as a host / DB would supply it -----------------------------
set kopf {
    belegnr    RE-2026-0042
    datum      2026-06-28
    lieferdat  2026-06-25
    kundennr   K-10042
    firma      "Mustermann GmbH"
    kunde      "Erika Mustermann"
    strasse    "Musterweg 1"
    plzort     "55555 Musterstadt"
    ustidnr    DE123456789
    referenz   "Auftrag 1234"
    status     Offen
    zahlart    Ueberweisung
}
# positions: menge einzelpreis (net)
set positionen {
    {4 56.00}
    {2 34.50}
    {3 45.00}
}

# --- domain logic: net / VAT / gross ---------------------------------------
set netto 0.0
foreach p $positionen { lassign $p menge ep; set netto [expr {$netto + $menge*$ep}] }
set mwst   [expr {$netto * 0.19}]
set brutto [expr {$netto + $mwst}]

# --- wire the form purely by symbolic name (the HIG names) -----------------
::tkuload::fill $ui [dict create \
    entBelegNr     [dict get $kopf belegnr] \
    entDatum       [dict get $kopf datum] \
    entLieferdatum [dict get $kopf lieferdat] \
    entKundennr    [dict get $kopf kundennr] \
    entFirma       [dict get $kopf firma] \
    entKunde       [dict get $kopf kunde] \
    entStrasse     [dict get $kopf strasse] \
    entPLZOrt      [dict get $kopf plzort] \
    entUStIdNr     [dict get $kopf ustidnr] \
    entReferenz    [dict get $kopf referenz] \
    cbStatus       [dict get $kopf status] \
    cbZahlungsart  [dict get $kopf zahlart] \
    entNetto       [format %.2f $netto] \
    entMwSt19      [format %.2f $mwst] \
    entBrutto      [format %.2f $brutto] \
    txtNotizen     "Lieferung frei Haus. Zahlbar 14 Tage netto."]

# --- read the form back (as on "Speichern") --------------------------------
set back [::tkuload::collect $ui \
            {entBelegNr entKunde entPLZOrt cbStatus entNetto entMwSt19 entBrutto}]
puts "loaded modern_faktura_complete.tkd ([dict size [dict get $ui byName]] named widgets)"
puts "round-trip readback:"
dict for {k v} $back { puts [format "  %-12s = %s" $k $v] }
puts "notes = \"[::tkuload::getValue $ui txtNotizen]\""
