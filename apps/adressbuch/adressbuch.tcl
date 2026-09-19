#!/usr/bin/env wish
# adressbuch.tcl -- Liste und Maske ueber adressbuch-modell.tcl.
#
#     wish adressbuch.tcl ?datei.db?
#
# Folgt den Mustern aus serie-liste-maske:
#
#   02-id-statt-zeile     die Kennung steht in "rowcget -name", nicht in
#                         der Zeilennummer -- nach dem Sortieren zeigt
#                         Zeile 3 auf einen anderen Datensatz
#   05-speichern          nur die eine Zeile auffrischen
#   06-auswahl-behalten   die Auswahl ueber die KENNUNG wiederherstellen
#   09-ungespeichert      beim Wechsel mit offenen Aenderungen fragen
#   10-validierung        Pflichtfeld leer -> nicht speichern, und sagen
#                         welches
#   13-suchen             ueber alle Felder

package require Tk
package require Ttk
package require tablelist_tile

set ::appdir [file dirname [file normalize [info script]]]
# DAS MODELL IST EIN PAKET, die Oberflaeche nicht.
#
# lib/tm daneben in die Modulsuche haengen, damit die Anwendung ohne
# gesetzte Umgebungsvariable laeuft -- wer sie auspackt und startet,
# soll nicht erst TCL9_0_TM_PATH setzen muessen.
set ::abmodules [file join $::appdir lib tm]
if {[file isdirectory $::abmodules]
        && $::abmodules ni [::tcl::tm::path list]} {
    ::tcl::tm::path add $::abmodules
}
package require adressbuch::model

source [file join $::appdir adressbuch-einstellungen.tcl]

namespace eval ::ab {
    variable tbl ""
    variable felder {}          ;# Feldname -> Eingabefeld
    variable aktuell ""         ;# Kennung des angezeigten Datensatzes
    variable urzustand {}       ;# zum Erkennen von Aenderungen
    variable status ""
    variable suche ""
    # Rueckfragen abschaltbar -- sonst haengt jeder Test an einem
    # tk_messageBox, das auf eine Antwort wartet, die niemand gibt.
    # 0 bedeutet: verhalte dich wie "ja, weiter" ohne zu fragen.
    variable fragen 1
    variable dav
    array set dav {url "" pfad "" user "" pass "" ok 0}
    variable vs
    array set vs {neu "" neu2 "" ok 0}
    variable kw
    array set kw {wert "" ok 0}
}

# --- Maske -----------------------------------------------------------------

# Die Beschriftungen an einer Stelle. Wer ein Feld ergaenzt, aendert
# hier und in ::adressbuch::felder -- sonst nirgends.
proc ::ab::beschriftung {feld} {
    array set b {
        vorname Vorname  name Name        strasse Strasse  nummer Nr.
        plz     PLZ      ort  Ort         telefon Telefon  mobil  Mobil
        email   E-Mail   email2 {E-Mail 2} notiz  Notiz
    }
    if {[info exists b($feld)]} { return $b($feld) }
    return $feld
}

proc ::ab::maskeBauen {eltern} {
    variable felder
    set r 0
    foreach f [adressbuch::felder] {
        ttk::label $eltern.l$f -text "[beschriftung $f]:"
        grid $eltern.l$f -row $r -column 0 -sticky w -padx {0 8} -pady 2
        if {$f eq "notiz"} {
            text $eltern.e$f -height 4 -width 30 -wrap word
            grid $eltern.e$f -row $r -column 1 -sticky ew -pady 2
        } else {
            ttk::entry $eltern.e$f -width 30
            grid $eltern.e$f -row $r -column 1 -sticky ew -pady 2
        }
        dict set felder $f $eltern.e$f
        incr r
    }
    grid columnconfigure $eltern 1 -weight 1
}

proc ::ab::maskeLesen {} {
    variable felder
    set w [dict create]
    dict for {f pfad} $felder {
        if {[winfo class $pfad] eq "Text"} {
            dict set w $f [string trimright [$pfad get 1.0 end] "\n"]
        } else {
            dict set w $f [$pfad get]
        }
    }
    return $w
}

proc ::ab::maskeSetzen {werte} {
    variable felder
    dict for {f pfad} $felder {
        set v [expr {[dict exists $werte $f] ? [dict get $werte $f] : ""}]
        if {[winfo class $pfad] eq "Text"} {
            $pfad delete 1.0 end
            $pfad insert 1.0 $v
        } else {
            $pfad delete 0 end
            $pfad insert 0 $v
        }
    }
}

# --- Liste -----------------------------------------------------------------

