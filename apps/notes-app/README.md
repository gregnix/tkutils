# Notes (auf tkutils)

Eine kleine, vollstaendige Notiz-App fuer hierarchische Notizen mit Baum,
Editor, Datei-Persistenz (JSON) und Verschieben im Baum. Baut komplett auf der
tkutils-Widget-Familie auf.

## Starten

```bash
wish notes_app.tcl ?notes.json?
```

Benoetigt Tcl/Tk 8.6+ (inkl. 9.x), **tkutils 0.26.0+** und **tclutils 0.35.0+**.
Die Bibliotheken werden automatisch gefunden, wenn `TKUTILS_TM` / `TCLUTILS_TM`
auf das jeweilige `lib/tm` zeigen oder die entpackten `tkutils-*` / `tclutils-*`
Ordner neben dem Tool (oder im uebergeordneten Verzeichnis) liegen.

## Was aus tkutils/tclutils verwendet wird

- `tknotes` (mit `-toolbar 0`) – Baum + Title/Tags/Content-Editor; die App liefert
  die Steuerung selbst.
- `tktoolbar` – die App-Symbolleiste (New Root, New Child, Delete, Save, Expand,
  Collapse).
- `tkstatus` – Statusleiste mit Notizzahl-Feld, Pfadanzeige der Auswahl und
  `flash`-Meldung nach dem Speichern.
- `tkdialog` – Bestaetigungs-/Warn-/Fehlerdialoge.
- `tclutils::tunotes` – die gesamte Notiz-Logik und JSON-Persistenz (ueber
  tknotes; fuer den Move-Dialog liest die App den Store direkt aus).

## Bedienung

**Menue:** File (New, Open, Save, Save As, Exit), Edit (New Root/Child, Save Note,
Delete mit/ohne Kinder, Move to Root, Move under...), View (Expand/Collapse All,
Refresh).

**Editor:** Titel und Tags (leerzeichengetrennt) als Felder, Inhalt als Textfeld.
"Save Note" bzw. **Save** uebernimmt die Editorfelder in den Store (commit) und
schreibt anschliessend die Datei.

**Move under...** oeffnet einen Dialog mit allen moeglichen Ziel-Notizen
(eingerueckt nach Tiefe; die Notiz selbst und ihre Nachfahren sind
ausgeschlossen, Zyklen werden verhindert).

### Tastenkuerzel

| Kuerzel | Aktion |
|:--------|:-------|
| `Ctrl+N` | Neue Wurzel-Notiz |
| `Ctrl+Shift+N` | Neue Unter-Notiz |
| `Ctrl+S` | Speichern |
| `Ctrl+O` | Oeffnen |
| `Del` | Notiz loeschen (mit Kindern) |
| `F5` | Aktualisieren |

## Datenformat

Notizen werden als JSON-Objekt `id -> {id parent_id title content created
modified tags}` gespeichert (erzeugt/gelesen von `tclutils::tunotes` ueber
`tclutils::tujson`, keine externen Pakete).

## Hinweise

- "Delete (with children)" loescht den Teilbaum; "Delete (keep children)"
  haengt die direkten Kinder an die Wurzel um.
- Ungespeicherte Aenderungen werden im Fenstertitel mit `*` markiert; New/Open/
  Exit fragen bei ungespeicherten Aenderungen nach.

## Verifiziert

GUI-Smoke (New Root/Child, Commit, Save/Open, Move-to-Root, Kandidatenliste,
Expand/Collapse, Statusaktualisierung) erfolgreich unter Xvfb auf Tcl/Tk **8.6**
und **9.0.2**.

## Tests

Headless-Smoke-Test (kein Tablelist noetig) unter `tests/smoke.tcl`
(Constraint `notes` — ohne Tk/tunotes sauber uebersprungen):

```bash
export TCLUTILS_TM=$PWD/../tclutils-0.35.0/lib/tm
export TKUTILS_TM=$PWD/../tkutils-0.26.0/lib/tm
xvfb-run -a tclsh tests/smoke.tcl
```

Geprueft: neue Wurzel-/Kindnotiz, Save/New/Open-Round-Trip, Expand/Collapse.
Auf Tcl/Tk 8.6 und 9.0.2: 4/4 gruen.

Das Schliessen ueber das Fenster-X (`WM_DELETE_WINDOW`) fragt bei
ungespeicherten Aenderungen nach.

## Lizenz

MIT — siehe [LICENSE](LICENSE).
