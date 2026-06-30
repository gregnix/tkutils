# Tcl/Tk Developer Toolbox (tkdevtools)

Ein eigenstaendiger Nachschlage-/Spielwiesen-Browser fuer Tk-Entwicklung:
die Referenz-Tabellen und Cheat-Sheets, die man beim GUI-Bauen staendig
braucht, gebuendelt in einer App mit Navigationsbaum. Reine Anzeige/Probe —
es werden keine Dateien geschrieben.

## Starten

```bash
wish tkdevtools.tcl
```

Screenshot-Modus (rendert einen Tab und beendet sich):

```bash
tclsh tkdevtools.tcl --shot out.png ?toolKey?      # z. B. themes, colors, regexp
```

Benoetigt Tcl/Tk 8.6+ (inkl. 9.x), **tclutils** (`tclutils::tucolor`) und das
**Tablelist**-Megawidget (aus tklib, z. B. `apt install tklib`). Die
tkutils-Tabellen-Helfer `tkutlsort` / `tkutlfind` / `tkutlclip` werden, falls
vorhanden, fuer Spaltensortierung, Inkrementalsuche und Clipboard-Export
genutzt; fehlen sie, laeuft die App ohne diese Komfortfunktionen weiter.

Die Bibliotheken werden ueber den gemeinsamen Bootstrap `../_lib/paths.tcl`
gefunden (`TCLUTILS_TM`/`TKUTILS_TM`, Install-/share-/XDG-Pfade oder ein
Geschwister-Checkout) — wie bei den anderen Apps, kein manuelles `export`
noetig. Tablelist muss auf dem `auto_path` liegen.

## Was es zeigt

**Reference**
- **Colors** — die benannte Farbdatenbank (`tclutils::tucolor`): Name, Hex,
  RGB, HSV, mit Farb-Swatch und Filter.
- **Characters** — Codepage-/Unicode-Zeichentabelle fuer waehlbare Bereiche
  (ASCII, Latin-1, Currency, Box-drawing, Arrows): Zeichen, `\u`, `U+`, Dez, Hex.
- **Fonts** — Font-Familien durchsuchen, Groesse/Bold/Italic/Underline
  einstellen, Live-Vorschau plus Metriken und fertiger `font create`-Spec.
- **Bitmaps** — die eingebauten Tk-Bitmaps (`-bitmap`).

**Conversion / time**
- **Units** — Bildschirm-DPI und Umrechnung px/pt/mm/cm/inch (`winfo fpixels`).
- **Timezones** — Weltzeitzonen mit live tickender Uhr, Datum, UTC-Offset, Abk.
- **clock format** — `clock format`-Codes mit Bedeutung und Live-Beispiel.

**Tk widgets / style**
- **Cursors** — alle Cursor-Namen mit Vorschaufeld.
- **Relief / Anchor** — Cheat-Sheet fuer `-relief`, `-anchor`, `-justify`.
- **Keysym probe** — Tasten druecken und Keysym/Char/Keycode/State ablesen.
- **ttk Themes** — Theme-/Element-Baum, Widget-Galerie als Vorschau und ein
  Style-Inspektor (configure + map als Tabelle, layout als Baum).
- **Widget explorer** — fuer einen Widget-Typ alle Optionen mit Default/Current.

**Layout**
- **pack** / **grid** — interaktive Spielwiesen, die den jeweiligen
  Geometry-Manager-Befehl mitschreiben.

**Text / patterns**
- **regexp** — Muster + Subjekt live testen (Flags, Inline-Matches, regsub).
- **format / scan** — `format`/`scan` testen plus Konvertierungs-Cheat-Sheet.
- **Encodings** — fuer eine Kodierung die Bytes eines Beispieltexts (hex).
- **Virtual events** — definierte virtuelle Events und ihre physischen Bindungen.

## Lizenz

MIT — siehe [LICENSE](LICENSE).
