# adressbuch/model-0.1.tm -- die Logik, ohne Tk.
#
# ALS PAKET, NICHT ALS source.
#
#     package require adressbuch::model
#
# Das Modell ist fuer sich brauchbar: csvLesen, vcardLesen, davHolen
# und die Ablage arbeiten ohne Oberflaeche. Wer nur Adressen umwandeln
# will, braucht kein Tk.
#
# Der Pfad zu diesem Modul muss in der Modulsuche stehen:
#
#     ::tcl::tm::path add /pfad/lib/tm
#     TCL9_0_TM_PATH=/pfad/lib/tm   (oder TCL8_6_TM_PATH)
#
# Liegt in der Modellschicht: was hier steht, laesst sich ohne Anzeige
# pruefen. Die Oberflaeche kommt in adressbuch.tcl darueber.
#
# Benutzt aus tclutils:
#   tucsv      CSV lesen und schreiben
#   tuvcard    vCard erzeugen und lesen
#   tusqlite   Ablage
#   tuvalidate E-Mail pruefen
#
# Das Datenmodell entspricht dem, was fuer die Mitschueler-Datei
# entstanden ist: Person, Jahre, Mailhistorie -- siehe schema.sql.

package require Tcl 8.6-

# FREMDABHAENGIGKEITEN MIT EINER BRAUCHBAREN MELDUNG.
#
# "can't find package tclutils::tucsv" sagt nicht, WO es liegen muesste.
# Wer das Adressbuch zum ersten Mal auspackt, sucht dann im falschen
# Verzeichnis.
foreach _p {tclutils::tucsv tclutils::tuvcard} {
    if {[catch {package require $_p} _e]} {
        return -code error "Das Paket $_p fehlt.\n\
                Es gehoert zu tclutils. Der Pfad dorthin muss in der\
                Modulsuche stehen:\n\
                  ::tcl::tm::path add /pfad/tclutils/lib/tm\n\
                oder in der Umgebung:\n\
                  TCL9_0_TM_PATH=/pfad/tclutils/lib/tm\n\
                Ursprungsmeldung: $_e"
    }
}
unset -nocomplain _p _e

# VERSCHLUESSELUNG, WENN DER BAU SIE KANN.
#
# SQLite3MultipleCiphers ersetzt die uebliche sqlite3-Anbindung und
# versteht zusaetzlich "PRAGMA key". Liegt sie im Suchpfad oder unter
# ADRESSBUCH_SQLITE3MC, wird sie geladen; sonst die gewoehnliche.
#
# ACHTUNG, GEMESSENE FALLE 12.09.2026:
#
# Die gewoehnliche Anbindung kennt den Unterbefehl "rekey" -- er steht
# in der Fehlerliste und laesst sich AUFRUFEN, OHNE ZU MECKERN. Er
# verschluesselt aber nichts: der Klartext stand danach unveraendert in
# der Datei. Wer sich darauf verlaesst, haelt eine ungeschuetzte Datei
# fuer geschuetzt.
#
# Darum wird NICHT nach dem Befehl gefragt, sondern GEMESSEN, ob die
# Datei hinterher verschluesselt ist -- siehe kannVerschluesseln.
# WO DIE BIBLIOTHEK GESUCHT WIRD, in dieser Reihenfolge:
#
#   1. $ADRESSBUCH_SQLITE3MC          ausdruecklich genannt
#   2. dist/<plattform>/tcl<fassung>/ neben dieser Datei
#   3. die gewoehnliche sqlite3       ohne Verschluesselung
#
# Der Zweig 2 ist der Grund fuer den dist-Aufbau: eine .so passt nur zu
# EINER Tcl-Fassung und EINEM Betriebssystem. Gemessen 12.09.2026: gegen
# Tcl 8.6 gebaut, laedt sie unter 9.0 nicht -- sie uebersetzt sauber und
# scheitert erst beim Laden. Also getrennt ablegen und die passende
# nehmen, statt eine fuer alle zu hoffen.
namespace eval ::adressbuch {
    # VERSCHLUESSELN IST ABGESCHALTET (Stand 2026-09-19).
    #
    # Die Funktion ist noch nicht fertig (siehe LIESMICH, "Offen und
    # ungemessen"). Solange steht hier 0: keine Datei wird verschluesselt,
    # kein Kennwort gesetzt oder geaendert. Einschalten NUR durch Aendern
    # dieser Zeile auf 1 -- bewusst kein Umgebungsschalter, keine
    # Einstellung, und nicht schon deshalb, weil SQLite3MultipleCiphers
    # gefunden wird.
    #
    # Was trotzdem immer geht: eine VORHANDENE verschluesselte Datei mit
    # Kennwort oeffnen und ihre Verschluesselung AUFHEBEN. Sonst saesse
    # jeder, der schon verschluesselt hat, vor seiner eigenen Datei.
    variable kryptoEin 0
}

# kryptoEin -- 1, wenn Verschluesseln im Code eingeschaltet ist.
proc ::adressbuch::kryptoEin {} {
    variable kryptoEin
    return [expr {$kryptoEin ? 1 : 0}]
}

proc ::adressbuch::_kryptoAus {was} {
    return -code error -errorcode {ADRESSBUCH KRYPTO_AUS} \
        "$was: Verschluesseln ist abgeschaltet (Funktion unfertig).\
        Einschalten nur im Code: ::adressbuch::kryptoEin in\
        lib/tm/adressbuch/model-0.1.tm auf 1 setzen."
}

