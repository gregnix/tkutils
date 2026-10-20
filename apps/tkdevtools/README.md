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

Benoetigt Tcl/Tk 8.6+ (inkl. 9.x), **tclutils 0.64.0 oder neuer** (aktuell 0.66.0) (`tucolor`, `tustr`,
`tudate`, `tupkgfinder` 0.2, `tuappinfo`, `tupath`, `tunum` 0.4), aus tkutils `tkutablelist` 0.4 und
`tkuunits`, und das **Tablelist**-Megawidget (aus tklib, z. B.
`apt install tklib`). Die
tkutils-Tabellen-Helfer `tkutlsort` / `tkutlfind` / `tkutlclip` werden, falls
vorhanden, fuer Spaltensortierung, Inkrementalsuche und Clipboard-Export
genutzt; fehlen sie, laeuft die App ohne diese Komfortfunktionen weiter.

Die Bibliotheken werden ueber den gemeinsamen Bootstrap `../_lib/paths.tcl`
gefunden (`TCLUTILS_TM`/`TKUTILS_TM`, Install-/share-/XDG-Pfade oder ein
Geschwister-Checkout) — wie bei den anderen Apps, kein manuelles `export`
noetig. Tablelist muss auf dem `auto_path` liegen.

## Was es zeigt

**Runtime**
- **Tcl / Tk** — Patchlevel, Windowing-System, Libraries, Encoding, Platform,
  ttk-Themes, Thread/zipfs wenn vorhanden.
- **OS / platform** — Hostname, `uname`, Desktop-/Locale-Env, optional
  `nproc`/`free`/`df` (Unix).
- **Packages** — bekannte Pakete mit geladener Version, Versionsliste und
  `ifneeded`-Quelle; Filter und „loaded only“.
- **Package shadows** — jede Kopie eines Pakets in Modulpfaden und
  `auto_path` (`tupkgfinder::shadows`). Rot: eine zweite Kopie derselben
  Version, die nie geladen wird -- etwa eine Installation neben dem
  Arbeitsbaum. Welche gewinnt, haengt von der Pfadreihenfolge ab.
- **Paths** — `auto_path`, `tcl_pkgPath`, `tcl::tm::path`, Encoding-Dirs.
- **Display** — Bildschirmgroesse, DPI/`tk scaling`, Pointer, Img-Pakete.
- **Environment** — filterbare `::env`-Tabelle.
- **Channels** — offene Channels mit Typ/Encoding/`chan configure`.
- **Photo formats** — Img-/Core-Formate listen, per Button laden, 1×1-Probe.
- **External tools** — tkcon (embed/Prozess), tkinspect, Tk-`widget`-Demo.

**Reference**
- **Colors** — die benannte Farbdatenbank (`tclutils::tucolor`): Name, Hex,
  RGB, HSV, mit Farb-Swatch und Filter.
- **Characters** — Codepage-/Unicode-Zeichentabelle fuer waehlbare Bereiche
  (ASCII, Latin-1, Currency, Box-drawing, Arrows): Zeichen, `\u`, `U+`, Dez, Hex.
- **Fonts** — Font-Familien durchsuchen, Groesse/Bold/Italic/Underline
  einstellen, Live-Vorschau plus Metriken und fertiger `font create`-Spec.
- **Bitmaps** — die eingebauten Tk-Bitmaps (`-bitmap`).
- **Graphemes** — vereinfachte UAX-#29-Cluster vs. Codepoints.
- **Font aliases** — was Tk aus Helvetica, Times, Courier, Arial und den
  `Tk*Font`-Namen macht (Familie, Groesse, Metriken). Gelb: der Name kommt
  unveraendert zurueck (Tk 9 unter Windows bei Helvetica) und kann in einem
  PDF-Export mit der gleichnamigen Standardschrift zusammenfallen.

**Conversion / time**
- **Units** — Bildschirm-DPI und Umrechnung px/pt/mm/cm/inch (`winfo fpixels`).
- **Timezones** — Weltzeitzonen mit live tickender Uhr, Datum, UTC-Offset, Abk.
- **clock format** — `clock format`-Codes mit Bedeutung und Live-Beispiel.
- **Number format** — dieselben Werte mit `format %.Nf` (Rundung der
  C-Laufzeit, glibc und Windows unterscheiden sich bei x,5) und
  `tunum::format` (kaufmaennisch, 0,5 weg von null), dazu der gespeicherte
  double-Wert.

**Platform**
- **Paths** — `file pathtype`/`split`/`dirname`/`normalize`/`nativename`
  und `tupath::clean` fuer einen Pfad, dazu die Einordnung nach Windows- und
  Unix-Regeln (`/x` und `C:x` sind unter Windows volumerelative).
- **glob** — was ein Muster in einem Verzeichnis trifft, mit `-types`.
  Zeigt, wie viele Punkt-Dateien `*` hier auslaesst; unter Windows trifft
  `*` sie, und `*` plus `.*` liefert sie doppelt.
- **Programs** — `auto_execok` fuer einen Namen und die PATH-Eintraege mit
  Treffern; Trennzeichen und unter Windows PATHEXT.
- **Encoding profiles** — Bytes (hex) in einer Kodierung mit den Profilen
  `strict`, `replace` und `tcl8` gelesen (Tcl 9); `strict` bricht beim
  ersten ungueltigen Byte ab, wie ein Kanal mit Standard-Profil.

**Tk widgets / style**
- **Widget tree** — Hierarchie unter `.`, winfo, Bindtags und Bindings.
- **Clipboard** — CLIPBOARD/PRIMARY lesen, setzen, leeren.
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

Unter **External tools** werden tkcon, tkinspect und die Tk-Widget-Demo
gestartet, sofern installiert (`apt install tkcon tkinspect` bzw.
`tk*-doc` fuer die Demo).

## Lizenz

MIT — siehe [LICENSE](LICENSE).
