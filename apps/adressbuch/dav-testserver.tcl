# dav-testserver.tcl -- ein winziger CardDAV-Nachbau fuer den Test.
#
# WARUM EIN ECHTER SERVER UND KEINE ATTRAPPE.
#
# Eine nachgebaute "tudav::get"-Prozedur wuerde genau das messen, was
# man selbst hineinschreibt. Der Weg vom PROPFIND ueber die
# Multistatus-Antwort bis zur geholten vCard -- also das, woran es
# scheitern kann -- bliebe ungeprueft.
#
# Dieser Server spricht so viel CardDAV, wie davHolen braucht:
# PROPFIND mit Depth 1 auf die Sammlung, GET auf die einzelnen .vcf.
#
# IM EIGENEN PROZESS STARTEN. Im selben Prozess wartet der Klient in
# seiner Ereignisschleife auf eine Antwort, die der Server erst geben
# kann, wenn dieselbe Schleife ihn drankommen laesst -- gemessen
# 12.09.2026: der Aufruf blieb stehen, ohne Fehlermeldung.
#
#     exec tclsh dav-testserver.tcl PORT VCF-VERZEICHNIS &
#
# Der Server schreibt den Port auf die Standardausgabe und laeuft, bis
# er beendet wird.

package require Tcl 8.6-

namespace eval ::davtest {
    variable kanal ""
    variable port 0
    variable karten {}
    variable basis /adressen/
}

proc ::davtest::setzeKarten {liste} {
    variable karten
    set karten $liste
}

proc ::davtest::start {{wunschPort 0}} {
    variable kanal
    variable port
    set kanal [socket -server ::davtest::_annehmen -myaddr 127.0.0.1 $wunschPort]
    set port [lindex [fconfigure $kanal -sockname] 2]
    return $port
}

proc ::davtest::stop {} {
    variable kanal
    if {$kanal ne ""} { catch {close $kanal} ; set kanal "" }
}

proc ::davtest::_annehmen {sock addr p} {
    fconfigure $sock -translation crlf -blocking 1
    if {[catch {_bedienen $sock}]} {}
    catch {close $sock}
}

proc ::davtest::_bedienen {sock} {
    variable karten
    variable basis
    set anfrage [gets $sock]
    if {$anfrage eq ""} return
    lassign [split $anfrage " "] verb pfad
    set laenge 0
    while {[gets $sock zeile] >= 0 && $zeile ne ""} {
        if {[regexp -nocase {^content-length:\s*(\d+)} $zeile -> n]} {
            set laenge $n
        }
    }
    if {$laenge > 0} {
        fconfigure $sock -translation binary
        read $sock $laenge
        fconfigure $sock -translation crlf
    }

    switch -- $verb {
        PROPFIND { _multistatus $sock }
        GET {
            set name [file tail $pfad]
            if {[dict exists $karten $name]} {
                _antwort $sock 200 "text/vcard; charset=utf-8" \
                        [dict get $karten $name]
            } else {
                _antwort $sock 404 text/plain "nicht da"
            }
        }
        default { _antwort $sock 405 text/plain "nicht unterstuetzt" }
    }
}

proc ::davtest::_multistatus {sock} {
    variable karten
    variable basis
    set x "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
    append x "<D:multistatus xmlns:D=\"DAV:\">\n"
    # Die Sammlung selbst.
    append x "<D:response><D:href>$basis</D:href><D:propstat>"
    append x "<D:prop><D:resourcetype><D:collection/></D:resourcetype>"
    append x "<D:displayname>Adressen</D:displayname></D:prop>"
    append x "<D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>\n"
    dict for {name inhalt} $karten {
        set typ [expr {[string match -nocase *.vcf $name]
                       ? "text/vcard" : "text/plain"}]
        append x "<D:response><D:href>$basis$name</D:href><D:propstat>"
        append x "<D:prop><D:resourcetype/>"
        append x "<D:getcontenttype>$typ</D:getcontenttype>"
        append x "<D:getetag>\"[string length $inhalt]\"</D:getetag>"
        append x "</D:prop><D:status>HTTP/1.1 200 OK</D:status>"
        append x "</D:propstat></D:response>\n"
    }
    append x "</D:multistatus>\n"
    _antwort $sock 207 "application/xml; charset=utf-8" $x
}

proc ::davtest::_antwort {sock code typ inhalt} {
    set b [encoding convertto utf-8 $inhalt]
    puts $sock "HTTP/1.1 $code OK"
    puts $sock "Content-Type: $typ"
    puts $sock "Content-Length: [string length $b]"
    puts $sock "Connection: close"
    puts $sock ""
    flush $sock
    fconfigure $sock -translation binary
    puts -nonewline $sock $b
    flush $sock
}


# --- als eigener Prozess ----------------------------------------------------

if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    set verz [lindex $argv 0]
    set wunsch [expr {[llength $argv] > 1 ? [lindex $argv 1] : 0}]
    set k [dict create]
    # ALLE Dateien anbieten, nicht nur .vcf -- eine echte Sammlung
    # enthaelt auch anderes, und genau daran soll sich zeigen, ob der
    # Klient filtert. Nur .vcf zu listen hiesse, die Pruefung zu
    # umgehen: gemessen 12.09.2026 blieb die Gegenprobe deshalb gruen.
    foreach f [lsort [glob -nocomplain -directory $verz *]] {
        if {[file tail $f] eq "port.txt"} continue
        set fh [open $f r]
        fconfigure $fh -encoding utf-8
        dict set k [file tail $f] [read $fh]
        close $fh
    }
    ::davtest::setzeKarten $k
    set p [::davtest::start $wunsch]
    puts $p
    flush stdout
    vwait forever
}