proc ::adressbuch::_mcPfade {} {
    # ACHTUNG BEIM UMZUG INS PAKET: "info script" zeigt jetzt auf
    # lib/tm/adressbuch/model-0.1.tm, nicht mehr auf die Anwendung.
    # "dist neben dieser Datei" hiesse also lib/tm/adressbuch/dist --
    # dort liegt nichts.
    #
    # Darum ZWEI Wurzeln: das Modulverzeichnis und die Anwendung drei
    # Ebenen darueber (lib/tm/adressbuch -> Anwendung).
    set hier [file dirname [file normalize [info script]]]
    set wurzeln [list $hier [file normalize [file join $hier .. .. ..]]]
    set fassung [join [lrange [split [info tclversion] .] 0 1] .]
    switch -- $::tcl_platform(platform) {
        windows { set plattform win ; set endung .dll }
        default {
            set endung .so
            set plattform [expr {$::tcl_platform(os) eq "Darwin" ? "mac" : "linux"}]
            if {$plattform eq "mac"} { set endung .dylib }
        }
    }
    set namen [list "libsqlite3mc$endung" "sqlite3mc$endung"]
    set pfade {}
    # 1. Neben der Anwendung -- so kommt sie aus dem Paket.
    foreach w $wurzeln {
        foreach n $namen {
            lappend pfade [file join $w dist $plattform tcl$fassung $n]
            lappend pfade [file join $w .. dist $plattform tcl$fassung $n]
        }
    }
    # 2. Im Datenverzeichnis des Benutzers -- dorthin legt sie
    #    "mcEinrichten". Damit gilt sie fuer JEDEN Start, auch wenn die
    #    Anwendung anderswo liegt oder neu ausgepackt wird.
    # datenVerzeichnis steht weiter unten in der Datei -- beim Laden
    # ist sie noch nicht da, denn _mcLaden laeuft ganz oben. Also
    # nachsehen statt blind rufen.
    if {[llength [info procs ::adressbuch::datenVerzeichnis]]} {
        foreach n $namen {
            lappend pfade [file join [datenVerzeichnis] dist $plattform \
                    tcl$fassung $n]
        }
    }
    return $pfade
}

# EINMAL EINRICHTEN STATT JEDESMAL SETZEN.
#
#     adressbuch::mcEinrichten /pfad/libsqlite3mc.so
#
# Kopiert die Bibliothek an die Stelle, an der das Adressbuch sie beim
# naechsten Start von selbst findet -- nach Betriebssystem und
# Tcl-Fassung einsortiert.
#
# Warum kopieren und nicht den Pfad merken: ein gemerkter Pfad zeigt
# irgendwann ins Leere (Quellbaum aufgeraeumt, Verzeichnis umbenannt),
# und der Fehler faellt erst auf, wenn man ein Kennwort eingibt.
proc ::adressbuch::mcEinrichten {quelle} {
    if {![file readable $quelle]} {
        error "nicht lesbar: $quelle"
    }
    # ERST PRUEFEN, OB SIE TAUGT -- eine unbrauchbare Bibliothek
    # einzusortieren hiesse, den Fehler nur zu verschieben.
    set eigen [info nameofexecutable]
    set pruef [list [file normalize $quelle]]
    if {[catch {
        set i [interp create]
        $i eval [list load [file normalize $quelle] Sqlite3]
        # NICHT :memory: -- dort ist "PRAGMA key" nicht unterstuetzt
        # ("Setting key not supported for in-memory or temporary
        # databases"), und die Pruefung schluege faelschlich fehl.
        set probe [file join [_tempVerzeichnis] \
                "mc-einricht-[pid]-[clock clicks].db"]
        $i eval [list sqlite3 p $probe]
        $i eval {p eval {PRAGMA key = 'x'}}
        $i eval {p eval {CREATE TABLE t(a)}}
        $i eval {p close}
        file delete -force $probe
        interp delete $i
    } e]} {
        catch {interp delete $i}
        error "laedt nicht in dieses Tcl ([info patchlevel]): $e"
    }

    set alle [_mcPfade]
    set ziel ""
    foreach kand $alle {
        # Die Kandidaten aus dem Datenverzeichnis erkennen.
        if {[string match "[datenVerzeichnis]*" $kand]} { set ziel $kand ; break }
    }
    if {$ziel eq ""} { set ziel [lindex $alle end] }
    file mkdir [file dirname $ziel]
    file copy -force $quelle $ziel
    return $ziel
}

proc ::adressbuch::_mcLaden {} {
    # 0. ALS PAKET, wenn es schon im Suchpfad steht.
    #
    # sqlite3mc ist eine eigenstaendige Bibliothek mit eigenem Baum und
    # eigenen Tests. Wer sie hat, soll sie benutzen koennen, ohne dass
    # eine Kopie im Adressbuch liegt -- zwei Kopien derselben Datei
    # driften auseinander, und man erwischt die falsche.
    if {![catch {package require sqlite3mc}]} {
        return "package:sqlite3mc"
    }
    if {[info exists ::env(ADRESSBUCH_SQLITE3MC)]
            && $::env(ADRESSBUCH_SQLITE3MC) ne ""} {
        # Ausdruecklich genannt: ein Fehlschlag ist HIER einer. Wer den
        # Pfad angibt, will diese Bibliothek und keine andere.
        load $::env(ADRESSBUCH_SQLITE3MC) Sqlite3
        return $::env(ADRESSBUCH_SQLITE3MC)
    }
    foreach f [_mcPfade] {
        if {![file readable $f]} continue
        if {![catch {load $f Sqlite3}]} { return $f }
        # Gefunden, aber nicht ladbar -- meist die falsche Tcl-Fassung.
        # Weitersuchen statt abbrechen.
    }
    package require sqlite3
    return ""
}

# GELADEN WIRD AM ENDE DIESER DATEI.
#
# _mcPfade sieht auch im Datenverzeichnis nach, und dafuer braucht es
# datenVerzeichnis -- die weiter unten steht. Hier oben zu laden hiesse,
# diesen Pfad stillschweigend zu ueberspringen. Gemessen: eine
# eingerichtete Bibliothek wurde nicht gefunden.
#
# Gebraucht wird sqlite3 ohnehin erst beim Oeffnen, nicht beim Laden.

namespace eval ::adressbuch {
    variable db ""
    variable dateiname ""
}

# --- Wo die Datei liegt ----------------------------------------------------

# DATEN GEHOEREN NICHT INS ARBEITSVERZEICHNIS.
#
# Eine Vorgabe wie "adressen.db" legt die Datei dort an, wo man gerade
# steht. Wer die Anwendung aus dem Projektbaum startet, hat sie danach
# darin -- und "git add -A" nimmt sie mit. Gemessen an pdf4tcl am
# 09.09.2026: acht Demos, dreizehn Dateien im Baum.
#
# Reihenfolge: ADRESSBUCH_DB, sonst XDG_DATA_HOME, sonst ~/.local/share,
# sonst %APPDATA%. DATA, nicht CONFIG -- das hier sind Daten, keine
# Einstellungen.
proc ::adressbuch::vorgabeDatei {} {
    if {[info exists ::env(ADRESSBUCH_DB)] && $::env(ADRESSBUCH_DB) ne ""} {
        return $::env(ADRESSBUCH_DB)
    }
    return [file join [datenVerzeichnis] adressen.db]
}

