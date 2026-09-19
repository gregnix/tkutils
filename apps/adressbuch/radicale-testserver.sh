#!/bin/sh
# radicale-testserver.sh -- einen echten Radicale zum Pruefen aufsetzen.
#
# WOZU, wenn es schon dav-testserver.tcl gibt.
#
# Der Tcl-Nachbau spricht so viel CardDAV, wie davHolen braucht -- aber
# eben nur so viel. Ob es mit einem RICHTIGEN Server geht, sagt nur ein
# richtiger Server. Radicale ist dafuer der naheliegende: klein, in
# Python, ohne Datenbank.
#
#     pip install radicale
#     sh radicale-testserver.sh /tmp/rad 5232
#     ADRESSBUCH_RADICALE=5232 tclsh adressbuch-dav.test
#
# DIESES SKRIPT SAGT, WAS ES TUT.
#
# Die erste Fassung hatte "set -e" und schwieg: fehlte Radicale, brach
# sie ohne ein Wort ab, und man stand vor einer leeren Eingabezeile.
# Gemeldet 12.09.2026. Ein Werkzeug, das stumm scheitert, ist schlimmer
# als keines -- man sucht dann am falschen Ende.

VERZ="${1:-/tmp/rad}"
PORT="${2:-5232}"
BENUTZER=greg
KENNWORT=geheim

sagen() { printf '  %s\n' "$*"; }
fehler() { printf '  FEHLER: %s\n' "$*" >&2; exit 1; }

sagen "Verzeichnis: $VERZ"
sagen "Port:        $PORT"

# --- Voraussetzungen -------------------------------------------------------

command -v python3 >/dev/null 2>&1 || fehler "python3 nicht gefunden"

# WELCHES PYTHON HAT RADICALE?
#
# Debian 13 und andere neuere Systeme schuetzen ihr Python: "pip install"
# bricht mit "externally-managed-environment" ab (PEP 668). Der Rat
# "--break-system-packages" steht zwar in der Fehlermeldung, heisst aber
# genau, was er sagt -- er kann die Systeminstallation beschaedigen.
#
# Richtig ist eine eigene Umgebung. Dieses Skript legt sie selbst an,
# unter $VERZ/venv, und benutzt nur sie. Das Systempython bleibt
# unberuehrt.
PY=python3
if python3 -c 'import radicale' 2>/dev/null; then
    sagen "Radicale:    $(python3 -c 'import radicale; print(radicale.VERSION)') (Systempython)"
elif [ -x "$VERZ/venv/bin/python3" ] \
        && "$VERZ/venv/bin/python3" -c 'import radicale' 2>/dev/null; then
    PY="$VERZ/venv/bin/python3"
    sagen "Radicale:    $("$PY" -c 'import radicale; print(radicale.VERSION)') (aus $VERZ/venv)"
else
    sagen "Radicale fehlt -- lege eine eigene Umgebung an: $VERZ/venv"
    mkdir -p "$VERZ" || fehler "kann $VERZ nicht anlegen"
    if ! python3 -m venv "$VERZ/venv" 2>/dev/null; then
        fehler "python3 -m venv geht nicht.
          Debian/Ubuntu:  sudo apt install python3-venv
          Danach dieses Skript noch einmal aufrufen."
    fi
    sagen "installiere Radicale (das dauert einen Augenblick) ..."
    if ! "$VERZ/venv/bin/pip" install --quiet radicale 2>/tmp/pip-fehler.txt; then
        sagen "--- pip sagt ---"
        tail -5 /tmp/pip-fehler.txt 2>/dev/null
        fehler "Radicale liess sich nicht installieren"
    fi
    PY="$VERZ/venv/bin/python3"
    sagen "Radicale:    $("$PY" -c 'import radicale; print(radicale.VERSION)') (neu angelegt)"
fi

command -v curl >/dev/null 2>&1 || fehler "curl nicht gefunden"

# Laeuft schon etwas auf dem Port?
if curl -s --max-time 2 -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
    fehler "auf Port $PORT antwortet schon etwas.
          Beenden mit:  pkill -f 'radicale --config'
          oder einen anderen Port waehlen."
fi

# --- Aufsetzen -------------------------------------------------------------

mkdir -p "$VERZ/collections" || fehler "kann $VERZ nicht anlegen"
printf '%s:%s\n' "$BENUTZER" "$KENNWORT" > "$VERZ/users"

