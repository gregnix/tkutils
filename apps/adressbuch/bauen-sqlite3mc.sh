#!/bin/sh
# bauen-sqlite3mc.sh -- die Tcl-Anbindung von SQLite3MultipleCiphers bauen.
#
#     cd SQLite3MultipleCiphers-2.2.5
#     sh /pfad/bauen-sqlite3mc.sh
#
# Oder mit einem bestimmten Tcl:
#
#     sh bauen-sqlite3mc.sh /opt/tcl9/lib/tclConfig.sh
#
# KEINE PFADE RATEN.
#
# Die erste Anleitung schrieb "-I/opt/tcl9/include" hin -- das war MEIN
# Pfad, nicht jeder hat ihn, und der Fehler lautet dann nur
# "tcl.h: Datei oder Verzeichnis nicht gefunden". Gemeldet 12.09.2026.
#
# tclConfig.sh weiss es selbst: sie steht neben jeder Tcl-Installation
# und nennt Include-Pfad, Stub-Bibliothek und Version.

sagen() { printf '  %s\n' "$*"; }
fehler() { printf '  FEHLER: %s\n' "$*" >&2; exit 1; }

# --- Quellbaum -------------------------------------------------------------

S="$PWD/src"
[ -f "$S/sqlite3mc.c" ] || fehler "src/sqlite3mc.c nicht gefunden.
          Dieses Skript im entpackten SQLite3MultipleCiphers-Verzeichnis
          aufrufen."
[ -f "$S/tclsqlite.c" ] || fehler "src/tclsqlite.c nicht gefunden."

# --- Welches Tcl? ----------------------------------------------------------

CONF="$1"
if [ -z "$CONF" ]; then
    # Das Tcl fragen, das gerade laeuft -- nicht irgendeines suchen.
    for T in tclsh9.0 tclsh9 tclsh8.6 tclsh; do
        command -v "$T" >/dev/null 2>&1 || continue
        P=$("$T" <<'EOF' 2>/dev/null
if {[catch {package require platform}]} { }
# tcl_pkgPath und die Nachbarn von tcl_library absuchen
set kandidaten {}
lappend kandidaten [file join [file dirname $tcl_library] tclConfig.sh]
lappend kandidaten [file join [file dirname [file dirname $tcl_library]] tclConfig.sh]
foreach d [set ::tcl_pkgPath] {
    lappend kandidaten [file join $d tclConfig.sh]
    lappend kandidaten [file join [file dirname $d] tclConfig.sh]
}
foreach k $kandidaten {
    if {[file readable $k]} { puts $k ; break }
}
EOF
)
        if [ -n "$P" ] && [ -r "$P" ]; then
            CONF="$P"
            sagen "Tcl gefunden ueber: $T"
            break
        fi
    done
fi

[ -n "$CONF" ] || fehler "keine tclConfig.sh gefunden.
          Pfad angeben:  sh bauen-sqlite3mc.sh /pfad/lib/tclConfig.sh
          Suchen mit:    find / -name tclConfig.sh 2>/dev/null"
[ -r "$CONF" ] || fehler "nicht lesbar: $CONF"

. "$CONF"

[ -n "$TCL_INCLUDE_SPEC" ] || fehler "$CONF nennt kein TCL_INCLUDE_SPEC"
[ -n "$TCL_STUB_LIB_SPEC" ] || fehler "$CONF nennt kein TCL_STUB_LIB_SPEC"

sagen "tclConfig.sh: $CONF"
sagen "Tcl-Version:  $TCL_VERSION"
sagen "Include:      $TCL_INCLUDE_SPEC"
sagen "Stub:         $TCL_STUB_LIB_SPEC"

# Die Kopfdatei wirklich nachsehen, statt dem Eintrag zu glauben.
IDIR=$(printf '%s' "$TCL_INCLUDE_SPEC" | sed 's/^-I//')
[ -f "$IDIR/tcl.h" ] || fehler "tcl.h liegt nicht in $IDIR.
          Bei Debian/Ubuntu fehlt meist das Entwicklerpaket:
          sudo apt install tcl-dev      (fuer das System-Tcl)
          Bei selbst gebautem Tcl: mit 'make install' auch die
          Kopfdateien installieren."