# DIE BILDLAUFLEISTE IST EIN NACHBAR DER TABELLE, KEIN KIND.
#
# Erste Fassung: "ttk::scrollbar $pfad.sb" -- damit lag sie IN der
# Tabelle, zwischen deren eigenen Teilen (.hdr, .body, .lb). Sichtbar
# war sie als winziger Stummel unten rechts. Gemeldet 12.09.2026.
#
# Ein Widget, dessen Pfad unter einem Megawidget liegt, gehoert diesem --
# tablelist verwaltet den Platz darin selbst und weiss von dem Fremdling
# nichts.
#
# UND ES BLEIBT NICHT BEIM AUSSEHEN: die falsche Fassung liess den
# Testlauf in die Zeitsperre laufen (rc 124). Zwei Geometrieverwalter,
# die denselben Platz aushandeln, kommen nicht zur Ruhe.
#
# Darum ein eigener Rahmen: Tabelle und Leiste sind Geschwister darin.
proc ::ab::listeBauen {pfad} {
    variable tbl
    ttk::frame $pfad
    set tbl [tablelist::tablelist $pfad.t \
            -columns {0 Name left  0 Vorname left  0 Ort left} \
            -stretch all -selectmode browse -exportselection 0 \
            -yscrollcommand [list $pfad.sb set]]
    ttk::scrollbar $pfad.sb -orient vertical -command [list $tbl yview]
    grid $tbl     -row 0 -column 0 -sticky nsew
    grid $pfad.sb -row 0 -column 1 -sticky ns
    grid rowconfigure    $pfad 0 -weight 1
    grid columnconfigure $pfad 0 -weight 1
    # AN DAS WIDGET BINDEN, NICHT AN DEN KORPUS.
    #
    # "bind [$tbl bodytag] <<TablelistSelect>>" sieht richtig aus und
    # war es nicht: bei einem echten Mausklick blieb die Maske LEER,
    # obwohl die Zeile ausgewaehlt war. Gemeldet 12.09.2026 mit einem
    # Bildschirmfoto.
    #
    # Warum es beim Pruefen nicht auffiel: ein von Hand erzeugtes
    # "event generate <<TablelistSelect>>" laeuft NACH dem Setzen der
    # Auswahl und geht deshalb gut. Der echte Klick nimmt den anderen
    # Weg. Ein Test, der das Ereignis selbst erzeugt, misst die
    # Reihenfolge nicht.
    bind $tbl <<TablelistSelect>> [list ::ab::zeileGewaehlt]
    return $tbl
}

# DIE KENNUNG STEHT IM ZEILENNAMEN, nicht in der Zeilennummer.
#
# Nach dem Sortieren zeigt Zeile 3 auf einen anderen Datensatz. Wer sich
# die Nummer merkt, bearbeitet den falschen -- siehe
# serie-liste-maske/02-id-statt-zeile.
proc ::ab::listeFuellen {{auswahlId ""}} {
    variable tbl
    variable suche
    if {$auswahlId eq ""} { set auswahlId [aktuelleId] }
    $tbl delete 0 end
    foreach id [adressbuch::alle $suche] {
        set d [adressbuch::lesen $id]
        $tbl insert end [list [dict get $d name] [dict get $d vorname] \
                              [dict get $d ort]]
        $tbl rowconfigure end -name $id
    }
    auswahlSetzen $auswahlId
    statusMelden "[$tbl size] Eintraege"
}

proc ::ab::aktuelleId {} {
    variable tbl
    set sel [$tbl curselection]
    if {![llength $sel]} { return "" }
    return [$tbl rowcget [lindex $sel 0] -name]
}

# Die Auswahl ueber die KENNUNG wiederherstellen, nicht ueber die
# Zeilennummer -- nach Filter oder Sortierung steht sie woanders.
proc ::ab::auswahlSetzen {id} {
    variable tbl
    $tbl selection clear 0 end
    if {$id eq ""} { maskeLeeren ; return }
    for {set i 0} {$i < [$tbl size]} {incr i} {
        if {[$tbl rowcget $i -name] eq $id} {
            $tbl selection set $i
            $tbl see $i
            zeileGewaehlt
            return
        }
    }
    # Der Datensatz ist durch den Filter gefallen.
    maskeLeeren
}

# --- Ablauf ----------------------------------------------------------------

proc ::ab::zeileGewaehlt {} {
    variable aktuell
    variable urzustand
    set id [aktuelleId]
    if {$id eq "" || $id eq $aktuell} return
    if {![wechselErlaubt]} {
        # Zurueck auf den alten Datensatz -- ohne erneutes Fragen.
        set merk $aktuell
        set aktuell ""
        auswahlSetzen $merk
        return
    }
    set aktuell $id
    set d [adressbuch::lesen $id]
    maskeSetzen $d
    set urzustand [maskeLesen]
}

proc ::ab::geaendert {} {
    variable urzustand
    return [expr {[maskeLesen] ne $urzustand}]
}

# Beim Wechsel mit offenen Aenderungen fragen -- nicht stillschweigend
# verwerfen (serie-liste-maske/09-ungespeichert).
proc ::ab::wechselErlaubt {} {
    variable aktuell
    variable fragen
    if {$aktuell eq "" || ![geaendert]} { return 1 }
    if {!$fragen} { return 1 }
    set a [tk_messageBox -type yesnocancel -icon question \
            -title "Ungespeicherte Aenderungen" \
            -message "Der Datensatz wurde geaendert. Speichern?"]
    switch -- $a {
        yes    { return [speichern] }
        no     { return 1 }
        cancel { return 0 }
    }
    return 0
}

proc ::ab::maskeLeeren {} {
    variable aktuell
    variable urzustand
    set aktuell ""
    maskeSetzen {}
    set urzustand [maskeLesen]
}

proc ::ab::neu {} {
    variable tbl
    if {![wechselErlaubt]} return
    $tbl selection clear 0 end
    maskeLeeren
    focus [dict get $::ab::felder vorname]
    statusMelden "Neuer Eintrag -- Speichern legt ihn an"
}

# Pflichtfeld leer: nicht speichern, und SAGEN welches
# (serie-liste-maske/10-validierung).
proc ::ab::speichern {} {
    variable aktuell
    variable urzustand
    set w [maskeLesen]
    if {[string trim [dict get $w name]] eq ""} {
        if {$::ab::fragen} {
            tk_messageBox -icon warning -title Pflichtfeld \
                    -message "Das Feld \"Name\" darf nicht leer sein."
            focus [dict get $::ab::felder name]
        }
        statusMelden "Das Feld \"Name\" darf nicht leer sein."
        return 0
    }
    set id [adressbuch::schreiben $aktuell $w]
    set aktuell $id
    set urzustand $w
    listeFuellen $id
    statusMelden "Gespeichert"
    return 1
}

