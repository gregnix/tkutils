# Adressbuch

Ein Tcl/Tk-Adressbuch mit SQLite, CSV- und vCard-Import, CardDAV und
optionaler Verschluesselung -- **die ist derzeit abgeschaltet**, siehe
[Verschluesselung](#verschluesselung).

```
lib/tm/adressbuch/model-0.1.tm   das Modell -- ein Paket, ohne Tk
adressbuch.tcl                   die Oberflaeche
adressbuch-einstellungen.tcl     Einstellungen
dist/                            SQLite3MultipleCiphers je System/Fassung
beispiel*.csv                    Probedaten (siehe BEISPIEL.md)
```

```sh
wish adressbuch.tcl              # Vorgabedatei
wish adressbuch.tcl ~/meine.db   # oder ausdruecklich
```

Braucht `tclutils` (fuer `tucsv`, `tuvcard`, `tudav`) und `tablelist`.
Fehlt etwas, sagt die Meldung, wohin der Pfad gehoert.

---

## Inhalt

* [Das Modell als Paket](#das-modell-als-paket)
* [Wo was liegt](#wo-was-liegt)
* [Liste und Maske](#liste-und-maske)
* [Import: CSV, Outlook, Thunderbird](#import-csv-outlook-thunderbird)
* [CardDAV](#carddav)
* [Verschluesselung](#verschluesselung)
* [Alles loeschen](#alles-loeschen)
* [Einstellungen](#einstellungen)
* [Tests](#tests)
* [Offen und ungemessen](#offen-und-ungemessen)

---

## Das Modell als Paket

```tcl
::tcl::tm::path add /pfad/adressbuch/lib/tm
package require adressbuch::model

adressbuch::oeffnen ~/adressen.db
adressbuch::csvLesen kontakte.csv
adressbuch::vcardSchreiben adressen.vcf
```

**Ohne Tk brauchbar** -- wer nur Adressen umwandelt, braucht keine
Oberflaeche. Die Anwendung haengt `lib/tm` daneben selbst in die
Modulsuche: wer sie auspackt und startet, muss nichts setzen.

*Beim Umzug ins Paket zu beachten war:* `info script` zeigt jetzt auf
`lib/tm/adressbuch/model-0.1.tm`, nicht mehr auf die Anwendung. Die
Suche nach `dist/` nimmt deshalb zwei Wurzeln -- das Modulverzeichnis
und die Anwendung drei Ebenen darueber.

## Wo was liegt

**Daten** (`XDG_DATA_HOME`, nicht CONFIG -- es sind Daten):

```
$ADRESSBUCH_DB
$XDG_DATA_HOME/adressbuch/adressen.db
~/.local/share/adressbuch/adressen.db
%APPDATA%\adressbuch\
```

**Einstellungen** (`XDG_CONFIG_HOME`):

```
$ADRESSBUCH_CONF
$XDG_CONFIG_HOME/adressbuch/adressbuch.conf
~/Library/Preferences/adressbuch/     (macOS)
~/.config/adressbuch/
```

**Nicht ins Arbeitsverzeichnis.** Eine Vorgabe wie `adressen.db` legt
die Datei dort an, wo man gerade steht -- wer aus dem Projektbaum
startet, hat sie danach darin, und `git add -A` nimmt sie mit. Gemessen
an pdf4tcl: acht Demos, dreizehn Dateien im Baum (`ab-7.1`).

**Die Rechte:** eine neu angelegte Datei bekommt `0600`, ihr Verzeichnis
`0700` -- dieselbe Regel, die `sqledit-conn.tcl` fuer
Verbindungsprofile anwendet. Darin stehen Anschriften und Rufnummern
Dritter (`ab-7.3`). Bei einer **vorhandenen** Datei bleiben die Rechte,
wie sie sind.

**Datei -> Ordner der Datei oeffnen** bringt einen dorthin, ohne den
Pfad abzutippen. Ist kein Dateiverwalter da, wird der Pfad genannt statt
abzustuerzen (`gui-16.1`).

## Liste und Maske

Gebaut nach den Mustern aus `serie-liste-maske`:

| Muster | Kapitel |
|---|---|
| Die Kennung steht in `rowcget -name`, nicht in der Zeilennummer | `02-id-statt-zeile` |
| Auffrischen laedt neu, die Auswahl folgt der **Kennung** | `06-auswahl-behalten` |
| Beim Wechsel mit offenen Aenderungen wird gefragt | `09-ungespeichert` |
| Pflichtfeld leer: nicht speichern, und sagen welches | `10-validierung` |
| Faellt die Auswahl durch den Filter, leert sich die Maske | `14-filter-und-auswahl` |
| Nach dem Loeschen auf den naechsten, nicht ins Leere | `07-neu-und-loeschen` |
| Statuszeile zuerst packen, sonst wird sie gequetscht | `softwaredesign/14` |

**Die Suche geht ueber alle Felder**, nicht nur den Namen. Wer eine
Nummer im Kopf hat, sucht danach (`ab-1.2`).

*Zwei Fallen, beide gemessen:* die Auswahlbindung muss am **Widget**
haengen, nicht am Korpus -- sonst bleibt die Maske bei einem echten
Mausklick leer (`gui-8.1`). Und die Bildlaufleiste ist ein **Nachbar**
der Tabelle, kein Kind: als Kind bekommt sie keinen Platz, und zwei
Geometrieverwalter um denselben Platz lassen den Lauf haengen
(`gui-9.1`, `gui-9.2`).

**Rueckfragen sind abschaltbar** (`::ab::fragen 0`). Sonst haengt jeder
Test an einem `tk_messageBox`, das auf eine Antwort wartet, die niemand
gibt.

## Import: CSV, Outlook, Thunderbird

```
Datei -> CSV einlesen...       erkennt die Herkunft selbst
Datei -> CSV einlesen als      oder man sagt es ihr
```

| Herkunft | Kopfzeile |
|---|---|
| eigenes Format | ja |
| Outlook | ja |
| Thunderbird | **nein** |

**Thunderbird schreibt beim CSV-Export nur Werte, keine Kopfzeile.** Wer
eine erwartet, verliert den ersten Eintrag **und** ordnet alles falsch
zu (`ab-10.2`). Die Erkennung merkt es an der ersten Zeile: steht dort
eine E-Mail-Adresse oder etwas, das wie eine Rufnummer aussieht, ist es
keine Kopfzeile.

**CSV wird ueber die Kopfzeile gelesen**, nicht ueber Spaltennummern.
Wer eine Spalte einfuegt, verschiebt sonst alles dahinter -- und es
faellt erst auf, wenn Telefonnummern im Ortsfeld stehen (`ab-2.1`).

**Unbekannte Spalten gehen nicht verloren**, sondern sammeln sich mit
ihrem Spaltennamen in `notiz` (`ab-2.2`): `Company: Musterbetrieb GmbH`,
nicht nur der Wert. **Zwei Quellspalten auf ein Feld** -- Outlook hat
`Home Phone` und `Business Phone` -- die erste gewinnt, die zweite geht
ebenfalls in die Notiz (`ab-10.5`).

Fuer Dateien, die zu keinem Programm gehoeren:

```tcl
adressbuch::csvLesen datei.csv -felder {name vorname ort}
```

**Eine Eigenschaft von vCard, kein Fehler:** die Hausnummer wandert in
die Strasse. `ADR` kennt kein eigenes Feld dafuer (`ab-3.3`). Festnetz
und Mobil bleiben getrennt ueber `TEL;TYPE=voice` und `TEL;TYPE=cell`
(`ab-3.2`).

## CardDAV

**Datei -> Von CardDAV holen...**

```tcl
adressbuch::davHolen https://server/dav/ \
        -pfad /adressen/ -user greg -password geheim
```

Server, Pfad und Benutzer bleiben in den Einstellungen -- **das Kennwort
nicht** (`gui-11.1`). Eine Klartextdatei neben den Adressen mit dem
Zugang zum ganzen Server waere bequem und falsch.

**Abgleich, nicht blosses Holen.** Die erste Fassung hat nur geholt:
zweimal aufgerufen, war alles doppelt -- aus 2 Datensaetzen wurden 4.
Erkannt wird an der **vCard-UID**: zwei Menschen koennen gleich heissen,
eine UID gibt es einmal (`dav-4.1`).

**Nicht jede vCard hat eine UID** -- in vCard 3.0 ist sie nicht
vorgeschrieben, und Thunderbird-Exporte tragen oft keine. Dann dient der
**Pfad auf dem Server** als Ersatzschluessel.

**Voreingestellt wird nichts geloescht** (`dav-4.3`). Ein Abgleich, der
ungefragt loescht, ist gefaehrlich -- ein halb geantworteter Server oder
ein falscher Pfad wuerde das ganze Adressbuch leeren. Wer es will:
`-entfernen 1`.

**Nur lesend.** Zurueckschreiben hiesse, mit Etags und Konflikten
umzugehen; "wer zuletzt schreibt, gewinnt" ist bei fremden
Adressbuechern keine Antwort.

Zum Ausprobieren: `sh radicale-testserver.sh /tmp/rad 5232` -- siehe
BEISPIEL.md.

## Verschluesselung

> **ABGESCHALTET (Stand 19.09.2026) -- die Funktion ist noch nicht fertig.**
>
> Es wird keine Datei verschluesselt und kein Kennwort gesetzt oder
> geaendert: die Menuepunkte dafuer fehlen, und das Modell lehnt es ab
> (`ADRESSBUCH KRYPTO_AUS`) -- auch eine neue Datei mit Kennwort.
> **Einschalten nur im Code:** in `lib/tm/adressbuch/model-0.1.tm`
>
>     variable kryptoEin 0     ->   variable kryptoEin 1
>
> Bewusst kein Umgebungsschalter und keine Einstellung, und die Funktion
> kommt nicht schon dadurch zurueck, dass SQLite3MultipleCiphers gefunden
> wird.
>
> **Was immer geht:** eine schon verschluesselte Datei mit Kennwort oeffnen
> (die Abfrage beim Start bleibt) und mit *Datei -> Verschluesselung
> aufheben...* entschluesseln. Wer schon verschluesselt hat, kommt an seine
> Daten.
>
> Tests: Was verschluesselt, laeuft nur bei `kryptoEin 1`
> (Bedingung `kryptoEin`); Oeffnen, Erkennen und Aufheben einer
> verschluesselten Datei wird immer geprueft (`krypto-2.2`, `2.3`, `7.2`,
> `8.4`, `gui-14.*`), die Sperre selbst mit `aus-1.*` und `gui-16.*`.
> Was vor dem Einschalten noch fehlt, steht unter
> [Offen und ungemessen](#offen-und-ungemessen).

Der Rest dieses Abschnitts beschreibt die Funktion, wie sie mit
`kryptoEin 1` arbeitet.

Optional, ueber **SQLite3MultipleCiphers**.

Die steckt seit dem 12.09.2026 in einer **eigenstaendigen Bibliothek**
mit eigenem Baum, eigenen Bauskripten und eigenen Tests: `sqlite3mc/`.
Das Adressbuch sucht sie in dieser Reihenfolge:

```
1. package require sqlite3mc      steht sie im Suchpfad, wird sie genommen
2. $ADRESSBUCH_SQLITE3MC          ausdruecklich genannt
3. dist/<system>/tcl<fassung>/    mitgeliefert
4. gewoehnliche sqlite3           ohne Verschluesselung
```

Schritt 1 ist der saubere Weg:

```tcl
lappend auto_path /pfad/sqlite3mc/lib/linux/tcl9.0
package require sqlite3mc
```

**Warum ausgelagert:** zwei Kopien derselben Bibliothek driften
auseinander, und man erwischt die falsche. Wer sie schon hat, soll sie
benutzen koennen, ohne eine zweite im Adressbuch liegen zu haben.

Siehe `sqlite3mc/LIESMICH.md` und `BAUEN-sqlite3mc.md`.

```
Datei -> Verschluesseln / Kennwort aendern...
      -> Verschluesselung aufheben...
      -> Verschluesselung einrichten...
```

**Eine vorhandene Datei** laesst sich nicht einfach mit Kennwort
oeffnen -- das scheitert. Sie muss umgeschrieben werden:

```tcl
adressbuch::oeffnen ~/adressen.db      # wie bisher, ohne Kennwort
adressbuch::verschluesseln geheim      # schreibt die Datei um
adressbuch::oeffnen ~/adressen.db geheim
```

Dieselbe Prozedur aendert das Kennwort; ein **leeres** Kennwort hebt die
Verschluesselung auf (`gui-15.1`). Den Rueckweg muss es geben -- wer die
Datei weitergibt oder mit einem anderen Werkzeug oeffnet, braucht sie
offen.

**Vorher wird gesichert** (`krypto-8.2`) -- ein Abbruch mitten im
Umschreiben liesse sonst eine Datei zurueck, die weder mit altem noch
mit neuem Schluessel zu oeffnen ist. **Das Kennwort wird zweimal
abgefragt** (`gui-13.1`) und **nirgends gespeichert**.

**Beim Start** fragt die Anwendung nach dem Kennwort, bevor das
Hauptfenster kommt; drei Versuche (`gui-14.1` bis `14.3`). Vorher starb
sie mit `Error in startup script: file is not a database` -- daraus
konnte niemand ablesen, dass ein Kennwort fehlt. Das Modell
unterscheidet die Faelle jetzt:

```
ADRESSBUCH KENNWORT_FEHLT    Die Datei ist verschluesselt: ...
ADRESSBUCH KENNWORT_FALSCH   Falsches Kennwort fuer: ...
ADRESSBUCH KEINE_DATENBANK   Keine SQLite-Datei: ...
```

**Man sieht den Zustand**, statt ihn zu glauben:

```
[verschluesselt]  7 Eintraege
[offen]           3 Eintraege
```

**Hilfe -> Ueber...** nennt Tcl, SQLite, ob Verschluesselung moeglich
ist und woher sie kommt, Datei, Eintraege, Schema-Fassung und Zustand.
Ist die Datei offen, steht dort auch, was das heisst -- nicht bloss
"nein".

**Erkannt wird am DATEIKOPF**, nicht daran, ob ein Kennwort uebergeben
wurde (`krypto-7.1`). Wer eine alte offene Datei mit Kennwort oeffnet,
bekaeme sonst "verschluesselt" angezeigt -- und die Datei waere offen.

> **Die uebliche sqlite3-Anbindung luegt hier.** `db rekey` meldet
> Erfolg und verschluesselt nichts (`krypto-4.1`). Darum misst das
> Adressbuch, ob eine Probedatei wirklich unlesbar wird, statt nach dem
> Befehl zu fragen. **Ohne faehigen Bau wird ein Kennwort abgelehnt**
> (`krypto-3.1`), nicht stillschweigend uebergangen: eine ungeschuetzte
> Datei, die man fuer geschuetzt haelt, ist schlimmer als eine offen als
> ungeschuetzt bekannte.

## Alles loeschen

**Datei -> Alle Eintraege loeschen...** -- zwei Huerden statt einer: die
Rueckfrage nennt die **Zahl**, und ihre Vorgabe ist **Nein**.

**Vorher wird gesichert**, und der Pfad steht danach in der
Statuszeile -- wer eine Sicherung anlegt und nicht sagt wo, hat keine
angelegt. Danach laeuft `VACUUM`: sonst gibt man beim Weitergeben die
geloeschten Seiten mit. Bei leerer Datei wird gar nicht erst gefragt
(`gui-10.3`).

## Einstellungen

Fenstergroesse, Teilerstellung, Spaltenbreiten und die zuletzt
geoeffnete Datei werden **beim Beenden** gemerkt -- nicht bei jeder
Aenderung, das gaebe bei jedem Ziehen am Teiler einen Schreibvorgang.

**INI, nicht JSON.** Eine Einstellungsdatei soll man im Texteditor
aufmachen und verstehen koennen; JSON verzeiht kein fehlendes Komma und
kennt keine Kommentare. Fuer Daten gilt das Umgekehrte -- darum SQLite
fuer die Adressen.

```ini
# Einstellungen des Adressbuchs.
# Von Hand bearbeitbar.

[fenster]
breite=1024
hoehe=520
teiler=500
```

Drei Eigenschaften, alle geprueft:

* **Eine kaputte Datei verhindert den Start nicht** (`conf-2.1`). Wer
  sie von Hand bearbeitet und dabei etwas zerschossen hat, soll die
  Anwendung noch oeffnen koennen -- sonst kommt er nicht mehr an die
  Stelle, an der er es richten wuerde.
* **Unbekannte Schluessel werden uebergangen** (`conf-2.2`). Ein
  Tippfehler soll nicht als neue Einstellung erscheinen, die nichts tut.
* **Erst in eine Nebendatei, dann umbenennen** (`conf-3.1`). Sonst steht
  nach einem Abbruch eine halbe Datei da.

Und `breite = achthundert` faellt auf die Vorgabe zurueck, statt ein
Fenster der Groesse 0 zu ergeben (`conf-2.3`).

*Eine Falle beim Anschliessen:* der Teiler darf erst gesetzt werden,
wenn das Fenster eine Breite hat. `after idle` reicht **nicht** -- das
`panedwindow` stand da noch auf Breite 1, und `sashpos 0 500` rutschte
auf 0. Die Liste war weg.

## Tests

```
adressbuch.test        24 / 24     Modell, CSV-Herkuenfte
adressbuch-conf.test    9 /  9     Einstellungen
adressbuch-krypto.test 20 / 20 + 2 Verschluesselung
adressbuch-dav.test     8 /  8 + 1 CardDAV, Abgleich
adressbuch-gui.test    34 / 34     Oberflaeche
```

```sh
TCL9_0_TM_PATH=/pfad/tclutils/lib/tm:/pfad/tkutils/lib/tm \
    tclsh adressbuch.test
```

Die Uebersprungenen brauchen eine Voraussetzung, die nicht da ist -- ein
laufender Radicale (`ADRESSBUCH_RADICALE=5232`), oder das Gegenteil des
gerade vorhandenen Zustands.

**Jeder Test wurde gegengeprueft:** Behebung heraus, Test rot. Zwei
Faelle, in denen das misslang und der Test nachgebessert werden musste,
stehen in den Kommentaren -- ein Transaktionstest, dessen Attrappe gar
nichts einfuegte, und eine Hoehenpruefung an einem Fenster, das zu gross
war, um den Fall ueberhaupt zu zeigen.

## Offen und ungemessen

**Verschluesselung -- vor dem Einschalten (`kryptoEin 1`) zu klaeren**,
gefunden 19.09.2026:

* **Eine Klartext-Kopie bleibt liegen.** `verschluesseln` sichert die
  *offene* Datei nach `<datei>.<zeit>.vor-verschluesselung` (Rechte 0600)
  und laesst sie nach dem Umschluesseln stehen. Die Meldung nennt nur den
  Pfad, nicht dass die Kopie unverschluesselt ist. Wer verschluesselt, hat
  danach mehr ungeschuetzte Adressen auf der Platte als vorher. Mindestens:
  beim Namen nennen und nach erfolgreichem Umschluesseln das Loeschen
  anbieten -- mit dem Hinweis, dass Loeschen auf SSDs den Inhalt nicht
  sicher entfernt.
* **Beim Kennwortwechsel bleibt eine Kopie mit dem alten Kennwort.** Wer
  das Kennwort aendert, weil es bekannt geworden ist, laesst eine Datei
  zurueck, die mit dem alten weiter aufgeht.
* **Export im Klartext.** *Als CSV sichern* und *Als vCard sichern*
  schreiben die Adressen offen -- das sollte beim Export einer
  verschluesselten Datei gesagt werden.
* **`dist/` fehlt im Baum.** Oben als Suchort genannt; die gebauten
  Bibliotheken liegen derzeit nur in den Zips
  `adressbuch*_20260912_*.zip`. `krypto-9.1` bis `9.3` sind rot, weil
  neben der Bibliothek keine `pkgIndex.tcl` liegt (auch vor dem Abschalten
  so gemessen).

* Die Gegenprobe zum vCard-Filter in `davHolen` lief zweimal in die
  Zeitsperre und steht aus. Dass der Filter noetig ist, steht fest; dass
  `dav-1.2` ihn faengt, ist nicht bewiesen.
* `dist/win/tcl9.0/sqlite3mc.dll` ist quer gebaut und **nicht unter
  Windows geprueft**. macOS fehlt ganz.
* Etiketten ueber `pdf4tcl`.
* Die Nebentabellen fuer Schuljahre und Mailhistorie aus dem
  Mitschueler-Schema -- hier ist erst die Person abgebildet.
* CardDAV nur lesend.
