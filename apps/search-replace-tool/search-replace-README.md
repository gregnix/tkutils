# Such- und Ersetzen-Tool (auf tkutils)

Rekursive Datei-Suche/-Ersetzung mit Treeview-Ergebnissen, Inhaltsvorschau
(Zeilennummern, farbig markierte Treffer), Encoding-Auswahl mit iso8859-1-
Fallback und Multiline-Suche. Umsetzung der beiliegenden Spezifikation
(`search_replace_tool_doku.md`) als lauffähiges Werkzeug auf Basis von **tkutils**.

## Starten

```bash
wish search_replace_tool.tcl
```

Benötigt Tcl/Tk 8.6+ (inkl. 9.x) sowie die Bibliotheken **tkutils** und
**tclutils**. Das Tool findet sie automatisch, wenn

- die Umgebungsvariablen `TKUTILS_TM` / `TCLUTILS_TM` auf das jeweilige
  `lib/tm`-Verzeichnis zeigen, **oder**
- die entpackten `tkutils-*` / `tclutils-*`-Ordner neben dem Tool (oder im
  übergeordneten Verzeichnis) liegen.

## Was aus tkutils verwendet wird

- `tktoolbar` – die Aktionsleiste (Suchen, Abbrechen, Alle ersetzen,
  Ausgewaehlte ersetzen, Leeren). Waehrend einer laufenden Suche ist nur
  **Abbrechen** aktiv.
- `tkstatus` – die Statusleiste mit Trefferanzahl-Feld, laufendem Fortschritt
  (`i/N Dateien, K Treffer`) und `flash`-Meldung nach dem Ersetzen.
- `tkdialog` – Bestaetigungs- und Warn-/Fehlerdialoge (`confirm`,
  `showWarning`, `showError`).

Treeview, Vorschau-Text (mit Zeilennummern) und das geteilte Panedwindow sind
Standard-`ttk`/Tk. Datei-I/O erfolgt mit Encoding und iso8859-1-Fallback.

## Architektur

Die Such-/Ersetzlogik ist **Tk-frei** (Namespace `::srtool`, Prozeduren
`searchDir`, `searchFile`, `replaceInFile`, `collectFiles`, …) und damit ohne
Display testbar. Die GUI wird nur gebaut, wenn die Datei als Hauptskript
gestartet wird; beim `source` (z. B. im Test) bleibt sie aus.

- Einzeilige Suche: zeilenweise mit `string first` bzw. `regexp`.
- Mehrzeilige Suche: auf dem gesamten Inhalt; Trefferposition wird in
  Zeilennummern umgerechnet (Bereich `N-M`). Wird automatisch aktiviert, sobald
  der Suchtext einen Zeilenumbruch enthaelt.
- Ersetzen (nicht-Regex): Sonderzeichen werden literal behandelt; Gross/Klein
  ueber `-nocase`.
- Uebersprungen werden Verzeichnisse mit fuehrendem `.` sowie `__pycache__`.

## Tests

Headless (ohne Tk), beide bauen einen eigenen Fixture-Baum:

```bash
tclsh tests/search_replace.test    # 19 Tests -- Suchen, Ersetzen, Filter
tclsh tests/test_safe.test         # 11 Tests -- was Dateien beschädigen konnte
wish  tests/test_gui.test          # 27 Tests -- was man sieht (braucht Display)
```

`test_safe.test` deckt die vier Stellen ab, an denen das Werkzeug still
Schaden anrichten konnte: Binärdateien, Zeilenenden, Encoding-Rückfall
und übersprungene Verzeichnisse. Zu jeder gibt es die Gegenprobe, dass
sie rot wird, wenn der Schutz fehlt.

## Nach Datum filtern