proc ::adressbuch::datenVerzeichnis {} {
    if {[info exists ::env(XDG_DATA_HOME)] && $::env(XDG_DATA_HOME) ne ""} {
        set basis $::env(XDG_DATA_HOME)
    } elseif {[info exists ::env(HOME)] && $::env(HOME) ne ""} {
        set basis [file join $::env(HOME) .local share]
    } elseif {[info exists ::env(APPDATA)] && $::env(APPDATA) ne ""} {
        set basis $::env(APPDATA)
    } else {
        # Letzter Ausweg. Besser als das Arbeitsverzeichnis, weil
        # wenigstens erkennbar.
        set basis [file join [pwd] .adressbuch-daten]
    }
    return [file join $basis adressbuch]
}

# --- Ablage ----------------------------------------------------------------

# KANN DIESER BAU WIRKLICH VERSCHLUESSELN?
#
# Nicht am Befehl erkennbar, sondern nur an der Datei: eine Probe
# anlegen, einen erkennbaren Text hineinschreiben, und nachsehen, ob er
# noch lesbar darin steht.
#
# Das Ergebnis wird gemerkt -- die Probe kostet eine Datei und soll
# nicht bei jedem Oeffnen laufen.
proc ::adressbuch::kannVerschluesseln {} {
    variable verschluesselbar
    if {[info exists verschluesselbar]} { return $verschluesselbar }
    set verschluesselbar 0
    set probe [file join [_tempVerzeichnis] \
            "adressbuch-probe-[pid]-[clock clicks].db"]
    catch {
        file delete -force $probe
        sqlite3 ::adressbuch::PROBE $probe
        ::adressbuch::PROBE eval {PRAGMA key = 'probe'}
        ::adressbuch::PROBE eval {CREATE TABLE p(a TEXT)}
        ::adressbuch::PROBE eval {INSERT INTO p VALUES('KLARTEXTPROBE')}
        ::adressbuch::PROBE close
        set fh [open $probe rb]
        set inhalt [read $fh]
        close $fh
        if {![string match *KLARTEXTPROBE* $inhalt]} {
            set verschluesselbar 1
        }
    }
    catch {::adressbuch::PROBE close}
    catch {file delete -force $probe}
    return $verschluesselbar
}

proc ::adressbuch::_tempVerzeichnis {} {
    foreach v {TMPDIR TEMP TMP} {
        if {[info exists ::env($v)] && [file isdirectory $::env($v)]} {
            return $::env($v)
        }
    }
    if {[file isdirectory /tmp]} { return /tmp }
    return [pwd]
}

