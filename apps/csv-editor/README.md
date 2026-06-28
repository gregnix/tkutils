# CSV Editor (auf tkutils)

Ein kleiner CSV-Tabelleneditor: laden, Zellen bearbeiten, Zeilen/Spalten
hinzufuegen/loeschen/umbenennen, sortieren und speichern. Baut auf der
tkutils-Widget-Familie auf.

## Starten

```bash
wish csv_editor.tcl ?datei.csv?
```

Benoetigt Tcl/Tk 8.6+ (inkl. 9.x), **tkutils 0.26.0+**, **tclutils 0.37.0+**
sowie das **Tablelist**-Megawidget (aus tklib, z. B. `apt install tklib`), da
der Editor `tktablelist` verwendet. Fehlt Tablelist, zeigt der Editor beim Start
eine klare Meldung und beendet sich (kein stiller Absturz).

Bibliotheken werden ueber `TKUTILS_TM` / `TCLUTILS_TM`, ueber
`source ../tkutils-0.26.0/tools/setup.tcl` oder ueber Geschwister-Ordner neben
dem Tool gefunden; Tablelist muss auf dem `auto_path` liegen.

## CSV-Optionen

In der Optionsleiste lassen sich vor dem Oeffnen/Speichern einstellen:

- **Encoding** — utf-8, cp1252, iso8859-1, ascii (wichtig fuer deutsche Dateien). Ein
  UTF-8-BOM am Dateianfang wird automatisch entfernt.
- **Delimiter** — Comma (`,`), Semicolon (`;`), Tab oder **Space**. Im
  Space-Modus wird jede Zeile am **ersten** Leerzeichen in zwei Spalten geteilt
  (z. B. `mm/dd/yyyy Beschreibung`), damit Beschreibungen mit Leerzeichen heil
  bleiben.
- **Header row** — erste Zeile als Spaltenkopf behandeln (an/aus).
- **Skip # comments** — Zeilen, die mit `#` beginnen, beim Laden ueberspringen.

Ohne Header werden Spalten automatisch als `Column1`, `Column2`, … benannt.
Ein Beispiel im Space-Format liegt unter `examples/feiertage.csv`.
Gelesen/geschrieben wird ueber `tclutils::tucsv` mit den gewaehlten Optionen.

## Was aus tkutils/tclutils verwendet wird

- `tktablelist` – die editierbare, sortierbare Tabelle.
- `tktoolbar` – Symbolleiste (Open, Save, Add Row, Delete Row, Add Column).
- `tkstatus` – Statusleiste mit "Zeilen x Spalten"-Feld und Save-`flash`.
- `tkdialog` – Bestaetigungen, Warnungen und Formular-Dialoge (Spalten).
- `tclutils::tucsv` – CSV parsen/schreiben (Delimiter/Quote).

## Bedienung

**Menue:** File (New, Open, Save, Save As, Exit), Edit (Add Row, Delete Row(s),
Add/Rename/Delete Column).

- Doppelklick auf eine Zelle bearbeitet sie; Klick auf einen Spaltenkopf sortiert.
- Mehrfachauswahl (Shift/Ctrl) fuer "Delete Row(s)".
- Ungespeicherte Aenderungen: `*` im Titel; New/Open/Exit und das Schliessen
  ueber das Fenster-X (`WM_DELETE_WINDOW`) fragen nach.

### Tastenkuerzel

| Kuerzel | Aktion |
|:--------|:-------|
| `Ctrl+N` | Neu |
| `Ctrl+O` | Oeffnen |
| `Ctrl+S` | Speichern |
| `Insert` | Zeile hinzufuegen |
| `Del` | Ausgewaehlte Zeile(n) loeschen |

## Tests

Headless-Smoke- und Datenoperations-Tests unter `tests/csv_editor.test`
(Constraint `tablelist` — wird ohne Tablelist sauber uebersprungen):

```bash
export TCLUTILS_TM=$PWD/../tclutils-0.37.0/lib/tm
export TKUTILS_TM=$PWD/../tkutils-0.26.0/lib/tm
xvfb-run -a tclsh tests/csv_editor.test
```

Geprueft werden Load/Save-Round-Trips (Delimiter, Encoding mit Umlauten,
Header an/aus), Spalten hinzufuegen/umbenennen/loeschen (inkl. Index-Guard) und
Zeilen hinzufuegen/loeschen. Auf Tcl/Tk 8.6 mit Tablelist 6.20: 7/7 gruen.

## Lizenz

MIT — siehe [LICENSE](LICENSE).

## Robustheit

Geladen wird ueber `tucsv` (RFC-4180-konform: Quotes, Trenner und
Zeilenumbrueche **innerhalb** von Feldern, `""`-Escapes). Defekte Dateien mit
nicht geschlossenen Quotes werden tolerant geladen (`-strict 0`) statt mit einem
Fehler abzubrechen.

## DATEV / ragged rows

DATEV-Stammdaten-Exporte sind Semikolon-getrennt (oft UTF-8 oder CP1252) und
koennen **unterschiedlich breite Zeilen** haben (Datenzeilen mit mehr Feldern als
die Kopfzeile). Beim Laden wird die Spaltenzahl auf die **breiteste** Zeile
erweitert (zusaetzliche Spalten heissen `Column<N>`), sodass keine
Feldinhalte verloren gehen; zu kurze Zeilen werden mit Leerfeldern aufgefuellt.
Geprueft mit einer 254-Spalten-DATEV-Datei (Round-Trip stabil) und Performance
mit 10.000 Zeilen sowie einem 500.000-Zeichen-Feld.
