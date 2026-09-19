#!/bin/sh
# dist-bauen.sh -- SQLite3MultipleCiphers fuer ALLE gefundenen
# Tcl-Fassungen bauen und nach dist/ einsortieren.
#
#     cd SQLite3MultipleCiphers-2.2.5
#     sh /pfad/dist-bauen.sh /pfad/zum/adressbuch
#
# Ohne Argument landet dist/ neben diesem Skript.
#
# WARUM EIN EIGENES SKRIPT.
#
# bauen-sqlite3mc.sh baut EINE Fassung. Das dist braucht je eine pro
# Tcl-Fassung -- eine .so passt nur zu einer, gemessen: gegen 8.6
# gebaut laedt sie unter 9.0 nicht. Die Zuordnung von Hand zu machen
# ist genau die Stelle, an der man sich vertut und eine 8.6-Datei nach
# tcl9.0/ legt.

HIER=$(cd "$(dirname "$0")" && pwd)
ZIEL="${1:-$HIER}"
BAUEN="$HIER/bauen-sqlite3mc.sh"

sagen() { printf '  %s\n' "$*"; }

# pkgIndex.tcl neben die Bibliothek legen.
#
# WARUM EIN EIGENER PAKETNAME. Die Bibliothek meldet sich INTERN als
# "sqlite3" an. Wuerde der Index denselben Namen anbieten, entschiede
# die Reihenfolge im Suchpfad, welche Fassung kommt -- die
# verschluesselnde oder die gewoehnliche. Die eine kann "PRAGMA key",
# die andere nicht; das will man nicht dem Zufall ueberlassen.
indexSchreiben() {
    _verz="$1"
    _datei="$2"
    # GESCHUETZTER HEREDOC (<<'EOF') und der Dateiname per sed.
    #
    # Ohne die Anfuehrungszeichen frisst die Shell die Dollarzeichen:
    # aus "$dir" wurde nichts, und der erzeugte Index enthielt
    #     set f [file join \ libsqlite3mc.so]
    # -- gemessen 12.09.2026. Er laedt dann nie, und "package require"
    # meldet nur "can't find package".
    cat > "$_verz/pkgIndex.tcl" <<'IDXEOF'
# pkgIndex.tcl -- SQLite3MultipleCiphers als ladbares Paket.
# ERZEUGT von dist-bauen.sh. Nicht von Hand pflegen.
#
#     lappend auto_path /pfad/zu/diesem/verzeichnis
#     package require sqlite3mc
#
# EIGENER NAME, nicht "sqlite3": die Bibliothek meldet sich intern als
# sqlite3 an. Boete dieser Index denselben Namen, entschiede die
# Reihenfolge im Suchpfad, welche Fassung kommt -- die verschluesselnde
# oder die gewoehnliche. Die eine kann "PRAGMA key", die andere nicht.
#
# Nebenwirkung: nach dem Laden ist AUCH "sqlite3" angemeldet, denn die
# Bibliothek traegt sich selbst so ein. Das ist richtig -- der Befehl
# sqlite3 kommt ja aus ihr.

package ifneeded sqlite3mc 3.53.0 [list apply {{dir} {
    set f [file join $dir @DATEI@]
    if {![file readable $f]} {
        return -code error "sqlite3mc: $f nicht lesbar"
    }
    load $f Sqlite3
    package provide sqlite3mc 3.53.0
}} $dir]
IDXEOF
    sed -i "s|@DATEI@|$_datei|" "$_verz/pkgIndex.tcl"
    sagen "pkgIndex.tcl geschrieben"
}
fehler() { printf '  FEHLER: %s\n' "$*" >&2; exit 1; }

[ -f "$PWD/src/sqlite3mc.c" ] || fehler "src/sqlite3mc.c nicht gefunden.
          Dieses Skript im entpackten SQLite3MultipleCiphers-Verzeichnis
          aufrufen."
[ -f "$BAUEN" ] || fehler "bauen-sqlite3mc.sh liegt nicht neben diesem Skript"

sagen "Quelle: $PWD"
sagen "Ziel:   $ZIEL/dist"

# --- Welche Tcl-Installationen gibt es? ------------------------------------
#
# Gesucht wird nach tclConfig.sh, nicht nach tclsh: nur sie nennt
# Include-Pfad und Stub-Bibliothek. Doppelte Fassungen werden
# uebergangen -- die erste gefundene gewinnt.