Die Felder **Geaendert: von / bis** (Format `JJJJ-MM-TT`, beide optional)
grenzen die Suche auf Dateien mit passendem **Aenderungsdatum** (mtime) ein.
`von` ist ab 00:00 des Tages, `bis` ist **tagesinklusive** (bis 23:59 des Tages).
Der Filter gilt fuer beide Modi – Inhalts- und Dateinamen-Suche – und laesst
sich mit ihnen kombinieren (z. B. *Nur Dateinamen* + Zeitraum = „welche Dateien
wurden im Zeitraum geaendert"). Ein ungueltiges Datum meldet einen Hinweis;
leere Felder bedeuten „keine Grenze".

## Nur Dateinamen suchen

Mit der Option **Nur Dateinamen** sucht das Tool ausschliesslich nach
**Dateinamen** – der Inhalt wird nicht gelesen. Der Suchtext wird gegen den
Dateinamen (ohne Pfad) geprueft (Teilstring bzw. Regex, je nach Optionen); ein
**leerer Suchtext listet alle** Dateien, die auf das Dateimuster passen. Die
Ergebnisse erscheinen als Dateiliste ohne Treffer-Zeilen; das Ersetzen ist in
diesem Modus deaktiviert (es gibt keinen Inhalt zu ersetzen).

Beispiel: Dateimuster `*.tcl`, Suchtext `test`, Option *Nur Dateinamen* an →
alle `*.tcl`-Dateien, deren Name `test` enthaelt.

## Responsive Suche & Abbruch

Die Suche laeuft **inkrementell**: Dateien werden nacheinander durchsucht, die
Statuszeile zeigt den Fortschritt (`i/N Dateien, K Treffer`), und die
Oberflaeche bleibt bedienbar. Ueber **Abbrechen** (oder `Esc`) laesst sich ein
laufender Durchlauf jederzeit stoppen; die bis dahin gefundenen Treffer bleiben
erhalten und werden angezeigt.

## Backup beim Ersetzen

Die Option **Backup (.bak)** legt vor dem Ueberschreiben einer Datei eine
unveraenderte Kopie `<datei>.bak` an (exakte Kopie des Originals). Damit laesst
sich eine Ersetzung von Hand rueckgaengig machen.

## Bewusste Vereinfachung

"Ausgewaehlte ersetzen" arbeitet auf **Datei-Granularitaet**: ersetzt werden
alle Treffer in den Dateien, von denen ein Knoten (Datei oder Treffer) markiert
ist. Eine Ersetzung einzelner Vorkommen innerhalb einer Datei ist nicht
implementiert. Ersetzungen selbst sind nicht per Undo rueckgaengig zu machen –
dafuer die Option **Backup (.bak)** aktivieren (siehe oben).

## Verifiziert

Kernlogik 19/19 und GUI-Smoke (Suche, Vorschau, Treffer-Markierung, Multiline-
Umschaltung) erfolgreich unter Xvfb auf Tcl/Tk **8.6** und **9.0.2**.

## Was sich am 30.08.2026 geändert hat

Vier Stellen, an denen das Werkzeug **Dateien beschädigen** konnte —
alle vier still, keine davon in der bestehenden Suite.

**Binärdateien.** Eine Datei mit Nullbytes wurde durchsucht wie Text,
stand damit in der Trefferliste und wurde von *Alle ersetzen*
überschrieben. Jetzt: nicht durchsucht (`Binärdateien einbeziehen`
schaltet es an, denn Suchen ist lesend) und **nie** beschrieben.

**Zeilenenden.** `writeFileEnc` setzte immer `-translation lf`. Eine
CRLF-Datei kam als LF zurück — eine Änderung an jeder Zeile, die niemand
angefordert hat. Jetzt wird mit den Zeilenenden geschrieben, mit denen
gelesen wurde.

**Encoding.** Der Rückfall auf `iso8859-1` beim Lesen war unsichtbar,
geschrieben wurde danach mit dem *gewählten* Encoding. Jetzt mit dem
tatsächlich gelesenen, und die Zahl der betroffenen Dateien steht in der
Hinweiszeile.

**Verzeichnisse.** `node_modules`, `build`, `dist`, `target`, `vendor`
und Verwandte werden übersprungen. Vorher nur Punkt-Verzeichnisse und
`__pycache__` — gemessen lief `node_modules` voll mit.

Dazu:

- **Backup ist Vorgabe an.** Der Bestätigungsdialog sagt „kann nicht
  rückgängig gemacht werden"; dann soll die Sicherung nicht an einem
  Haken hängen, den man vergessen kann.
- **Ein ungültiger regulärer Ausdruck** ergab null Treffer ohne ein Wort.
  Jetzt eine Meldung, einmal je Suche.
- **Mehrzeilig übernimmt den Inhalt.** Wer einzeilig tippte und dann
  umschaltete, suchte mit leerem Text.
- **Esc im Ruhezustand** fragt nach, statt die Trefferliste wortlos zu
  leeren.
- **Schalter in zwei Reihen** — die sieben brauchten 866 px nebeneinander
  und fielen unter 900 px Fensterbreite aus dem Fenster. Obere Reihe:
  was die Suche bestimmt. Untere: was beim Ersetzen passiert.
## Was man nach der Suche sieht

**Der erste Treffer ist gewählt und die Vorschau gefüllt.** Vorher blieb
die rechte Hälfte weiß, bis jemand einen Knoten anklickte — wer nicht
wusste, dass ein Klick die Datei lädt, sah nur die abgeschnittene Spalte
*Treffer* und hielt die Suche für ergebnislos.

**F3 / Shift+F3** gehen weiter und zurück und laufen um. Die Statusleiste
hat ein eigenes Feld `Treffer k/N`.

**Der Baum wächst während der Suche**, nicht erst danach. Dazu ein
Fortschritt über `tkustatus::progress`. Bei einem großen Verzeichnis sah
man vorher minutenlang nichts als eine Zahl.

**Die Vorschau zeigt die Umgebung der Trefferzeile**, nicht die ganze
Datei. Gemessen an 200000 Zeilen (5 MB):

```
vorher   1596 ms, 200002 Zeilen im Widget -- bei JEDEM Klick auf einen Treffer
jetzt     204 ms,    405 Zeilen
```

Die Zeilennummern bleiben die **echten** — eine Vorschau, die bei 1 zu
zählen anfängt, während der Treffer in Zeile 4711 steht, ist schlimmer
als keine. Oben und unten steht, was weggelassen wurde, und die
Hinweiszeile nennt den Bereich. Die ganze Datei gibt es im eingebauten
Editor; die Vorschau ist zum Hinsehen da, nicht zum Lesen.

### Rechte Maustaste

Drei Kontextmenüs statt einem.

**Im Baum** — und der Rechtsklick **wählt jetzt den Knoten unter dem
Zeiger**. Vorher tat er das nicht: das Menü wirkte auf die vorherige
Auswahl. Wer auf eine andere Datei rechtsklickte und *Im Editor öffnen*
wählte, bekam die alte — und beim Kopieren den falschen Pfad in der
Zwischenablage, ohne es zu merken.

| | |
|---|---|
| Vollen Pfad kopieren | `/pfad/zur/datei.tcl` |
| Dateinamen kopieren | `datei.tcl` |
| Trefferzeile kopieren | `/pfad/zur/datei.tcl:42: der gefundene Text` |
| Alle Treffer kopieren | dieselbe Form, eine Zeile je Treffer |

**In der Vorschau** — Auswahl, Zeile oder alles kopieren, alles
markieren. Es gab dort gar keins: man sah den Fund und konnte ihn nicht
mitnehmen, bei einem Werkzeug, das zum Finden da ist.

**In den Eingabefeldern** — Ausschneiden, Kopieren, Einfügen, alles
markieren. Tk kann das über die Standardbindungen, aber ohne Menü findet
es nur, wer die Tastenkürzel kennt.

Ein **leerer Text landet nicht** in der Zwischenablage — sonst leert ein
Fehlgriff sie, und was vorher drin war, ist weg. Was kopiert wurde, sagt
die Statuszeile.

### Lange Pfade

Das war der Hauptmangel der Ergebnisanzeige. Vier Dinge zusammen:

**Der Pfad steht relativ zur Suchwurzel.** Bei
`/home/greg/Project/2026/code/git/github/…` ist der Anfang bei allen
Knoten gleich und frisst die Spalte.

**Die Pfadspalte wird nicht gequetscht** (`-stretch 0`, 340 px). Vorher
teilten sich Pfad und Trefferspalte den Platz, und bei einem langen Pfad
blieb von beidem nichts. Die Trefferspalte nimmt jetzt den Rest.

**Ein Horizontal-Rollbalken.** Ohne ihn war ein abgeschnittener Pfad
endgültig weg — man konnte nicht einmal hinsehen.

**Der volle Pfad steht unter dem Baum**, samt Zeilennummer. Wer wissen
will, *wo* die Datei liegt, soll nicht raten müssen; eine Zeile, die
immer da ist, ist besser als ein Tooltip, den man erst treffen muss.

Dazu: der Ordnerknoten zählt seine Treffer, eine Trefferzeile zeigt ihre
Zeilennummer in Spalte `#0` (dort war vorher nur Einrückung), und die
Trefferzeilen sind **nicht mehr dunkelrot** — die Auswahl färbt den
Hintergrund blau, und Rot darauf ist kaum zu lesen. Die *Stelle* ist im
Vorschaufenster gelb markiert, dort, wo man hinsieht.

- **Statusleiste bleibt sichtbar.** Sie war beim Umbau auf 1 px
  geschrumpft, weil `pack` in Aufrufreihenfolge verteilt und die
  Ergebnisfläche sich den Platz vorher nahm.
