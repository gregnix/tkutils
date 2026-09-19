# SQLite3MultipleCiphers bauen

Die uebliche `sqlite3`-Anbindung kann **nicht** verschluesseln.
SQLite3MultipleCiphers ersetzt sie und versteht zusaetzlich
`PRAGMA key`.

## Die Falle, die es zu kennen gilt

Die gewoehnliche Anbindung kennt den Unterbefehl **`rekey`**. Er steht
in der Fehlerliste, laesst sich aufrufen, **meldet Erfolg -- und
verschluesselt nichts**:

```
db rekey geheim          -> kein Fehler
grep KLARTEXT datei.db   -> Treffer
```

Gemessen 12.09.2026. Wer sich darauf verlaesst, haelt eine offene Datei
fuer geschuetzt. `krypto-4.1` haelt den Befund fest.

Darum fragt das Adressbuch **nicht nach dem Befehl**, sondern misst: es
legt eine Probedatei an, schreibt einen erkennbaren Text hinein und
sieht nach, ob er noch lesbar darin steht
(`adressbuch::kannVerschluesseln`).

## Bauen

```sh
cd SQLite3MultipleCiphers-2.2.5
sh /pfad/bauen-sqlite3mc.sh
```

Das Skript **raet keine Pfade**. Die erste Fassung dieser Anleitung
schrieb `-I/opt/tcl9/include` hin -- das war der Pfad einer bestimmten
Maschine, und die Fehlermeldung lautete dann nur
*"tcl.h: Datei oder Verzeichnis nicht gefunden"*.

`tclConfig.sh` weiss es selbst: sie steht neben jeder
Tcl-Installation und nennt Include-Pfad, Stub-Bibliothek und Version.
Das Skript fragt das laufende `tclsh`, wo sie liegt. Geht das nicht:

```sh
find / -name tclConfig.sh 2>/dev/null
sh bauen-sqlite3mc.sh /pfad/lib/tclConfig.sh
```

### Was es prueft

* **Liegt `tcl.h` wirklich dort**, wo `tclConfig.sh` es sagt? Sonst
  fehlt meist das Entwicklerpaket (`sudo apt install tcl-dev`) oder das
  selbst gebaute Tcl wurde ohne Kopfdateien installiert.
* **Laedt die Bibliothek** in ein `tclsh` der gebauten Fassung? Gegen
  8.6 gebaut und mit 9.0 geprueft uebersetzt sauber und laedt trotzdem
  nicht -- gemessen.
* **Verschluesselt sie wirklich?** Probedatei anlegen, erkennbaren Text
  hineinschreiben, nachsehen. Nicht fragen, ob der Befehl da ist.

### Von Hand

```sh
S=$PWD/src
INC=$(find $S -type d | sed 's/^/-I/' | tr '\n' ' ')
. /pfad/lib/tclConfig.sh

gcc -O2 -fPIC -shared -o libsqlite3mc.so \
  $INC $TCL_INCLUDE_SPEC \
  -DSQLITE_THREADSAFE=1 -DUSE_TCL_STUBS \
  -DPACKAGE_NAME='"sqlite3"' -DPACKAGE_VERSION='"3.53.0"' \
  $S/tclsqlite.c $S/sqlite3mc.c \
  $TCL_STUB_LIB_SPEC -lpthread -lm -ldl
```

**Drei Punkte, die Zeit gekostet haben:**

* **`src/tclsqlite.c` benutzen, nicht das aus dem Tcl-Baum.** Der
  Tcl-Baum hat nur `tclsqlite3.c` -- die Amalgamation MIT sqlite3.c
  darin, die den Codec nicht kennt. SQLite3MultipleCiphers bringt die
  reine Anbindung selbst mit.
* **Alle Unterverzeichnisse von `src` als Include-Pfad.** Aegis und
  Argon2 liegen in eigenen Ordnern und suchen einander flach.
* **Include und Stub aus `tclConfig.sh`**, nicht von Hand. Die
  Stub-Bibliothek heisst je nach Bau `libtclstub.a` oder
  `libtclstub9.0.a`.

## Benutzen

```sh
ADRESSBUCH_SQLITE3MC=/pfad/libsqlite3mc.so wish adressbuch.tcl
```

```tcl
adressbuch::oeffnen ~/adressen.db geheim
```

Ohne Kennwort bleibt alles wie bisher -- eine gewoehnliche Datei
(`krypto-1.1`). Verschluesselung ist eine Moeglichkeit, keine Pflicht.

**Ohne faehigen Bau wird ein Kennwort ABGELEHNT** (`krypto-3.1`), nicht
stillschweigend uebergangen. Wer eines angibt, erwartet Schutz; eine
ungeschuetzte Datei, die man fuer geschuetzt haelt, ist schlimmer als
eine offen als ungeschuetzt bekannte.

## Gemessen

```
ohne Kennwort:        SQLite format 3...     (lesbar)
mit Kennwort:         033 | 036 231 \n 343   (kein Dateikopf)
falsches Kennwort:    Falsches Kennwort oder keine Adressbuchdatei
Apostroph im Kennwort: geht (krypto-2.4)
```
