# Probedaten

Drei Dateien, dieselben Personen, drei Herkuenfte:

| Datei | Herkunft | Kopfzeile |
|---|---|---|
| `beispiel.csv` | eigenes Format | ja |
| `beispiel-outlook.csv` | Outlook | ja |
| `beispiel-thunderbird.csv` | Thunderbird | **nein** |

```sh
wish adressbuch.tcl /tmp/probe.db
# Datei -> CSV einlesen...        erkennt die Herkunft selbst
# Datei -> CSV einlesen als       oder man sagt es ihr
```

## Thunderbird schreibt keine Kopfzeile

Das ist der Unterschied, der beim Einlesen zaehlt: der CSV-Export von
Thunderbird enthaelt **nur Werte**. Wer eine Kopfzeile erwartet, verliert
den ersten Eintrag **und** ordnet alles falsch zu.

Die Erkennung merkt es an der ersten Zeile: steht dort eine
E-Mail-Adresse oder etwas, das wie eine Rufnummer aussieht, ist es keine
Kopfzeile.

## Was sich ausprobieren laesst

| | |
|---|---|
| Herkunft erkennen | dieselben Leute aus drei Dateien einlesen |
| Unbekannte Spalten | `Company` aus Outlook landet in **Notiz**, mit Spaltenname |
| Zwei Spalten, ein Feld | Outlook hat `Home Phone` und `Business Phone` -- die erste gewinnt, die zweite geht in die Notiz |
| Suche ueber alle Felder | `0160` findet Cosima, `moor` findet Editha |
| Kennung gegen Zeilennummer | Spalte **Name** anklicken zum Sortieren, dann eine Zeile waehlen |
| Ungespeicherte Aenderungen | Ort aendern, andere Zeile waehlen -> Rueckfrage |
| Filter und Auswahl | jemanden waehlen, dann `zzz` suchen -> Maske leert sich |
| Alles loeschen | Datei -> Alle Eintraege loeschen (legt vorher eine Sicherung an) |

## Alles erfunden, mit Absicht

Eine fruehere Fassung benutzte **echte Orte** und trug Spalten wie `KL`
und `Abitur` aus einem Klassentreffen-Zusammenhang. Beides ist fuer
Probedaten unbrauchbar: echte Orte sehen aus wie echte Daten, und
schulische Spalten gehoeren nicht in ein allgemeines Adressbuch.

Jetzt gilt durchgehend:

* **Orte**, die es nicht gibt: *Marbach am Nebel*, *Wendisch Aue*,
  *Sankt Ohlendorf*.
* **Postleitzahlen** `00001` bis `00007` -- in Deutschland nicht
  vergeben.
* **Rufnummern** mit fuehrender Doppelnull -- kommt in keiner echten vor.
* **`example.org`** ist fuer genau diesen Zweck reserviert (RFC 2606).
* **Namen** aus seltenen Bestandteilen, keine Kombination, die einer
  bestimmten Person zuzuordnen waere.
* **Keine Spalten** aus einem besonderen Anlass -- nur, was in jedem
  Adressbuch vorkommt.

## Weitere Quellen

`adressbuch::herkunft::zuordnung` ist eine Liste; eine neue Herkunft ist
ein Eintrag darin. Fuer eine Datei, die zu keinem Programm gehoert, geht
auch:

```tcl
adressbuch::csvLesen datei.csv -felder {name vorname ort}
```

## CardDAV -- Radicale, Nextcloud, SOGo

```tcl
adressbuch::davHolen https://server/dav/ \
        -pfad /adressen/ -user greg -password geheim
```

`tclutils::tudav` holt, `tclutils::tuvcard` liest. **Nur lesend** --
Zurueckschreiben hiesse, mit Etags und Konflikten umzugehen, und "wer
zuletzt schreibt, gewinnt" ist bei fremden Adressbuechern keine Antwort.

Geholt wird nur, was eine vCard ist (`.vcf` oder `text/vcard`). Eine
Sammlung enthaelt auch anderes; wer alles herunterlaedt, bekommt
HTML-Seiten als Adressen.

**Geprueft gegen einen echten Server**, nicht gegen eine Attrappe:
`dav-testserver.tcl` spricht so viel CardDAV, wie `davHolen` braucht --
PROPFIND mit Depth 1, GET auf die einzelnen Dateien. Eine nachgebaute
`tudav::get`-Prozedur wuerde nur messen, was man selbst hineinschreibt;
der Weg vom PROPFIND ueber die Multistatus-Antwort bis zur vCard bliebe
ungeprueft.

### Und gegen einen echten Radicale

Der Nachbau spricht nur so viel CardDAV, wie `davHolen` braucht. Ob es
mit einem RICHTIGEN Server geht, sagt nur ein richtiger Server --
**gemessen 12.09.2026 mit Radicale 3.8.0: ja.**

**Radicale muss nicht vorher installiert sein.** Fehlt es, legt das
Skript unter `/tmp/rad/venv` eine eigene Python-Umgebung an und
installiert es dort hinein.

Der Grund: Debian 13 und andere neuere Systeme schuetzen ihr Python --
`pip install radicale` bricht mit *externally-managed-environment* ab
(PEP 668). Die Fehlermeldung schlaegt `--break-system-packages` vor; das
heisst aber genau, was es sagt, und kann die Systeminstallation
beschaedigen. Eine eigene Umgebung ist der richtige Weg.

Braucht `python3-venv` -- unter Debian und Ubuntu:
`sudo apt install python3-venv`

```sh
sh radicale-testserver.sh /tmp/rad 5232
ADRESSBUCH_RADICALE=5232 tclsh adressbuch-dav.test
```

Ohne die Variable wird `dav-3.1` **uebersprungen**, nicht rot -- eine
fehlende Voraussetzung ist kein Fehlschlag.

**Drei Dinge, die beim Aufsetzen Zeit gekostet haben:**

* **Ohne Anmeldung geht gar nichts.** Mit `auth type = none` ist der
  Benutzer anonym, und jeder Pfad unter `/benutzer/` wird mit 401
  abgewiesen -- die Sammlung laesst sich nicht anlegen.
* **PROPFIND ohne `Content-Length` bleibt stehen.** Der Server wartet
  auf einen Rumpf, der nie kommt, und `curl` meldet `000` statt eines
  Fehlers.
* **Der Test darf den Server nicht selbst starten.** `exec sh start.sh`
  wartet auf alle Kindprozesse -- auch auf den, der absichtlich
  weiterlaeuft. Der Lauf blieb stehen.

Der Server laeuft **in einem eigenen Prozess**: im selben wartet der
Klient in seiner Ereignisschleife auf eine Antwort, die der Server erst
geben kann, wenn dieselbe Schleife ihn drankommen laesst. Gemessen: der
Aufruf blieb ohne Fehlermeldung stehen.