proc ::ab::loeschen {} {
    variable aktuell
    variable tbl
    if {$aktuell eq ""} return
    set d [adressbuch::lesen $aktuell]
    set wer [string trim "[dict get $d vorname] [dict get $d name]"]
    if {$::ab::fragen
            && [tk_messageBox -type yesno -icon question -title Loeschen \
                    -message "\"$wer\" wirklich loeschen?"] ne "yes"} return
    # Nach dem Loeschen auf den NAECHSTEN springen, nicht ins Leere
    # (serie-liste-maske/07-neu-und-loeschen).
    set naechste ""
    set sel [$tbl curselection]
    if {[llength $sel]} {
        set i [expr {[lindex $sel 0] + 1}]
        if {$i < [$tbl size]} { set naechste [$tbl rowcget $i -name] }
    }
    adressbuch::loeschen $aktuell
    set ::ab::aktuell ""
    listeFuellen $naechste
    statusMelden "Geloescht"
}

# ALLES LOESCHEN -- zwei Huerden, nicht eine.
#
# Ein "Wirklich?" klickt man weg. Wer alles wegwirft, soll die Zahl
# gelesen haben und den Namen der Sicherung danach kennen.
#
# Die Vorgabe der Rueckfrage ist NEIN: wer versehentlich die Eingabe-
# taste drueckt, loescht nichts.
proc ::ab::allesLoeschen {} {
    variable fragen
    set n [llength [adressbuch::alle]]
    if {$n == 0} {
        statusMelden "Nichts zu loeschen"
        return 0
    }
    if {$fragen} {
        set a [tk_messageBox -type yesno -default no -icon warning \
                -title "Alles loeschen" \
                -message "Alle $n Eintraege loeschen?\n\nEine Sicherung\
wird vorher angelegt."]
        if {$a ne "yes"} { statusMelden "Abgebrochen" ; return 0 }
    }
    if {[catch {adressbuch::allesLoeschen} kopie]} {
        statusMelden "Nicht geloescht: $kopie"
        if {$fragen} {
            tk_messageBox -icon error -title Fehler -message $kopie
        }
        return 0
    }
    set ::ab::aktuell ""
    set ::ab::suche ""
    listeFuellen
    if {$kopie ne ""} {
        statusMelden "$n geloescht. Sicherung: $kopie"
        if {$fragen} {
            tk_messageBox -icon info -title "Sicherung" \
                    -message "Die Sicherung liegt unter:\n$kopie"
        }
    } else {
        statusMelden "$n geloescht"
    }
    return 1
}

proc ::ab::verwerfen {} {
    variable aktuell
    if {$aktuell eq ""} { maskeLeeren ; return }
    maskeSetzen [adressbuch::lesen $aktuell]
    set ::ab::urzustand [maskeLesen]
    statusMelden "Verworfen"
}

proc ::ab::suchen {} {
    listeFuellen
}

proc ::ab::statusMelden {text} {
    set z [schlossZeichen]
    if {$z ne ""} { set text "\[$z\]  $text" }
    set ::ab::status $text
}

# --- Ein und Ausgabe -------------------------------------------------------

# Einlesen. "auto" erkennt Outlook, Thunderbird und das eigene Format
# an der Kopfzeile -- und merkt, wenn gar keine da ist.
proc ::ab::csvHolen {{herkunft auto}} {
    set titel "CSV einlesen"
    if {$herkunft ne "auto"} { append titel " ($herkunft)" }
    set f [tk_getOpenFile -title $titel \
            -filetypes {{CSV {.csv}} {Alle *}}]
    if {$f eq ""} return
    if {[catch {adressbuch::csvLesen $f -herkunft $herkunft} n]} {
        statusMelden "Nicht eingelesen: $n"
        if {$::ab::fragen} {
            tk_messageBox -icon error -title "Einlesen" -message $n
        }
        return
    }
    listeFuellen
    statusMelden "$n Datensaetze eingelesen ([file tail $f])"
}

# --- CardDAV ---------------------------------------------------------------