proc ::adressbuch::oeffnen {datei {kennwort ""}} {
    variable db
    if {$db ne ""} { schliessen }
    # Das Verzeichnis anlegen, bevor SQLite es vermisst -- sonst kommt
    # "unable to open database file" ohne Hinweis worauf.
    set verz [file dirname [file normalize $datei]]
    if {![file isdirectory $verz]} {
        file mkdir $verz
        catch {file attributes $verz -permissions 0o700}
    }
    set neu [expr {![file exists $datei]}]
    # Eine NEUE Datei mit Kennwort wuerde verschluesselt angelegt -- das
    # ist Verschluesseln und bei abgeschalteter Funktion gesperrt. Eine
    # vorhandene verschluesselte Datei zu oeffnen bleibt erlaubt.
    if {$kennwort ne "" && $neu && ![kryptoEin]} {
        _kryptoAus "Neue Datei mit Kennwort"
    }
    set ::adressbuch::dateiname [file normalize $datei]
    sqlite3 ::adressbuch::DB $datei
    if {$kennwort ne ""} {
        if {![kannVerschluesseln]} {
            catch {::adressbuch::DB close}
            error "Diese sqlite3-Anbindung kann nicht verschluesseln.\
                    Mit SQLite3MultipleCiphers bauen und ueber\
                    ADRESSBUCH_SQLITE3MC laden."
        }
        # PRAGMA nimmt KEINE gebundenen Werte -- ":kennwort" ist dort
        # ein Syntaxfehler, kein Platzhalter. Also einsetzen, und dabei
        # einfache Anfuehrungszeichen im Kennwort verdoppeln, sonst
        # bricht ein Apostroph die Anweisung auf.
        set q [string map {' ''} $kennwort]
        ::adressbuch::DB eval "PRAGMA key = '$q'"
        # NACHSEHEN, OB DER SCHLUESSEL STIMMT. Ein falsches Kennwort
        # faellt sonst erst beim ersten Lesen auf -- und sieht dann aus
        # wie eine kaputte Datei.
        if {[catch {::adressbuch::DB eval {SELECT count(*) FROM sqlite_master}}]} {
            catch {::adressbuch::DB close}
            error "Falsches Kennwort oder keine Adressbuchdatei: $datei"
        }
    }
    set db ::adressbuch::DB
    $db eval {PRAGMA foreign_keys = ON}
    # PRUEFEN, OB DIE DATEI UEBERHAUPT ZU LESEN IST -- bevor das erste
    # CREATE TABLE mit "file is not a database" abbricht.
    #
    # Gemeldet 12.09.2026: eine verschluesselte Datei ohne Kennwort zu
    # oeffnen ergab einen Tcl-Stapelabzug beim Start, aus dem niemand
    # ablesen konnte, dass ein Kennwort fehlt.
    if {[catch {$db eval {SELECT count(*) FROM sqlite_master}}]} {
        catch {$db close}
        set ::adressbuch::db ""
        set ::adressbuch::dateiname ""
        if {[istVerschluesselt $datei]} {
            if {$kennwort eq ""} {
                return -code error -errorcode {ADRESSBUCH KENNWORT_FEHLT} \
                        "Die Datei ist verschluesselt: $datei\nEs wird ein\
                        Kennwort gebraucht."
            }
            return -code error -errorcode {ADRESSBUCH KENNWORT_FALSCH} \
                    "Falsches Kennwort fuer: $datei"
        }
        return -code error -errorcode {ADRESSBUCH KEINE_DATENBANK} \
                "Keine SQLite-Datei: $datei"
    }
    $db eval {
        CREATE TABLE IF NOT EXISTS person (
            id       INTEGER PRIMARY KEY,
            vorname  TEXT NOT NULL DEFAULT '',
            name     TEXT NOT NULL DEFAULT '',
            strasse  TEXT NOT NULL DEFAULT '',
            nummer   TEXT NOT NULL DEFAULT '',
            plz      TEXT NOT NULL DEFAULT '',
            ort      TEXT NOT NULL DEFAULT '',
            telefon  TEXT NOT NULL DEFAULT '',
            mobil    TEXT NOT NULL DEFAULT '',
            email    TEXT NOT NULL DEFAULT '',
            email2   TEXT NOT NULL DEFAULT '',
            notiz    TEXT NOT NULL DEFAULT ''
        )
    }
    $db eval {CREATE INDEX IF NOT EXISTS i_person_name ON person(name, vorname)}
    # ANSCHRIFTEN UND TELEFONNUMMERN VON DRITTEN.
    #
    # Nur der Eigentuemer soll lesen koennen -- dieselbe Regel, die
    # sqledit-conn.tcl fuer Verbindungsprofile anwendet. Nur bei einer
    # NEU angelegten Datei setzen: wer die Rechte absichtlich geaendert
    # hat, soll das behalten duerfen.
    if {$neu} { catch {file attributes $datei -permissions 0o600} }
    _schemaPruefen
    return $db
}

# DIE FASSUNG DES SCHEMAS STEHT IN DER DATEI.
#
# Ohne sie weiss eine spaetere Fassung der Anwendung nicht, ob die Datei
# schon eine neue Spalte hat -- und "ALTER TABLE ADD COLUMN" ein zweites
# Mal ist ein Fehler. PRAGMA user_version kostet nichts und ist von
# Anfang an da; nachtraeglich einzufuehren heisst raten, welchen Stand
# eine vorhandene Datei hat.
#
# serie-tablelist-datenbank/12-schema
proc ::adressbuch::_schemaPruefen {} {
    variable db
    set v [$db onecolumn {PRAGMA user_version}]
    if {$v == 0} {
        $db eval {PRAGMA user_version = 1}
        set v 1
    }
    # Fassung 2: die UID aus der vCard.
    #
    # Ohne sie ist jedes Holen ein Anlegen -- zweimal geholt, alles
    # doppelt. Gemessen 12.09.2026: aus 2 Datensaetzen wurden 4.
    #
    # Und HIER zahlt sich user_version aus: eine Datei aus Fassung 1
    # bekommt die Spalte nachtraeglich, eine neue hat sie gleich, und
    # ein zweiter Lauf macht nichts doppelt.
    if {$v < 2} {
        $db eval {ALTER TABLE person ADD COLUMN uid TEXT NOT NULL DEFAULT ''}
        $db eval {CREATE UNIQUE INDEX IF NOT EXISTS i_person_uid
                  ON person(uid) WHERE uid <> ''}
        $db eval {PRAGMA user_version = 2}
        set v 2
    }
    return $v
}

proc ::adressbuch::schemaFassung {} {
    variable db
    return [$db onecolumn {PRAGMA user_version}]
}

proc ::adressbuch::schliessen {} {
    variable db
    variable dateiname
    if {$db ne ""} { $db close ; set db "" }
    set dateiname ""
}

proc ::adressbuch::felder {} {
    return {vorname name strasse nummer plz ort telefon mobil email email2 notiz}
}

# Die UID gehoert NICHT in "felder": sie ist keine Angabe ueber die
# Person, sondern die Kennung des Datensatzes beim Server. In der Maske
# hat sie nichts zu suchen, und wer sie von Hand aendert, zerbricht den
# Abgleich.
proc ::adressbuch::uidVon {id} {
    variable db
    return [$db onecolumn {SELECT uid FROM person WHERE id = $id}]
}

proc ::adressbuch::idZuUid {uid} {
    variable db
    if {$uid eq ""} { return "" }
    return [$db onecolumn {SELECT id FROM person WHERE uid = $uid}]
}

proc ::adressbuch::alle {{muster ""}} {
    variable db
    if {$muster eq ""} {
        return [$db eval {SELECT id FROM person ORDER BY name, vorname}]
    }
    # Suche ueber ALLE Felder, nicht nur den Namen. Wer eine Nummer im
    # Kopf hat, sucht danach.
    set m "%[string tolower $muster]%"
    return [$db eval {
        SELECT id FROM person
        WHERE lower(vorname||' '||name||' '||ort||' '||plz||' '||telefon
                   ||' '||mobil||' '||email||' '||email2||' '||notiz) LIKE $m
        ORDER BY name, vorname
    }]
}

proc ::adressbuch::lesen {id} {
    variable db
    set aus [dict create id $id]
    $db eval {SELECT * FROM person WHERE id = $id} r {
        foreach f [felder] { dict set aus $f $r($f) }
    }
    return $aus
}

# Neu oder aendern -- der Aufrufer muss nicht wissen, welches.
proc ::adressbuch::schreiben {id werte} {
    if {$id eq "" || $id == 0} { return [_einfuegen $werte] }
    return [_aendern $id $werte]
}

proc ::adressbuch::_einfuegen {werte} {
    variable db
    foreach f [felder] {
        set v($f) [expr {[dict exists $werte $f] ? [dict get $werte $f] : ""}]
    }
    set uid [expr {[dict exists $werte uid] ? [dict get $werte uid] : ""}]
    $db eval {
        INSERT INTO person (vorname,name,strasse,nummer,plz,ort,
                            telefon,mobil,email,email2,notiz,uid)
        VALUES ($v(vorname),$v(name),$v(strasse),$v(nummer),$v(plz),$v(ort),
                $v(telefon),$v(mobil),$v(email),$v(email2),$v(notiz),$uid)
    }
    return [$db last_insert_rowid]
}

proc ::adressbuch::_aendern {id werte} {
    variable db
    foreach f [felder] {
        set v($f) [expr {[dict exists $werte $f] ? [dict get $werte $f] : ""}]
    }
    # Die UID bleibt, wie sie ist -- sie kommt vom Server, nicht aus der
    # Maske. Ein Speichern aus der Oberflaeche darf sie nicht loeschen.
    $db eval {
        UPDATE person SET vorname=$v(vorname), name=$v(name),
            strasse=$v(strasse), nummer=$v(nummer), plz=$v(plz), ort=$v(ort),
            telefon=$v(telefon), mobil=$v(mobil), email=$v(email),
            email2=$v(email2), notiz=$v(notiz)
        WHERE id=$id
    }
    return $id
}

# EINE VORHANDENE DATEI VERSCHLUESSELN -- oder das Kennwort aendern.
#
#     adressbuch::verschluesseln geheim        offen  -> verschluesselt
#     adressbuch::verschluesseln neu           altes Kennwort -> neues
#     adressbuch::verschluesseln ""            verschluesselt -> offen
#
# "PRAGMA rekey" arbeitet an Ort und Stelle: die Datei wird umgeschrieben,
# nicht kopiert. Gemessen 12.09.2026: sieben Eintraege, danach kein
# Klartext mehr in der Datei.
#
# VORHER WIRD GESICHERT. Ein Abbruch mitten im Umschreiben -- volle
# Platte, Stromausfall -- liesse sonst eine Datei zurueck, die weder mit
# altem noch mit neuem Schluessel zu oeffnen ist.
proc ::adressbuch::verschluesseln {kennwort} {
    variable db
    variable dateiname
    if {$db eq ""} { error "keine Datei geoeffnet" }
    # Ein leeres Kennwort hebt die Verschluesselung auf -- das geht immer.
    # Ein Kennwort setzen oder aendern nur, wenn im Code eingeschaltet.
    if {$kennwort ne "" && ![kryptoEin]} {
        _kryptoAus "Verschluesseln"
    }
    if {![kannVerschluesseln]} {
        error "Diese sqlite3-Anbindung kann nicht verschluesseln.\
                Siehe BAUEN-sqlite3mc.md."
    }
    set kopie ""
    if {$dateiname ne "" && [file exists $dateiname]} {
        set marke [clock format [clock seconds] -format %Y%m%d-%H%M%S]
        set kopie "$dateiname.$marke.vor-verschluesselung"
        file copy -force $dateiname $kopie
        if {![file exists $kopie]} { error "Sicherung nicht angelegt: $kopie" }
        catch {file attributes $kopie -permissions 0o600}
    }
    # Einfache Anfuehrungszeichen verdoppeln -- PRAGMA nimmt keine
    # gebundenen Werte.
    set q [string map {' ''} $kennwort]
    if {[catch {$db eval "PRAGMA rekey = '$q'"} e]} {
        error "Umschluesseln fehlgeschlagen: $e\nDie Sicherung liegt unter $kopie"
    }
    return $kopie
}

proc ::adressbuch::loeschen {id} {
    variable db
    $db eval {DELETE FROM person WHERE id=$id}
}

# ALLES LOESCHEN -- mit Sicherungskopie, nicht ohne.
#
# Eine Anwendung, die alles wegwerfen kann, muss auch einen Weg zurueck
# anbieten. Die Kopie kostet nichts (SQLite-Datei kopieren) und ist das
# einzige, was nach einem Fehlgriff noch hilft.
#
# Rueckgabe: der Pfad der Sicherung, damit der Aufrufer ihn nennen kann.
# Wer eine Sicherung anlegt und nicht sagt wo, hat keine angelegt.
proc ::adressbuch::allesLoeschen {} {
    variable db
    variable dateiname
    set kopie ""
    if {$dateiname ne "" && [file exists $dateiname]} {
        set marke [clock format [clock seconds] -format %Y%m%d-%H%M%S]
        set kopie "$dateiname.$marke.sicherung"
        # VOR dem Loeschen kopieren, und die Kopie erst dann als
        # gelungen betrachten, wenn sie wirklich dasteht.
        file copy -force $dateiname $kopie
        if {![file exists $kopie]} {
            error "Sicherung nicht angelegt: $kopie"
        }
        catch {file attributes $kopie -permissions 0o600}
    }
    # Nur leeren, was es gibt: das Schema der Mitschueler-Datei hat
    # Nebentabellen, dieses hier noch nicht. Ein hartes DELETE auf eine
    # fehlende Tabelle bricht mitten im Loeschen ab -- und laesst die
    # Haelfte stehen.
    $db transaction {
        foreach t {mailhistorie jahr person} {
            if {[$db onecolumn {SELECT count(*) FROM sqlite_master
                                WHERE type='table' AND name=$t}]} {
                $db eval "DELETE FROM $t"
            }
        }
    }
    # Den freigewordenen Platz zurueckgeben -- sonst steht die Datei
    # weiter mit voller Groesse da, und wer sie weitergibt, gibt die
    # geloeschten Seiten mit.
    $db eval {VACUUM}
    return $kopie
}

# IST DIESE DATEI VERSCHLUESSELT?
#
# Am Dateikopf erkennbar, nicht am Programmzustand: eine unverschluessel-
# te SQLite-Datei beginnt mit "SQLite format 3\0". Fehlt das, ist der
# Anfang verschluesselt.
#
# Warum nicht merken, ob ein Kennwort uebergeben wurde: das sagt, was
# man VORHATTE, nicht was in der Datei steht. Wer eine alte
# unverschluesselte Datei mit Kennwort oeffnet, bekaeme sonst "ja"
# angezeigt -- und die Datei waere offen.
proc ::adressbuch::istVerschluesselt {{datei ""}} {
    variable dateiname
    if {$datei eq ""} { set datei $dateiname }
    if {$datei eq "" || ![file readable $datei]} { return "" }
    if {[file size $datei] < 16} { return "" }
    if {[catch {
        set fh [open $datei rb]
        set kopf [read $fh 16]
        close $fh
    }]} { return "" }
    return [expr {![string match "SQLite format 3*" $kopf]}]
}

# Was die Anwendung ueber sich selbst weiss -- fuer Statuszeile und
# "Ueber".
proc ::adressbuch::auskunft {} {
    variable mcDatei
    variable dateiname
    set d [dict create]
    dict set d tcl        [info patchlevel]
    dict set d sqlite     [expr {[info commands sqlite3] ne "" ? [_sqliteVersion] : "?"}]
    dict set d mcDatei    $mcDatei
    dict set d mcAktiv    [kannVerschluesseln]
    dict set d kryptoEin  [kryptoEin]
    dict set d datei      $dateiname
    dict set d verschluesselt [istVerschluesselt]
    dict set d schema     [expr {$dateiname ne "" ? [schemaFassung] : ""}]
    dict set d eintraege  [expr {$dateiname ne "" ? [llength [alle]] : ""}]
    return $d
}

proc ::adressbuch::_sqliteVersion {} {
    variable db
    if {$db ne ""} { return [$db version] }
    if {[catch {
        sqlite3 ::adressbuch::VER :memory:
        set v [::adressbuch::VER version]
        ::adressbuch::VER close
    }]} { return "?" }
    return $v
}

proc ::adressbuch::dateiName {} {
    variable dateiname
    return $dateiname
}

# --- Herkunft einer CSV-Datei ----------------------------------------------
#
# Jedes Programm nennt seine Spalten anders. Statt zu raten, gibt es
# benannte Zuordnungen -- und eine Erkennung, die die Kopfzeile
# befragt.
#
# GEMESSENE BESONDERHEIT: Thunderbird schreibt beim CSV-Export NUR
# WERTE, ohne Kopfzeile. Outlook schreibt eine. Wer bei Thunderbird eine
# Kopfzeile erwartet, verliert den ersten Eintrag und ordnet alles
# falsch zu.
namespace eval ::adressbuch::herkunft {}

# Zuordnung: Quellspalte (klein geschrieben) -> eigenes Feld.
# Was hier nicht steht, wandert in "notiz".
set ::adressbuch::herkunft::zuordnung(eigen) {
    vorname vorname  name name  strasse strasse  nummer nummer
    plz plz  ort ort  telefon telefon  mobil mobil
    email email  email2 email2  notiz notiz
}

set ::adressbuch::herkunft::zuordnung(thunderbird) {
    {first name}      vorname
    {last name}       name
    {primary email}   email
    {secondary email} email2
    {home phone}      telefon
    {mobile number}   mobil
    {work phone}      telefon
    {home address}    strasse
    {home city}       ort
    {home post code}  plz
    {home zipcode}    plz
    {display name}    notiz
    {organization}    notiz
}

set ::adressbuch::herkunft::zuordnung(outlook) {
    {first name}        vorname
    {last name}         name
    {e-mail address}    email
    {e-mail 2 address}  email2
    {home phone}        telefon
    {mobile phone}      mobil
    {business phone}    telefon
    {home street}       strasse
    {home city}         ort
    {home postal code}  plz
    {company}           notiz
}

# Die Spaltenfolge des kopflosen Thunderbird-Exports.
#
# Steht so in der Thunderbird-Dokumentation und ist die einzige
# Moeglichkeit, eine Datei ohne Kopfzeile zu deuten. Wer eine andere
# Reihenfolge hat, nimmt eine eigene Zuordnung.
set ::adressbuch::herkunft::spaltenfolge(thunderbird) {
    vorname name notiz notiz email email2 - telefon - - -
    mobil strasse - ort - plz - - - - - - - notiz
}

proc ::adressbuch::herkunft::namen {} {
    variable zuordnung
    return [lsort [array names zuordnung]]
}

# Welche Herkunft passt zu dieser Kopfzeile?
#
# Gezaehlt wird, wie viele Spalten eine Zuordnung wiedererkennt -- die
# mit den meisten Treffern gewinnt. Bei null Treffern ist es keine
# bekannte Herkunft.
proc ::adressbuch::herkunft::erkennen {kopf} {
    variable zuordnung
    set beste ""
    set bestzahl 0
    foreach h [namen] {
        set z [dict create {*}$zuordnung($h)]
        set n 0
        foreach k $kopf {
            if {[dict exists $z [string tolower [string trim $k]]]} { incr n }
        }
        if {$n > $bestzahl} { set bestzahl $n ; set beste $h }
    }
    return $beste
}

# Hat die Datei ueberhaupt eine Kopfzeile?
#
# Eine Kopfzeile enthaelt keine E-Mail-Adresse und keine Ziffernfolge,
# die wie eine Rufnummer aussieht. Das ist eine Faustregel, keine
# Gewissheit -- darum laesst sich die Antwort ueberschreiben.
proc ::adressbuch::herkunft::hatKopfzeile {zeile} {
    foreach f $zeile {
        if {[string match *@*.* $f]} { return 0 }
        if {[regexp {^[0-9][0-9/ ()-]{4,}$} [string trim $f]]} { return 0 }
    }
    return 1
}

# --- CSV -------------------------------------------------------------------

# Einlesen ueber die KOPFZEILE, nicht ueber Spaltennummern. Wer eine
# Spalte einfuegt, verschiebt sonst alles dahinter, und es faellt erst
# auf, wenn Telefonnummern im Ortsfeld stehen.
#
# Unbekannte Spalten wandern gesammelt in "notiz", statt verworfen zu
# werden -- was in der Datei stand, soll nicht stillschweigend weg sein.
# Einlesen mit Zuordnung.
#
#   -herkunft  eigen | thunderbird | outlook | auto (Vorgabe)
#   -kopfzeile 1 | 0 | auto (Vorgabe)
#   -felder    Liste eigener Feldnamen, ueberschreibt alles
#
# Unbekannte Spalten wandern gesammelt in "notiz", statt verlorenzugehen.
proc ::adressbuch::csvLesen {datei args} {
    variable db
    set opt [dict create -herkunft auto -kopfzeile auto -felder {}]
    dict for {k v} $args {
        if {![dict exists $opt $k]} { error "unbekannte Option: $k" }
        dict set opt $k $v
    }

    set ch [open $datei r]
    fconfigure $ch -encoding utf-8
    set text [read $ch]
    close $ch
    set rows [::tclutils::tucsv::parse $text]
    if {![llength $rows]} { return 0 }

    lassign [_deutung $rows $opt] felder datenZeilen kopf
    if {![llength $felder]} { return 0 }

    set n 0
    # Eine Transaktion um den ganzen Vorgang: ohne sie steht nach einem
    # Fehler in Zeile 300 die Haelfte in der Datei.
    $db transaction {
        foreach zeile $datenZeilen {
            if {![llength $zeile]} continue
            set werte [dict create]
            set extra {}
            set sp 0
            foreach f $zeile k $felder {
                set name [lindex $kopf $sp]
                incr sp
                if {$k eq "" || $k eq "-"} {
                    # MIT DEM SPALTENNAMEN in die Notiz, nicht nur der
                    # Wert. "eb" allein sagt niemandem etwas; "kl: eb"
                    # schon.
                    if {$f ne ""} {
                        lappend extra [expr {$name eq "" ? $f : "$name: $f"}]
                    }
                    continue
                }
                if {$f eq ""} continue
                if {[dict exists $werte $k] && [dict get $werte $k] ne ""} {
                    # Zwei Quellspalten auf dasselbe Feld (etwa Privat-
                    # und Diensttelefon): die erste gewinnt, die zweite
                    # geht in die Notiz statt verloren.
                    lappend extra [expr {$name eq "" ? $f : "$name: $f"}]
                } else {
                    dict set werte $k $f
                }
            }
            if {[llength $extra]} {
                set alt [expr {[dict exists $werte notiz]
                               ? [dict get $werte notiz] : ""}]
                set neu [join $extra "\n"]
                dict set werte notiz [string trim "$alt\n$neu"]
            }
            _einfuegen $werte
            incr n
        }
    }
    return $n
}

# Welche Spalte ist welches Feld -- und wo fangen die Daten an?
proc ::adressbuch::_deutung {rows opt} {
    set herkunft [dict get $opt -herkunft]
    set kopfzeile [dict get $opt -kopfzeile]
    set eigene [dict get $opt -felder]

    # Ausdrueckliche Feldliste schlaegt alles.
    if {[llength $eigene]} {
        set ab [expr {$kopfzeile eq "0" ? 0 : 1}]
        set k [expr {$ab ? [lindex $rows 0] : {}}]
        return [list $eigene [lrange $rows $ab end] $k]
    }

    set erste [lindex $rows 0]
    if {$kopfzeile eq "auto"} {
        set kopfzeile [::adressbuch::herkunft::hatKopfzeile $erste]
    }

    if {!$kopfzeile} {
        # Ohne Kopfzeile hilft nur die bekannte Spaltenfolge.
        if {$herkunft eq "auto"} { set herkunft thunderbird }
        if {![info exists ::adressbuch::herkunft::spaltenfolge($herkunft)]} {
            error "ohne Kopfzeile und ohne bekannte Spaltenfolge fuer\
                    \"$herkunft\" laesst sich nichts zuordnen"
        }
        return [list $::adressbuch::herkunft::spaltenfolge($herkunft) $rows {}]
    }

    if {$herkunft eq "auto"} {
        set herkunft [::adressbuch::herkunft::erkennen $erste]
        if {$herkunft eq ""} { set herkunft eigen }
    }
    if {![info exists ::adressbuch::herkunft::zuordnung($herkunft)]} {
        error "unbekannte Herkunft: $herkunft"
    }
    set z [dict create {*}$::adressbuch::herkunft::zuordnung($herkunft)]
    set felder {}
    foreach k $erste {
        set k [string tolower [string trim $k]]
        if {[dict exists $z $k]} {
            lappend felder [dict get $z $k]
        } else {
            lappend felder ""
        }
    }
    return [list $felder [lrange $rows 1 end] $erste]
}

proc ::adressbuch::csvSchreiben {datei {ids ""}} {
    if {$ids eq ""} { set ids [alle] }
    set zeilen [list [felder]]
    foreach id $ids {
        set d [lesen $id]
        set z {}
        foreach f [felder] { lappend z [dict get $d $f] }
        lappend zeilen $z
    }
    set ch [open $datei w]
    fconfigure $ch -encoding utf-8
    foreach z $zeilen { puts $ch [::tclutils::tucsv::joinLine $z] }
    close $ch
    return [expr {[llength $zeilen] - 1}]
}

# --- CardDAV (Radicale und andere) ------------------------------------------
#
# Ein CardDAV-Server -- Radicale, Nextcloud, SOGo -- haelt vCards, kein
# CSV. tclutils::tudav holt sie, tclutils::tuvcard liest sie; diese
# Prozedur verbindet beides.
#
# ABSICHTLICH NUR LESEND. Zurueckschreiben hiesse, mit Etags und
# Konflikten umzugehen ("wer zuletzt schreibt, gewinnt" ist bei fremden
# Adressbuechern keine Antwort). Wer das braucht, baut es als eigenen
# Schritt -- nicht nebenbei.

proc ::adressbuch::davHolen {url args} {
    package require tclutils::tudav
    set opt [dict create -user "" -password "" -pfad "" -entfernen 0]
    dict for {k v} $args {
        if {![dict exists $opt $k]} { error "unbekannte Option: $k" }
        dict set opt $k $v
    }
    set c [::tclutils::tudav::client $url \
            -user [dict get $opt -user] \
            -password [dict get $opt -password]]
    set n 0
    set gesehen {}
    try {
        set liste [::tclutils::tudav::listResources $c \
                -path [dict get $opt -pfad]]
        foreach res $liste {
            set href [dict get $res href]
            # NUR .vcf HOLEN. Eine Sammlung enthaelt auch anderes --
            # wer alles herunterlaedt, bekommt HTML-Seiten als Adressen.
            if {![string match -nocase *.vcf $href]
                    && ![string match -nocase *vcard* \
                         [dict get $res contenttype]]} continue
            set text [::tclutils::tudav::get $c $href]
            incr n [_vcardAbgleichen $text gesehen $href]
        }
    } finally {
        ::tclutils::tudav::destroy $c
    }
    # Was der Server NICHT mehr hat: nur auf ausdruecklichen Wunsch
    # entfernen.
    #
    # Voreingestellt bleibt es stehen. Ein Abgleich, der ungefragt
    # loescht, ist gefaehrlich: ein halb geantworteter Server oder ein
    # falscher Pfad wuerde das ganze Adressbuch leeren.
    if {[dict get $opt -entfernen]} {
        variable db
        foreach id [alle] {
            set u [uidVon $id]
            if {$u ne "" && $u ni $gesehen} { loeschen $id }
        }
    }
    return $n
}

# Eine Karte einarbeiten: vorhanden -> aktualisieren, neu -> anlegen.
#
# ERKANNT WIRD AN DER UID, nicht am Namen. Zwei Menschen koennen gleich
# heissen; eine UID gibt es einmal.
# NICHT JEDE vCARD HAT EINE UID.
#
# Sie ist in vCard 3.0 nicht vorgeschrieben, und Thunderbird-Exporte
# tragen oft keine. Ohne Ersatzschluessel verdoppelt jeder weitere
# Abgleich die Eintraege -- gemessen an den eigenen Testkarten, die
# keine hatten.
#
# Der Ersatz ist der PFAD AUF DEM SERVER: eine Datei liegt dort einmal,
# und beim naechsten Mal liegt sie an derselben Stelle. Er ist
# schwaecher als eine UID -- wer die Datei umbenennt, bekommt einen
# zweiten Eintrag -- aber besser als gar kein Schluessel.
proc ::adressbuch::_vcardAbgleichen {text gesehenVar {href ""}} {
    upvar 1 $gesehenVar gesehen
    set n 0
    set karten [::tclutils::tuvcard::parse $text]
    set mehrere [expr {[llength $karten] > 1}]
    foreach karte $karten {
        set w [_vcardZuWerten $karte]
        if {![dict size $w]} continue
        set uid [expr {[dict exists $w uid] ? [dict get $w uid] : ""}]
        if {$uid eq "" && $href ne "" && !$mehrere} {
            # Nur wenn EINE Karte in der Datei steht -- sonst zeigten
            # alle auf denselben Schluessel und ueberschrieben sich
            # gegenseitig.
            set uid "href:$href"
            dict set w uid $uid
        }
        if {$uid ne ""} { lappend gesehen $uid }
        set id [idZuUid $uid]
        if {$id ne ""} {
            _aendern $id $w
        } else {
            _einfuegen $w
        }
        incr n
    }
    return $n
}

# --- vCard -----# --- vCard -----------------------------------------------------------------

proc ::adressbuch::vcardVon {id} {
    set d [lesen $id]
    set k {}
    set voll [string trim "[dict get $d vorname] [dict get $d name]"]
    lappend k [dict create name FN value $voll params {}]
    lappend k [dict create name N \
            value "[dict get $d name];[dict get $d vorname];;;" params {}]
    foreach {feld eigen typ} {
        email    EMAIL {}
        email2   EMAIL {}
        telefon  TEL   voice
        mobil    TEL   cell
    } {
        set w [dict get $d $feld]
        if {$w eq ""} continue
        set p {}
        if {$typ ne ""} { set p [dict create TYPE $typ] }
        lappend k [dict create name $eigen value $w params $p]
    }
    set adr [dict get $d strasse]
    if {[dict get $d nummer] ne ""} { append adr " [dict get $d nummer]" }
    if {$adr ne "" || [dict get $d ort] ne ""} {
        lappend k [dict create name ADR params {} \
                value ";;$adr;[dict get $d ort];;[dict get $d plz];"]
    }
    return $k
}

proc ::adressbuch::vcardSchreiben {datei {ids ""}} {
    if {$ids eq ""} { set ids [alle] }
    set karten {}
    foreach id $ids { lappend karten [vcardVon $id] }
    set ch [open $datei w]
    fconfigure $ch -encoding utf-8 -translation binary
    puts -nonewline $ch [::tclutils::tuvcard::toVcf $karten]
    close $ch
    return [llength $karten]
}

proc ::adressbuch::vcardLesen {datei} {
    set ch [open $datei r]
    fconfigure $ch -encoding utf-8
    set text [read $ch]
    close $ch
    return [_vcardTextLesen $text]
}

# Derselbe Weg fuer Text aus einer Datei und Text vom Server -- eine
# Stelle, nicht zwei.
proc ::adressbuch::_vcardTextLesen {text} {
    set n 0
    foreach karte [::tclutils::tuvcard::parse $text] {
        set w [_vcardZuWerten $karte]
        if {[dict size $w]} { _einfuegen $w ; incr n }
    }
    return $n
}

# Eine geparste vCard in unsere Felder uebersetzen.
#
# EINE STELLE, nicht zwei: aus der Datei und vom Server kommt dasselbe,
# und es soll auch dasselbe daraus werden.
proc ::adressbuch::_vcardZuWerten {karte} {
    set w [dict create]
    foreach p $karte {
        set nm [string toupper [dict get $p name]]
        set v [dict get $p value]
        switch -- $nm {
            UID { dict set w uid $v }
            N {
                lassign [split $v ";"] nach vor
                dict set w name $nach
                dict set w vorname $vor
            }
            EMAIL {
                if {![dict exists $w email]} { dict set w email $v } \
                else { dict set w email2 $v }
            }
            TEL {
                set par [dict get $p params]
                set typ ""
                if {[dict exists $par TYPE]} {
                    set typ [string tolower [dict get $par TYPE]]
                }
                if {$typ eq "cell"} { dict set w mobil $v } \
                else { dict set w telefon $v }
            }
            ADR {
                set t [split $v ";"]
                dict set w strasse [lindex $t 2]
                dict set w ort     [lindex $t 3]
                dict set w plz     [lindex $t 5]
            }
        }
    }
    # FN allein, ohne N: dann wenigstens den vollen Namen retten.
    if {![dict exists $w name]} {
        foreach p $karte {
            if {[string toupper [dict get $p name]] eq "FN"} {
                dict set w name [dict get $p value]
            }
        }
    }
    return $w
}

# --- jetzt laden ------------------------------------------------------------
#
# Ganz am Schluss, damit _mcPfade alle Prozeduren zur Verfuegung hat.
set ::adressbuch::mcDatei [::adressbuch::_mcLaden]

package provide adressbuch::model 0.1
