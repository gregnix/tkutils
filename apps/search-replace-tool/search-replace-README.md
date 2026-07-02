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

Headless (ohne Tk), baut einen eigenen Fixture-Baum:

```bash
tclsh tests/search_replace.test
```

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

Kernlogik 11/11 und GUI-Smoke (Suche, Vorschau, Treffer-Markierung, Multiline-
Umschaltung) erfolgreich unter Xvfb auf Tcl/Tk **8.6** und **9.0.2**.