KANDIDATEN=""
for D in /opt/tcl9/lib /usr/local/lib /usr/lib /usr/lib64 \
         /usr/lib/x86_64-linux-gnu /usr/lib/aarch64-linux-gnu \
         /opt/tcl86/lib /opt/tcl/lib; do
    [ -r "$D/tclConfig.sh" ] && KANDIDATEN="$KANDIDATEN $D/tclConfig.sh"
done
# Und was sonst noch herumliegt, aber nicht den ganzen Baum absuchen.
for D in /usr/lib/tcl8.6 /usr/lib/tcl9.0 /usr/local/lib/tcl8.6 \
         /usr/local/lib/tcl9.0; do
    [ -r "$D/tclConfig.sh" ] && KANDIDATEN="$KANDIDATEN $D/tclConfig.sh"
done

[ -n "$KANDIDATEN" ] || fehler "keine tclConfig.sh gefunden.
          Suchen mit:  find / -name tclConfig.sh 2>/dev/null
          und einzeln bauen:  sh bauen-sqlite3mc.sh /pfad/tclConfig.sh"

# --- System und Endung ------------------------------------------------------

case "$(uname -s)" in
    Linux)          SYS=linux ; ENDUNG=.so    ; NAME=libsqlite3mc ;;
    Darwin)         SYS=mac   ; ENDUNG=.dylib ; NAME=libsqlite3mc ;;
    MINGW*|MSYS*|CYGWIN*) SYS=win ; ENDUNG=.dll ; NAME=sqlite3mc ;;
    *)              SYS=linux ; ENDUNG=.so    ; NAME=libsqlite3mc
                    sagen "unbekanntes System $(uname -s) -- nehme linux" ;;
esac
sagen "System: $SYS$ENDUNG"

# --- Bauen -------------------------------------------------------------------

GEMACHT=""
GESCHEITERT=""
for CONF in $KANDIDATEN; do
    # Die Fassung VOR dem Bauen erfragen, damit doppelte uebersprungen
    # werden koennen.
    V=$(. "$CONF" 2>/dev/null; printf '%s' "$TCL_VERSION")
    [ -n "$V" ] || continue
    case " $GEMACHT " in *" $V "*) continue ;; esac

    echo ""
    sagen "=== Tcl $V  ($CONF)"
    AUSGABE="$ZIEL/dist/$SYS/tcl$V/$NAME$ENDUNG"
    mkdir -p "$(dirname "$AUSGABE")" || fehler "kann $(dirname "$AUSGABE") nicht anlegen"

    if AUS="$AUSGABE" sh "$BAUEN" "$CONF"; then
        GEMACHT="$GEMACHT $V"
        indexSchreiben "$(dirname "$AUSGABE")" "$(basename "$AUSGABE")"
    else
        GESCHEITERT="$GESCHEITERT $V"
        # Eine halbe Datei ist schlimmer als keine: sie wuerde beim
        # naechsten Start gefunden und scheiterte erst beim Laden.
        rm -f "$AUSGABE"
    fi
done

# --- Was dabei herauskam ----------------------------------------------------

echo ""
sagen "--- Ergebnis ---"
if [ -n "$GEMACHT" ]; then
    for V in $GEMACHT; do
        F="$ZIEL/dist/$SYS/tcl$V/$NAME$ENDUNG"
        sagen "gebaut:      Tcl $V  ->  dist/$SYS/tcl$V/$NAME$ENDUNG ($(wc -c < "$F") Bytes)"
    done
else
    sagen "gebaut:      nichts"
fi
[ -n "$GESCHEITERT" ] && sagen "gescheitert: $GESCHEITERT"

[ -n "$GEMACHT" ] || fehler "keine einzige Fassung gebaut"

# --- Windows quer bauen ------------------------------------------------------
#
# Nur auf Wunsch: TCLSRC_WIN muss auf einen Tcl-QUELLBAUM zeigen, und
# MinGW muss da sein.
#
#     TCLSRC_WIN=/pfad/tcl9.0.4 sh dist-bauen.sh /ziel
#
# WARUM EIN QUELLBAUM UND KEINE INSTALLATION: fuer Windows braucht es
# libtclstub.a in Windows-Form. Die liegt in keiner Linux-Installation
# -- sie wird aus dem Quellbaum mit MinGW gebaut:
#
#     cd /tmp/tclwin
#     /pfad/tcl9.0.4/win/configure --host=x86_64-w64-mingw32
#     make libtclstub.a
#
# Das macht dieses Skript selbst.