# Server, Pfad und Benutzer bleiben in den Einstellungen -- das KENNWORT
# NICHT.
#
# Es in eine Klartextdatei zu schreiben waere bequem und falsch: die
# Datei liegt neben den Adressen, und wer sie liest, hat den Zugang zum
# ganzen Server. Wer es nicht jedesmal tippen will, nimmt dafuer den
# Schluesselbund seines Systems -- das ist ein eigener Schritt.
proc ::ab::davDialog {} {
    variable fragen
    set w .dav
    destroy $w
    toplevel $w
    wm title $w "Von CardDAV holen"
    wm transient $w .

    set ::ab::dav(url)   [abconf::hol dav url]
    set ::ab::dav(pfad)  [abconf::hol dav pfad]
    set ::ab::dav(user)  [abconf::hol dav benutzer]
    set ::ab::dav(pass)  ""
    set ::ab::dav(ok)    0

    ttk::frame $w.f -padding 10
    pack $w.f -fill both -expand 1
    set r 0
    foreach {feld text} {url Server: pfad Pfad: user Benutzer: pass Kennwort:} {
        ttk::label $w.f.l$feld -text $text
        grid $w.f.l$feld -row $r -column 0 -sticky w -padx {0 8} -pady 3
        if {$feld eq "pass"} {
            ttk::entry $w.f.e$feld -width 40 -show * \
                    -textvariable ::ab::dav($feld)
        } else {
            ttk::entry $w.f.e$feld -width 40 -textvariable ::ab::dav($feld)
        }
        grid $w.f.e$feld -row $r -column 1 -sticky ew -pady 3
        incr r
    }
    grid columnconfigure $w.f 1 -weight 1

    ttk::label $w.f.hinweis -foreground gray40 -justify left \
            -text "Das Kennwort wird nicht gespeichert.\nGeholt wird nur,\
was eine vCard ist."
    grid $w.f.hinweis -row $r -column 0 -columnspan 2 -sticky w -pady {8 0}
    incr r

    ttk::frame $w.f.k
    grid $w.f.k -row $r -column 0 -columnspan 2 -sticky e -pady {10 0}
    ttk::button $w.f.k.ok -text Holen -command [list set ::ab::dav(ok) 1]
    ttk::button $w.f.k.ab -text Abbrechen -command [list set ::ab::dav(ok) 0]
    pack $w.f.k.ok $w.f.k.ab -side left -padx {6 0}

    bind $w <Return> [list set ::ab::dav(ok) 1]
    bind $w <Escape> [list set ::ab::dav(ok) 0]
    wm protocol $w WM_DELETE_WINDOW [list set ::ab::dav(ok) 0]

    if {$::ab::dav(url) eq ""} { set ::ab::dav(url) "http://127.0.0.1:5232" }
    focus $w.f.eurl
    if {$fragen} {
        grab set $w
        vwait ::ab::dav(ok)
        catch {grab release $w}
    }
    set gewollt $::ab::dav(ok)
    destroy $w
    if {!$gewollt} { statusMelden "Abgebrochen" ; return 0 }
    return [davHolen]
}

proc ::ab::davHolen {} {
    if {$::ab::dav(url) eq ""} {
        statusMelden "Kein Server angegeben"
        return 0
    }
    statusMelden "Hole von $::ab::dav(url) ..."
    update idletasks
    if {[catch {
        adressbuch::davHolen $::ab::dav(url) \
                -pfad $::ab::dav(pfad) \
                -user $::ab::dav(user) \
                -password $::ab::dav(pass)
    } n]} {
        statusMelden "Nicht geholt: $n"
        if {$::ab::fragen} {
            tk_messageBox -icon error -title CardDAV -message $n
        }
        return 0
    }
    # Server, Pfad und Benutzer merken -- das Kennwort nicht.
    abconf::setz dav url      $::ab::dav(url)
    abconf::setz dav pfad     $::ab::dav(pfad)
    abconf::setz dav benutzer $::ab::dav(user)
    set ::ab::dav(pass) ""
    listeFuellen
    statusMelden "$n Karten geholt"
    return $n
}

# Einmal einrichten statt jedesmal eine Umgebungsvariable setzen.
# --- Ueber ------------------------------------------------------------------

# Ein Schloss in der Statuszeile, damit man es SIEHT statt zu glauben.
proc ::ab::schlossZeichen {} {
    set v [adressbuch::istVerschluesselt]
    if {$v eq ""} { return "" }
    # KEIN Schloss-Sinnbild: "\u1F512" liegt jenseits der BMP, braucht
    # in Tcl "\U0001F512" -- und selbst dann muss die Schrift es haben.
    # Gemessen kam ein Ersatzzeichen heraus. Worte sind eindeutig.
    return [expr {$v ? "verschluesselt" : "offen"}]
}

proc ::ab::ueberText {} {
    set a [adressbuch::auskunft]
    set zeilen {}
    lappend zeilen "Adressbuch"
    lappend zeilen ""
    lappend zeilen "Tcl        [dict get $a tcl]"
    lappend zeilen "SQLite     [dict get $a sqlite]"
    lappend zeilen ""
    if {![dict get $a kryptoEin]} {
        lappend zeilen "Verschluesseln: ABGESCHALTET (Funktion unfertig)"
        lappend zeilen "  Vorhandene verschluesselte Dateien lassen sich"
        lappend zeilen "  oeffnen und entschluesseln."
    } elseif {[dict get $a mcAktiv]} {
        lappend zeilen "Verschluesselung moeglich: ja"
        lappend zeilen "  [dict get $a mcDatei]"
    } else {
        lappend zeilen "Verschluesselung moeglich: nein"
        lappend zeilen "  SQLite3MultipleCiphers fehlt."
        lappend zeilen "  Datei -> Verschluesselung einrichten..."
    }
    lappend zeilen ""
    set datei [dict get $a datei]
    if {$datei eq ""} {
        lappend zeilen "Keine Datei geoeffnet."
    } else {
        lappend zeilen "Datei      $datei"
        lappend zeilen "Eintraege  [dict get $a eintraege]"
        lappend zeilen "Schema     Fassung [dict get $a schema]"
        set v [dict get $a verschluesselt]
        if {$v eq ""} {
            lappend zeilen "Zustand    unbekannt"
        } elseif {$v} {
            lappend zeilen "Zustand    VERSCHLUESSELT"
        } else {
            # Deutlich sagen, was das heisst -- "nein" allein liest
            # sich wie eine Nebensache.
            lappend zeilen "Zustand    NICHT verschluesselt"
            lappend zeilen "           (wer die Datei liest, liest die Adressen)"
        }
    }
    return [join $zeilen "\n"]
}

