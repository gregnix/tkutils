#!/usr/bin/env wish
# Demo: load a named modern design via tkuload and bind values by name.
# Shows that the interactive widgets carry stable handles (entName, cbKategorie,
# ...), so a host can fill and collect them without touching widget paths.
set here [file dirname [file normalize [info script]]]
source [file join [file dirname [file normalize [info script]]] .. .. _lib paths.tcl]
package require tkutils::tkuload

set ui [::tkuload::buildFromFile . [file join $here modern_adressbuch.tkd]]

# fill a handful of named fields ...
::tkuload::fill $ui {
    entName     "Mustermann GmbH"
    entFirma    "Muster AG"
    entStrasse  "Musterweg 1"
    entPLZOrt   "48691 Vreden"
    entTelefon  "02564 12345"
    entEMail    "info@muster.example"
    cbKategorie "Kunde"
    txtNotizen  "Stammkunde seit 2019."
}
# ... and read them back by name
puts "collected: [::tkuload::collect $ui {entName entFirma entPLZOrt cbKategorie}]"

if {[info exists ::env(TKU_DEMO_BATCH)]} { after 300 exit }