# --- Uebersetzen -----------------------------------------------------------
#
# ALLE Unterverzeichnisse von src als Include-Pfad: Aegis und Argon2
# liegen in eigenen Ordnern und suchen einander flach.

INC=$(find "$S" -type d | sed 's/^/-I/' | tr '\n' ' ')
sagen "Include-Pfade aus src: $(printf '%s' "$INC" | wc -w)"

CC=${CC:-gcc}
AUS=${AUS:-libsqlite3mc.so}

sagen "uebersetze (das dauert eine Weile) ..."
$CC -O2 -fPIC -shared -o "$AUS" \
    $INC $TCL_INCLUDE_SPEC \
    -DSQLITE_THREADSAFE=1 -DUSE_TCL_STUBS \
    -DPACKAGE_NAME='"sqlite3"' -DPACKAGE_VERSION='"3.53.0"' \
    "$S/tclsqlite.c" "$S/sqlite3mc.c" \
    $TCL_STUB_LIB_SPEC -lpthread -lm -ldl 2>/tmp/mc-fehler.txt
RC=$?

if [ $RC -ne 0 ] || [ ! -f "$AUS" ]; then
    sagen "--- Meldungen ---"
    grep -i 'error\|fatal' /tmp/mc-fehler.txt | head -8
    fehler "Uebersetzen fehlgeschlagen (vollstaendig in /tmp/mc-fehler.txt)"
fi

# AUS kann absolut sein (dist-bauen.sh gibt einen vollen Pfad).
# "$PWD/$AUS" ergaebe dann /quelle//ziel/... -- richtig, aber unlesbar.
case "$AUS" in
    /*) VOLL="$AUS" ;;
    *)  VOLL="$PWD/$AUS" ;;
esac
sagen "gebaut: $VOLL ($(wc -c < "$AUS") Bytes)"

# --- NACHSEHEN, OB ES WIRKLICH VERSCHLUESSELT ------------------------------
#
# Nicht fragen, ob der Befehl da ist -- die gewoehnliche Anbindung kennt
# "rekey", meldet Erfolg und verschluesselt nichts. Geprueft wird an der
# Datei.

# MIT DEM PASSENDEN tclsh pruefen.
#
# Gegen Tcl 8.6 gebaut und mit 9.0 geprueft: die Bibliothek uebersetzt
# sauber und laedt trotzdem nicht. Gemessen. Darum zuerst das tclsh zur
# gebauten Fassung suchen.
case "$TCL_VERSION" in
    9*) TSH=$(command -v tclsh9.0 || command -v tclsh9 || command -v tclsh) ;;
    *)  TSH=$(command -v tclsh8.6 || command -v tclsh) ;;
esac
if [ -z "$TSH" ]; then
    sagen "kein tclsh zu Tcl $TCL_VERSION gefunden -- Probe uebersprungen"
    exit 0
fi
sagen "pruefe mit:   $TSH"

PROBE=$(mktemp -u /tmp/mc-probe-XXXXXX.db)
"$TSH" <<EOF >/dev/null 2>&1
load [file normalize "$AUS"] Sqlite3
sqlite3 db $PROBE
db eval {PRAGMA key = 'probe'}
db eval {CREATE TABLE t(a TEXT)}
db eval {INSERT INTO t VALUES('KLARTEXTPROBE')}
db close
EOF

if [ ! -f "$PROBE" ]; then
    fehler "die Bibliothek laedt nicht in $TSH.
          Haeufigster Grund: gegen eine andere Tcl-Fassung gebaut.
          Gebaut gegen Tcl $TCL_VERSION -- passt das zu dem tclsh,
          mit dem das Adressbuch laeuft?
          Dann die richtige tclConfig.sh angeben:
          sh bauen-sqlite3mc.sh /pfad/lib/tclConfig.sh"
fi
if grep -q 'KLARTEXTPROBE' "$PROBE" 2>/dev/null; then
    rm -f "$PROBE"
    fehler "gebaut, aber es VERSCHLUESSELT NICHT -- der Klartext steht
          noch in der Probedatei."
fi
rm -f "$PROBE"
sagen "Probe: verschluesselt."

echo ""
echo "Fertig. Weiter mit:"
echo ""
echo "    ADRESSBUCH_SQLITE3MC=$VOLL wish adressbuch.tcl"
echo ""