proc ::ab::ueber {} {
    variable fragen
    if {!$fragen} { return [ueberText] }
    set w .ueber
    destroy $w
    toplevel $w
    wm title $w "Ueber das Adressbuch"
    wm transient $w .
    ttk::frame $w.f -padding 12
    pack $w.f -fill both -expand 1
    set t [text $w.f.t -width 62 -height 16 -wrap none -relief flat \
            -background [ttk::style lookup TFrame -background]]
    pack $t -fill both -expand 1
    $t insert 1.0 [ueberText]
    $t configure -state disabled
    ttk::button $w.f.ok -text Schliessen -command [list destroy $w]
    pack $w.f.ok -side right -pady {10 0}
    bind $w <Escape> [list destroy $w]
    focus $w.f.ok
    return [ueberText]
}

# Eine vorhandene Datei verschluesseln, das Kennwort aendern, oder
# wieder entschluesseln.
# EINE VERSCHLUESSELTE DATEI BEIM START OEFFNEN.
#
# Ohne diesen Weg starb die Anwendung mit einem Tcl-Stapelabzug, bevor
# es ein Fenster gab -- gemeldet 12.09.2026. Wer sein Adressbuch
# verschluesselt hat, kam nicht mehr hinein.
#
# Rueckgabe: 1 wenn offen, 0 wenn der Benutzer abgebrochen hat.
proc ::ab::oeffnenMitKennwort {datei} {
    variable fragen
    if {![catch {adressbuch::oeffnen $datei} e]} { return 1 }
    set grund [lindex $::errorCode 1]
    if {$grund ne "KENNWORT_FEHLT" && $grund ne "KENNWORT_FALSCH"} {
        # Etwas anderes -- nicht nach einem Kennwort fragen, das nicht
        # hilft.
        if {$fragen} {
            tk_messageBox -icon error -title "Datei" -message $e
        } else {
            puts stderr $e
        }
        return 0
    }
    if {!$fragen} { return 0 }

    # Bis zu drei Versuche. Danach hat sich der Benutzer entweder
    # vertippt oder die Datei gehoert ihm nicht.
    for {set i 1} {$i <= 3} {incr i} {
        set kw [kennwortFragen $datei $i]
        if {$kw eq "\u0000ABBRUCH"} { return 0 }
        if {![catch {adressbuch::oeffnen $datei $kw}]} {
            # NICHT MERKEN. Das Kennwort bleibt in keiner Datei.
            set kw ""
            return 1
        }
    }
    tk_messageBox -icon error -title "Kennwort" \
            -message "Dreimal falsch. Die Datei wird nicht geoeffnet."
    return 0
}

proc ::ab::kennwortFragen {datei versuch} {
    set w .kw
    destroy $w
    toplevel $w
    wm title $w "Kennwort"
    set ::ab::kw(wert) ""
    set ::ab::kw(ok) 0
    ttk::frame $w.f -padding 12
    pack $w.f -fill both -expand 1
    set text "Die Datei ist verschluesselt:\n[file tail $datei]"
    if {$versuch > 1} { append text "\n\nVersuch $versuch von 3" }
    ttk::label $w.f.l -text $text -justify left
    pack $w.f.l -anchor w -pady {0 10}
    ttk::entry $w.f.e -width 32 -show * -textvariable ::ab::kw(wert)
    pack $w.f.e -fill x
    ttk::frame $w.f.k
    pack $w.f.k -anchor e -pady {10 0}
    ttk::button $w.f.k.ok -text Oeffnen -command [list set ::ab::kw(ok) 1]
    ttk::button $w.f.k.ab -text Abbrechen -command [list set ::ab::kw(ok) 0]
    pack $w.f.k.ok $w.f.k.ab -side left -padx {6 0}
    bind $w.f.e <Return> [list set ::ab::kw(ok) 1]
    bind $w <Escape> [list set ::ab::kw(ok) 0]
    wm protocol $w WM_DELETE_WINDOW [list set ::ab::kw(ok) 0]
    # Das Hauptfenster gibt es beim Start noch nicht -- also dieses
    # in die Mitte und den Fokus erzwingen.
    wm withdraw .
    update idletasks
    focus -force $w.f.e
    grab set $w
    vwait ::ab::kw(ok)
    catch {grab release $w}
    set ok $::ab::kw(ok)
    set wert $::ab::kw(wert)
    set ::ab::kw(wert) ""
    destroy $w
    if {!$ok} { return "\u0000ABBRUCH" }
    return $wert
}

# DEN ORDNER DER DATEI OEFFNEN.
#
# Damit man an die Sicherungen kommt, ohne den Pfad abzutippen -- sie
# liegen neben der Datei.
#
# Der Befehl ist je nach System ein anderer, und ein fehlender darf
# nicht zum Absturz fuehren: wer kein xdg-open hat, bekommt den Pfad
# genannt und kann ihn selbst benutzen.
proc ::ab::ordnerOeffnen {} {
    variable fragen
    set datei [adressbuch::dateiName]
    if {$datei eq ""} {
        statusMelden "Keine Datei geoeffnet"
        return 0
    }
    set verz [file dirname [file normalize $datei]]
    set befehle {}
    switch -- $::tcl_platform(platform) {
        windows { lappend befehle [list explorer $verz] }
        default {
            if {$::tcl_platform(os) eq "Darwin"} {
                lappend befehle [list open $verz]
            } else {
                lappend befehle [list xdg-open $verz]
                # Wenn xdg-open fehlt: die ueblichen Dateiverwalter.
                foreach fm {nautilus thunar dolphin pcmanfm nemo caja} {
                    lappend befehle [list $fm $verz]
                }
            }
        }
    }
    foreach b $befehle {
        set prog [lindex $b 0]
        if {[auto_execok $prog] eq ""} continue
        if {![catch {exec {*}$b &}]} {
            statusMelden "Ordner geoeffnet: $verz"
            return 1
        }
    }
    statusMelden "Kein Dateiverwalter gefunden -- $verz"
    if {$fragen} {
        tk_messageBox -icon info -title Ordner \
                -message "Es liess sich kein Dateiverwalter starten.\n\nDer\
Ordner ist:\n$verz"
    }
    return 0
}