cat > "$VERZ/config" <<EOF
[server]
hosts = 127.0.0.1:$PORT

[auth]
type = htpasswd
htpasswd_filename = $VERZ/users
htpasswd_encryption = plain

[storage]
filesystem_folder = $VERZ/collections
EOF

# OHNE ANMELDUNG GEHT GAR NICHTS. Mit "auth type = none" ist der
# Benutzer anonym, und jeder Pfad unter /benutzer/ wird mit 401
# abgewiesen -- die Sammlung laesst sich nicht anlegen.

setsid nohup "$PY" -m radicale --config "$VERZ/config" \
        > "$VERZ/log.txt" 2>&1 < /dev/null &

# Warten, bis er antwortet -- hoechstens zehn Sekunden.
i=0
while [ $i -lt 50 ]; do
    if curl -s --max-time 1 -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
        break
    fi
    i=$((i + 1))
    sleep 0.2
done
if [ $i -ge 50 ]; then
    sagen "--- letzte Zeilen aus $VERZ/log.txt ---"
    tail -5 "$VERZ/log.txt" 2>/dev/null
    fehler "Radicale antwortet nicht auf Port $PORT"
fi
sagen "Radicale laeuft."

# --- Adressbuch anlegen ----------------------------------------------------
#
# PROPFIND und MKCOL OHNE Content-Length bleiben stehen: der Server
# wartet auf einen Rumpf, der nie kommt, und curl meldet "000" statt
# eines Fehlers.

A="-u $BENUTZER:$KENNWORT --max-time 10 -s"
BASIS="http://127.0.0.1:$PORT/$BENUTZER/adressen/"

code=$(curl $A -X MKCOL -o /dev/null -w '%{http_code}' \
    -H "Content-Type: application/xml" \
    --data '<?xml version="1.0" encoding="utf-8"?><D:mkcol xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav"><D:set><D:prop><D:resourcetype><D:collection/><C:addressbook/></D:resourcetype><D:displayname>Adressen</D:displayname></D:prop></D:set></D:mkcol>' \
    "$BASIS")
case "$code" in
    201|405) sagen "Sammlung:    $BASIS  ($code)" ;;
    *)       fehler "MKCOL gab $code zurueck (erwartet 201 oder 405)" ;;
esac

# --- vCards hineinstellen --------------------------------------------------
#
# Was im Verzeichnis liegt, kommt hinein. Liegt nichts da, werden zwei
# erfundene angelegt -- sonst steht ein leeres Adressbuch da, und der
# Test misst nichts.

if [ -z "$(ls "$VERZ"/*.vcf 2>/dev/null)" ]; then
    sagen "keine .vcf gefunden -- lege zwei Beispielkarten an"
    printf 'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:c1\r\nFN:Aino Baltrusch\r\nN:Baltrusch;Aino;;;\r\nEMAIL:aino@example.org\r\nTEL;TYPE=CELL:00170/22\r\nEND:VCARD\r\n' > "$VERZ/1.vcf"
    printf 'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:c2\r\nFN:Boris Cendrowski\r\nN:Cendrowski;Boris;;;\r\nEMAIL:boris@example.org\r\nEND:VCARD\r\n' > "$VERZ/2.vcf"
fi

i=1
for f in "$VERZ"/*.vcf; do
    [ -f "$f" ] || continue
    code=$(curl $A -X PUT -H "Content-Type: text/vcard" \
        --data-binary @"$f" -o /dev/null -w '%{http_code}' \
        "${BASIS}card$i.vcf")
    case "$code" in
        201|204) sagen "hineingestellt: $(basename "$f")  ($code)" ;;
        *)       fehler "PUT von $f gab $code zurueck" ;;
    esac
    i=$((i + 1))
done

anzahl=$(curl $A -X PROPFIND -H "Depth: 1" -H "Content-Length: 0" "$BASIS" \
    | grep -o '\.vcf' | wc -l)
sagen "im Adressbuch: $anzahl Karten"

echo ""
echo "Fertig. Weiter mit:"
echo ""
echo "    ADRESSBUCH_RADICALE=$PORT tclsh adressbuch-dav.test"
echo ""
echo "Beenden mit:"
echo ""
echo "    pkill -f 'radicale --config $VERZ'"
echo ""
