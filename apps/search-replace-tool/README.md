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

- `tktoolbar` – die Aktionsleiste (Suchen, Alle ersetzen, Ausgewaehlte
  ersetzen, Leeren).
- `tkstatus` – die Statusleiste mit Trefferanzahl-Feld und `flash`-Meldung
  nach dem Ersetzen.
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

Headless (ohne Tk), baut einen eigenen Fixture-Baum:

```bash
tclsh tests/search_replace.test
```

## Bewusste Vereinfachung

"Ausgewaehlte ersetzen" arbeitet auf **Datei-Granularitaet**: ersetzt werden
alle Treffer in den Dateien, von denen ein Knoten (Datei oder Treffer) markiert
ist. Eine Ersetzung einzelner Vorkommen innerhalb einer Datei ist nicht
implementiert. Ersetzungen sind nicht rueckgaengig zu machen – vorher Backup.

## Verifiziert

Kernlogik 11/11 und GUI-Smoke (Suche, Vorschau, Treffer-Markierung, Multiline-
Umschaltung) erfolgreich unter Xvfb auf Tcl/Tk **8.6** und **9.0.2**.