proc ::ab::verschluesselnDialog {} {
    variable fragen
    if {![adressbuch::kryptoEin]} {
        statusMelden "Verschluesseln ist abgeschaltet"
        if {$fragen} {
            tk_messageBox -icon info -title Verschluesselung \
                    -message "Verschluesseln ist abgeschaltet -- die\
Funktion ist noch nicht fertig.\n\nEine schon verschluesselte Datei\
laesst sich weiter oeffnen und mit \"Verschluesselung aufheben\"\
entschluesseln."
        }
        return 0
    }
    if {![adressbuch::kannVerschluesseln]} {
        statusMelden "Verschluesselung nicht eingerichtet"
        if {$fragen} {
            tk_messageBox -icon warning -title Verschluesselung \
                    -message "SQLite3MultipleCiphers fehlt.\n\nDatei ->\
Verschluesselung einrichten..."
        }
        return 0
    }
    set istVerschl [adressbuch::istVerschluesselt]
    set w .verschl
    destroy $w
    toplevel $w
    wm title $w [expr {$istVerschl ? "Kennwort aendern" : "Datei verschluesseln"}]
    wm transient $w .
    set ::ab::vs(neu) ""
    set ::ab::vs(neu2) ""
    set ::ab::vs(ok) 0

    ttk::frame $w.f -padding 12
    pack $w.f -fill both -expand 1
    set hinweis [expr {$istVerschl
        ? "Die Datei ist verschluesselt.\nLeer lassen heisst ENTSCHLUESSELN."
        : "Die Datei ist NICHT verschluesselt.\nEin Kennwort verschluesselt sie."}]
    ttk::label $w.f.h -text $hinweis -justify left
    grid $w.f.h -row 0 -column 0 -columnspan 2 -sticky w -pady {0 10}
    set r 1
    foreach {feld text} {neu "Neues Kennwort:" neu2 "Wiederholen:"} {
        ttk::label $w.f.l$feld -text $text
        grid $w.f.l$feld -row $r -column 0 -sticky w -padx {0 8} -pady 3
        ttk::entry $w.f.e$feld -width 32 -show * -textvariable ::ab::vs($feld)
        grid $w.f.e$feld -row $r -column 1 -sticky ew -pady 3
        incr r
    }
    grid columnconfigure $w.f 1 -weight 1
    ttk::label $w.f.s -foreground gray40 -justify left \
            -text "Vorher wird eine Sicherung angelegt.\nDas Kennwort wird\
NICHT gespeichert -- vergessen heisst verloren."
    grid $w.f.s -row $r -column 0 -columnspan 2 -sticky w -pady {10 0}
    incr r
    ttk::frame $w.f.k
    grid $w.f.k -row $r -column 0 -columnspan 2 -sticky e -pady {10 0}
    ttk::button $w.f.k.ok -text Anwenden -command [list set ::ab::vs(ok) 1]
    ttk::button $w.f.k.ab -text Abbrechen -command [list set ::ab::vs(ok) 0]
    pack $w.f.k.ok $w.f.k.ab -side left -padx {6 0}
    bind $w <Escape> [list set ::ab::vs(ok) 0]
    wm protocol $w WM_DELETE_WINDOW [list set ::ab::vs(ok) 0]
    focus $w.f.eneu
    if {$fragen} {
        grab set $w
        vwait ::ab::vs(ok)
        catch {grab release $w}
    }
    set gewollt $::ab::vs(ok)
    destroy $w
    if {!$gewollt} { statusMelden "Abgebrochen" ; return 0 }
    return [verschluesselnAusfuehren]
}

proc ::ab::verschluesselnAusfuehren {} {
    variable fragen
    # BEIDE EINGABEN MUESSEN GLEICH SEIN. Ein Tippfehler im Kennwort
    # einer Datei, die danach nur damit zu oeffnen ist, ist nicht mehr
    # zu berichtigen.
    if {$::ab::vs(neu) ne $::ab::vs(neu2)} {
        statusMelden "Die beiden Eingaben sind verschieden"
        if {$fragen} {
            tk_messageBox -icon warning -title Kennwort \
                    -message "Die beiden Eingaben sind verschieden."
        }
        return 0
    }
    if {[catch {adressbuch::verschluesseln $::ab::vs(neu)} kopie]} {
        statusMelden "Fehlgeschlagen: $kopie"
        if {$fragen} {
            tk_messageBox -icon error -title Verschluesselung -message $kopie
        }
        return 0
    }
    set was [expr {$::ab::vs(neu) eq "" ? "entschluesselt" : "verschluesselt"}]
    set ::ab::vs(neu) ""
    set ::ab::vs(neu2) ""
    statusMelden "Datei $was. Sicherung: $kopie"
    if {$fragen} {
        tk_messageBox -icon info -title Verschluesselung \
                -message "Die Datei ist jetzt $was.\n\nSicherung:\n$kopie"
    }
    return 1
}