if [ -n "$TCLSRC_WIN" ]; then
    echo ""
    sagen "=== Windows (quer gebaut)"
    S="$PWD/src"
    INC=$(find "$S" -type d | sed 's/^/-I/' | tr '\n' ' ')
    MGCC=x86_64-w64-mingw32-gcc
    if ! command -v $MGCC >/dev/null 2>&1; then
        sagen "uebersprungen: $MGCC fehlt.
          Debian/Ubuntu:  sudo apt install gcc-mingw-w64-x86-64"
    elif [ ! -f "$TCLSRC_WIN/win/configure" ]; then
        sagen "uebersprungen: \$TCLSRC_WIN zeigt auf keinen Tcl-Quellbaum
          ($TCLSRC_WIN/win/configure fehlt)"
    else
        WV=$(grep -oE 'TCL_VERSION=[0-9.]+' "$TCLSRC_WIN/win/configure.ac" 2>/dev/null \
             | head -1 | cut -d= -f2)
        [ -n "$WV" ] || WV=$(sed -n 's/.*TCL_VERSION[ \t]*"\([0-9.]*\)".*/\1/p' \
             "$TCLSRC_WIN/generic/tcl.h" 2>/dev/null | head -1)
        [ -n "$WV" ] || WV=9.0
        sagen "Tcl-Quellbaum: $TCLSRC_WIN (Fassung $WV)"

        STUBDIR="${TMPDIR:-/tmp}/tclwin-stub-$WV"
        if [ ! -f "$STUBDIR/libtclstub.a" ]; then
            sagen "baue libtclstub.a fuer Windows ..."
            mkdir -p "$STUBDIR"
            ( cd "$STUBDIR" \
              && "$TCLSRC_WIN/win/configure" --host=x86_64-w64-mingw32 \
                 > configure.log 2>&1 \
              && make libtclstub.a > make.log 2>&1 ) \
              || sagen "libtclstub.a fehlgeschlagen (siehe $STUBDIR/*.log)"
        fi

        if [ -f "$STUBDIR/libtclstub.a" ]; then
            WAUS="$ZIEL/dist/win/tcl$WV/sqlite3mc.dll"
            mkdir -p "$(dirname "$WAUS")"
            sagen "uebersetze sqlite3mc.dll ..."
            # BUILD_sqlite -- NICHT BUILD_sqlite3. Ohne die richtige
            # Kennung erklaert tclsqlite.c Sqlite3_Init als dllIMPORT,
            # und der Binder sucht __imp_Sqlite3_Init. Gemessen.
            if $MGCC -O2 -shared -o "$WAUS" \
                $INC -I"$TCLSRC_WIN/generic" -I"$TCLSRC_WIN/win" -I"$STUBDIR" \
                -DSQLITE_THREADSAFE=1 -DUSE_TCL_STUBS -DBUILD_sqlite \
                -DPACKAGE_NAME='"sqlite3"' -DPACKAGE_VERSION='"3.53.0"' \
                "$S/tclsqlite.c" "$S/sqlite3mc.c" \
                "$STUBDIR/libtclstub.a" -lm 2>"${TMPDIR:-/tmp}/mc-win-fehler.txt"
            then
                sagen "gebaut:      Windows Tcl $WV  ->  dist/win/tcl$WV/sqlite3mc.dll ($(wc -c < "$WAUS") Bytes)"
                indexSchreiben "$(dirname "$WAUS")" "$(basename "$WAUS")"
                sagen "NICHT GEPRUEFT -- quer gebaut, hier laeuft kein Windows."
            else
                grep -iE 'error|undefined' "${TMPDIR:-/tmp}/mc-win-fehler.txt" | head -4
                rm -f "$WAUS"
                sagen "Windows-Bau fehlgeschlagen"
            fi
        fi
    fi
fi

echo ""
echo "Fertig. Das Adressbuch findet die passende Datei jetzt selbst --"
echo "wenn dist/ neben adressbuch-modell.tcl liegt."
echo ""
