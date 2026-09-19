# adressbuch-einstellungen.tcl -- laden, speichern, plattformgerecht.
#
# WARUM INI UND NICHT JSON.
#
# Eine Einstellungsdatei soll man mit einem Texteditor aufmachen und
# verstehen koennen. INI kann das, JSON verzeiht kein fehlendes Komma
# und kennt keine Kommentare. Wer seine Fenstergroesse von Hand
# korrigieren will, soll das koennen, ohne den Aufbau zu studieren.
#
# Fuer DATEN waere es andersherum -- da zaehlt Genauigkeit, nicht
# Lesbarkeit. Darum liegen die Adressen in SQLite und die Einstellungen
# hier.
#
# WO SIE LIEGT, je nach Betriebssystem:
#
#   ADRESSBUCH_CONF                    ausdruecklich gesetzt
#   $XDG_CONFIG_HOME/adressbuch/       Linux und BSD
#   ~/Library/Preferences/adressbuch/  macOS
#   %APPDATA%\adressbuch\              Windows
#   ~/.config/adressbuch/              Rueckfall
#
# CONFIG, nicht DATA: das hier sind Einstellungen. Die Adressdatei liegt
# unter XDG_DATA_HOME -- siehe adressbuch-modell.tcl.

package require Tcl 8.6-
package require tclutils::tuini

namespace eval ::abconf {
    variable werte {}       ;# Abschnitt -> Schluessel -> Wert
    variable datei ""
    # Die Vorgaben stehen HIER, nicht verstreut im Code. Wer wissen
    # will, was einstellbar ist, liest diese Liste.
    variable vorgaben {
        fenster {
            breite    860
            hoehe     520
            teiler    500
        }
        liste {
            spalte0   180
            spalte1   140
            spalte2   160
        }
        allgemein {
            letzte_datei  ""
            fragen        1
        }
        dav {
            url       ""
            pfad      ""
            benutzer  ""
        }
    }
}

proc ::abconf::verzeichnis {} {
    if {[info exists ::env(ADRESSBUCH_CONF)] && $::env(ADRESSBUCH_CONF) ne ""} {
        return [file dirname $::env(ADRESSBUCH_CONF)]
    }
    switch -- $::tcl_platform(platform) {
        windows {
            if {[info exists ::env(APPDATA)] && $::env(APPDATA) ne ""} {
                return [file join $::env(APPDATA) adressbuch]
            }
        }
    }
    if {$::tcl_platform(os) eq "Darwin"
            && [info exists ::env(HOME)] && $::env(HOME) ne ""} {
        return [file join $::env(HOME) Library Preferences adressbuch]
    }
    if {[info exists ::env(XDG_CONFIG_HOME)] && $::env(XDG_CONFIG_HOME) ne ""} {
        return [file join $::env(XDG_CONFIG_HOME) adressbuch]
    }
    if {[info exists ::env(HOME)] && $::env(HOME) ne ""} {
        return [file join $::env(HOME) .config adressbuch]
    }
    return [file join [pwd] .adressbuch-conf]
}

proc ::abconf::dateiname {} {
    if {[info exists ::env(ADRESSBUCH_CONF)] && $::env(ADRESSBUCH_CONF) ne ""} {
        return $::env(ADRESSBUCH_CONF)
    }
    return [file join [verzeichnis] adressbuch.conf]
}

# --- Lesen und Schreiben ----------------------------------------------------

# Fehlt die Datei oder ist sie kaputt, gelten die Vorgaben.
#
# EINE UNLESBARE EINSTELLUNGSDATEI DARF DEN START NICHT VERHINDERN.
# Wer sie von Hand bearbeitet hat und dabei etwas zerschossen hat, soll
# die Anwendung noch oeffnen koennen -- sonst kommt er nicht mehr an die
# Stelle, an der er es richten wuerde.
proc ::abconf::laden {{pfad ""}} {
    variable werte
    variable vorgaben
    variable datei
    if {$pfad eq ""} { set pfad [dateiname] }
    set datei $pfad
    set werte $vorgaben
    if {![file readable $pfad]} { return 0 }
    if {[catch {
        set fh [open $pfad r]
        fconfigure $fh -encoding utf-8
        set text [read $fh]
        close $fh
        set gelesen [::tclutils::tuini::parse $text]
    }]} { return 0 }
    # Nur bekannte Schluessel uebernehmen. Ein Tippfehler in der Datei
    # soll nicht als neue Einstellung erscheinen, die nichts tut.
    dict for {abschnitt paare} $gelesen {
        if {![dict exists $vorgaben $abschnitt]} continue
        dict for {k v} $paare {
            if {![dict exists $vorgaben $abschnitt $k]} continue
            dict set werte $abschnitt $k $v
        }
    }
    return 1
}

proc ::abconf::speichern {} {
    variable werte
    variable datei
    if {$datei eq ""} { set datei [dateiname] }
    set verz [file dirname $datei]
    if {![file isdirectory $verz]} {
        if {[catch {file mkdir $verz}]} { return 0 }
        catch {file attributes $verz -permissions 0o700}
    }
    # ERST IN EINE NEBENDATEI, DANN UMBENENNEN.
    #
    # Bricht das Schreiben mittendrin ab -- volle Platte, Stromausfall --
    # steht sonst eine halbe Datei da, und beim naechsten Start gelten
    # weder die alten noch die neuen Einstellungen.
    set neu "$datei.neu"
    if {[catch {
        set fh [open $neu w]
        fconfigure $fh -encoding utf-8
        puts -nonewline $fh [kopfzeile]
        puts -nonewline $fh [::tclutils::tuini::toIni $werte]
        close $fh
        file rename -force $neu $datei
    }]} {
        catch {file delete -force $neu}
        return 0
    }
    catch {file attributes $datei -permissions 0o600}
    return 1
}

proc ::abconf::kopfzeile {} {
    # Keine Zeilenfortsetzung mit Backslash: die bringt fuehrende
    # Leerzeichen in die Datei, und ein " #" ist in INI kein Kommentar
    # mehr.
    return [join {
        "# Einstellungen des Adressbuchs."
        "# Von Hand bearbeitbar. Unbekannte Schluessel werden beim Laden"
        "# uebergangen; fehlende ersetzt die Vorgabe."
        ""
        ""
    } \n]
}

# --- Zugriff ----------------------------------------------------------------

proc ::abconf::hol {abschnitt schluessel} {
    variable werte
    variable vorgaben
    if {[dict exists $werte $abschnitt $schluessel]} {
        return [dict get $werte $abschnitt $schluessel]
    }
    if {[dict exists $vorgaben $abschnitt $schluessel]} {
        return [dict get $vorgaben $abschnitt $schluessel]
    }
    return ""
}

proc ::abconf::setz {abschnitt schluessel wert} {
    variable werte
    dict set werte $abschnitt $schluessel $wert
    return $wert
}

# Eine Zahl, die eine sein muss.
#
# Wer "breite = achthundert" hineinschreibt, bekaeme sonst ein Fenster
# der Groesse 0 und wuesste nicht warum.
proc ::abconf::holZahl {abschnitt schluessel} {
    variable vorgaben
    set v [hol $abschnitt $schluessel]
    if {[string is integer -strict $v]} { return $v }
    if {[dict exists $vorgaben $abschnitt $schluessel]} {
        return [dict get $vorgaben $abschnitt $schluessel]
    }
    return 0
}

proc ::abconf::zuruecksetzen {} {
    variable werte
    variable vorgaben
    set werte $vorgaben
}