# Aufheben ist ein eigener Einstieg, kein leeres Feld im
# Verschluesselungsdialog: wer entschluesseln will, sucht nach dem Wort.
proc ::ab::entschluesseln {} {
    variable fragen
    set v [adressbuch::istVerschluesselt]
    if {$v eq ""} {
        statusMelden "Keine Datei geoeffnet"
        return 0
    }
    if {!$v} {
        statusMelden "Die Datei ist nicht verschluesselt"
        if {$fragen} {
            tk_messageBox -icon info -title Verschluesselung \
                    -message "Die Datei ist bereits offen."
        }
        return 0
    }
    if {$fragen} {
        set a [tk_messageBox -type yesno -default no -icon warning \
                -title "Verschluesselung aufheben" \
                -message "Die Verschluesselung wirklich aufheben?\n\nDanach\
liest jeder die Adressen, der die Datei liest.\n\nEine Sicherung wird\
vorher angelegt."]
        if {$a ne "yes"} { statusMelden "Abgebrochen" ; return 0 }
    }
    if {[catch {adressbuch::verschluesseln ""} kopie]} {
        statusMelden "Fehlgeschlagen: $kopie"
        if {$fragen} {
            tk_messageBox -icon error -title Verschluesselung -message $kopie
        }
        return 0
    }
    statusMelden "Verschluesselung aufgehoben. Sicherung: $kopie"
    if {$fragen} {
        tk_messageBox -icon info -title Verschluesselung \
                -message "Die Datei ist jetzt offen.\n\nSicherung:\n$kopie"
    }
    return 1
}

proc ::ab::mcEinrichten {} {
    variable fragen
    if {[adressbuch::kannVerschluesseln]} {
        statusMelden "Verschluesselung ist bereits eingerichtet"
        if {$fragen} {
            tk_messageBox -icon info -title Verschluesselung \
                    -message "Die Verschluesselung ist schon\
eingerichtet.\n\nGeladen aus:\n$::adressbuch::mcDatei"
        }
        return 1
    }
    set f [tk_getOpenFile -title "SQLite3MultipleCiphers auswaehlen" \
            -filetypes {{Bibliothek {.so .dll .dylib}} {Alle *}}]
    if {$f eq ""} return 0
    if {[catch {adressbuch::mcEinrichten $f} ziel]} {
        statusMelden "Nicht eingerichtet: $ziel"
        if {$fragen} {
            tk_messageBox -icon error -title Verschluesselung -message $ziel
        }
        return 0
    }
    statusMelden "Eingerichtet: $ziel"
    if {$fragen} {
        tk_messageBox -icon info -title Verschluesselung \
                -message "Eingerichtet unter:\n$ziel\n\nBeim naechsten\
Start wird sie von selbst gefunden."
    }
    return 1
}

proc ::ab::vcardGeben {} {
    set f [tk_getSaveFile -title "Als vCard sichern" -defaultextension .vcf \
            -filetypes {{vCard {.vcf}} {Alle *}}]
    if {$f eq ""} return
    set n [adressbuch::vcardSchreiben $f]
    statusMelden "$n Karten geschrieben"
}

proc ::ab::csvGeben {} {
    set f [tk_getSaveFile -title "Als CSV sichern" -defaultextension .csv \
            -filetypes {{CSV {.csv}} {Alle *}}]
    if {$f eq ""} return
    set n [adressbuch::csvSchreiben $f]
    statusMelden "$n Zeilen geschrieben"
}

# --- Fenster ---------------------------------------------------------------

proc ::ab::bauen {} {
    wm title . "Adressbuch"
    wm geometry . [abconf::holZahl fenster breite]x[abconf::holZahl fenster hoehe]

    set m [menu .menu -tearoff 0]
    . configure -menu $m
    set d [menu $m.datei -tearoff 0]
    $m add cascade -label Datei -menu $d
    $d add command -label "CSV einlesen..." -command ::ab::csvHolen
    # Wer weiss, woher die Datei kommt, soll es sagen koennen -- die
    # Erkennung ist eine Hilfe, keine Vorschrift.
    set imp [menu $d.import -tearoff 0]
    $d add cascade -label "CSV einlesen als" -menu $imp
    foreach h [adressbuch::herkunft::namen] {
        $imp add command -label $h -command [list ::ab::csvHolen $h]
    }
    $d add separator
    $d add command -label "Von CardDAV holen..." -command ::ab::davDialog
    $d add separator
    # Die Beschriftung richtet sich nach dem Zustand der Datei -- ein
    # Punkt "Datei verschluesseln..." bei einer verschluesselten Datei
    # laesst offen, ob man damit auch das Kennwort aendert.
    $d add command -label "Ordner der Datei oeffnen" -command ::ab::ordnerOeffnen
    $d add separator
    # Verschluesseln ist im Modell abgeschaltet (::adressbuch::kryptoEin).
    # Dann gibt es nur "aufheben" -- fuer Dateien, die schon
    # verschluesselt sind.
    if {[adressbuch::kryptoEin]} {
        $d add command -label "Verschluesseln / Kennwort aendern..." \
                -command ::ab::verschluesselnDialog
    }
    $d add command -label "Verschluesselung aufheben..." \
            -command ::ab::entschluesseln
    if {[adressbuch::kryptoEin]} {
        $d add command -label "Verschluesselung einrichten..." \
                -command ::ab::mcEinrichten
    }
    $d add separator
    $d add command -label "Als CSV sichern..."   -command ::ab::csvGeben
    $d add command -label "Als vCard sichern..." -command ::ab::vcardGeben
    $d add separator
    $d add command -label "Alle Eintraege loeschen..." \
            -command ::ab::allesLoeschen
    $d add separator
    $d add command -label Beenden -command ::ab::beenden
    set h [menu $m.hilfe -tearoff 0]
    $m add cascade -label Hilfe -menu $h
    $h add command -label "Ueber..." -command ::ab::ueber

    ttk::frame .top -padding 6
    pack .top -side top -fill x
    ttk::label .top.l -text Suchen:
    ttk::entry .top.e -textvariable ::ab::suche -width 24
    ttk::button .top.b -text Suchen -command ::ab::suchen
    pack .top.l .top.e .top.b -side left -padx {0 6}
    bind .top.e <Return> ::ab::suchen

    ttk::label .status -textvariable ::ab::status -anchor w -relief sunken
    # Die Statuszeile ZUERST packen, sonst quetscht sie der Rest
    # (serie-tcltk-softwaredesign/14-nicht-sichtbar).
    pack .status -side bottom -fill x

    ttk::frame .knopf -padding 6
    pack .knopf -side bottom -fill x
    foreach {t c} {Neu ::ab::neu Speichern ::ab::speichern
                   Verwerfen ::ab::verwerfen Loeschen ::ab::loeschen} {
        ttk::button .knopf.b$t -text $t -command $c
        pack .knopf.b$t -side left -padx {0 6}
    }

    ttk::panedwindow .pw -orient horizontal
    pack .pw -fill both -expand 1
    ttk::frame .pw.l
    ttk::frame .pw.r -padding 8
    .pw add .pw.l -weight 3
    .pw add .pw.r -weight 2
    listeBauen .pw.l.tbl
    pack .pw.l.tbl -fill both -expand 1
    maskeBauen .pw.r
    # Spaltenbreiten aus den Einstellungen.
    for {set i 0} {$i < 3} {incr i} {
        set b [abconf::holZahl liste spalte$i]
        if {$b > 0} { $::ab::tbl columnconfigure $i -width $b }
    }
    # DEN TEILER ERST SETZEN, WENN ES ETWAS ZU TEILEN GIBT.
    #
    # "after idle" reicht NICHT: gemessen 12.09.2026 stand das
    # panedwindow da noch auf Breite 1, und "sashpos 0 500" rutschte auf
    # 0 -- die Liste war weg, die Tabelle einen Pixel hoch.
    #
    # Also auf das erste <Configure> mit brauchbarer Breite warten und
    # die Bindung danach wieder loesen.
    bind .pw <Configure> [list ::ab::teilerErstesMal \
            [abconf::holZahl fenster teiler]]

    wm protocol . WM_DELETE_WINDOW ::ab::beenden
}

proc ::ab::teilerSetzen {x} {
    if {$x > 0 && [winfo exists .pw]} { catch {.pw sashpos 0 $x} }
}

proc ::ab::teilerErstesMal {x} {
    if {![winfo exists .pw]} return
    # Erst wenn das Fenster wirklich breit ist -- und der Teiler muss
    # hineinpassen, sonst klemmt Tk ihn an den Rand.
    set b [winfo width .pw]
    if {$b < 100} return
    bind .pw <Configure> {}
    if {$x >= $b - 40} { set x [expr {$b / 2}] }
    teilerSetzen $x
}

# WAS DER BENUTZER EINGERICHTET HAT, BEIM BEENDEN MERKEN.
#
# Nicht bei jeder Aenderung schreiben: das gaebe bei jedem Ziehen am
# Teiler einen Schreibvorgang. Einmal beim Beenden reicht.
#
# In "catch", weil ein fehlgeschlagenes Speichern das Beenden nicht
# verhindern darf -- wer keine Schreibrechte mehr hat, soll die
# Anwendung trotzdem zumachen koennen.
proc ::ab::einstellungenMerken {} {
    catch {
        abconf::setz fenster breite [winfo width .]
        abconf::setz fenster hoehe  [winfo height .]
        abconf::setz fenster teiler [.pw sashpos 0]
        for {set i 0} {$i < 3} {incr i} {
            abconf::setz liste spalte$i [$::ab::tbl columncget $i -width]
        }
        abconf::setz allgemein letzte_datei [adressbuch::dateiName]
        abconf::speichern
    }
}

proc ::ab::beenden {} {
    if {![wechselErlaubt]} return
    einstellungenMerken
    adressbuch::schliessen
    exit 0
}

# --- Start -----------------------------------------------------------------

if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    # OHNE ARGUMENT NICHT INS ARBEITSVERZEICHNIS.
    #
    # "adressen.db" legte die Datei dort an, wo man gerade stand -- wer
    # aus dem Projektbaum startete, hatte sie danach darin.
    # ::adressbuch::vorgabeDatei nimmt ADRESSBUCH_DB, sonst
    # XDG_DATA_HOME, sonst ~/.local/share.
    abconf::laden
    # Reihenfolge: Argument, dann zuletzt geoeffnete Datei, dann die
    # Vorgabe. Wer eine Datei nennt, meint sie auch.
    set datei [lindex $argv 0]
    if {$datei eq ""} { set datei [abconf::hol allgemein letzte_datei] }
    if {$datei eq "" || ![file exists $datei]} {
        set datei [::adressbuch::vorgabeDatei]
    }
    # Erst die Datei, dann das Fenster: eine verschluesselte Datei
    # braucht ein Kennwort, und der Dialog dafuer soll vor dem
    # Hauptfenster kommen.
    if {![::ab::oeffnenMitKennwort $datei]} { exit 1 }
    ::ab::bauen
    wm deiconify .
    ::ab::listeFuellen
    ::ab::statusMelden "Datei: [file normalize $datei]"
}
