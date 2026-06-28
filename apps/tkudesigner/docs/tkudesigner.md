# tkudesigner — visueller GUI-Designer für Tcl/Tk

`tkudesigner` ist ein Werkzeug, um **Tcl/Tk-Oberflächen visuell zu
entwerfen**: Fenster und ihre Chrome (Menüleiste, Toolbar, Statusleiste,
Panes), Widgets anordnen, Eigenschaften setzen — mit **echter Live-Vorschau**.

Wichtig: Diese Version erzeugt **bewusst keinen Tcl-Code**. Das Ergebnis ist
der Entwurf selbst (die Live-Vorschau), den du als `.tkd`-Datei speichern und
wieder laden kannst. Code-Generierung ist ein möglicher späterer Schritt.

---

## Start

```sh
wish tkudesigner.tcl                 # öffnet mit Beispiel-Layout
wish tkudesigner.tcl --new           # leeres Fenster
wish tkudesigner.tcl --open foo.tkd  # Entwurf laden
wish tkudesigner.tcl --open foo.tkd --shot bild.png   # headless Screenshot
```

Läuft unverändert auf **Tcl/Tk 8.6** und **9.0**.

### Voraussetzungen

- Tcl/Tk ≥ 8.6 (ttk vorausgesetzt).
- Für die **Advanced**-Palette optional `tablelist_tile` und
  `scrollutil_tile` (themed Varianten). Fehlt ein Paket, erscheint der
  betreffende Palette-Eintrag ausgegraut mit „(n/a)"; der Designer läuft
  trotzdem. Es werden **ausschließlich** die `*_tile`-Varianten geladen —
  Tablelist/Scrollutil und ihre Tile-Pendants dürfen nicht gemeinsam in einer
  Anwendung laufen.
- Für die **tkutils**-Palette müssen die Bibliotheken `tclutils`/`tkutils`
  auf dem Modulpfad liegen. Der Designer fügt dazu beim Start die
  Umgebungsvariablen **`TCLUTILS_TM`** und **`TKUTILS_TM`** zum
  `tcl::tm`-Pfad hinzu, falls gesetzt:

  ```sh
  export TCLUTILS_TM=…/tclutils/lib/tm
  export TKUTILS_TM=…/tkutils/lib/tm
  wish tkudesigner.tcl
  ```

  Ohne diese Pakete bleibt die tkutils-Gruppe sichtbar, aber ausgegraut.

---

## Die Oberfläche

Der Designer besteht aus zwei Fenstern:

1. **Designer-Fenster** (links) mit
   - **Palette** — Widgets nach Gruppen, Klick fügt zur Auswahl hinzu.
   - **Hierarchy** — Baum der Knoten; Auswahl und Drag & Drop.
   - **Properties** — Optionen und Anordnung des gewählten Knotens.
   - Eigene Menü-/Tool-/Statusleiste.
2. **Vorschau-Fenster** (rechts) — ein **echtes Toplevel**, das den Entwurf
   live zeigt (Titel, Menüleiste, Größe wirken real).

Das gewählte Widget wird in der Vorschau mit einem **roten Rahmen** markiert.

---

## Arbeitsablauf

1. Im Baum (oder per Klick in der Vorschau) einen **Container** auswählen.
2. In der **Palette** ein Element anklicken — es wird in den gewählten
   Container eingefügt (passt das gewählte Element dort nicht hinein, landet es
   im nächstpassenden Eltern-Container).
3. In **Properties** die Optionen setzen (Text, Breite, …).
4. Im Abschnitt **Placement / Child layout** die Anordnung festlegen.
5. Per **Drag & Drop** im Baum umhängen oder umsortieren.

Jede Änderung baut die Vorschau sofort neu auf.

---

## Palette

| Gruppe | Einträge |
|--------|----------|
| **Container** | Frame, LabelFrame, PanedWindow, Notebook |
| **Chrome** | Menubar → Menu → Menu item, Toolbar → Tool button, Statusbar |
| **Widget** (ttk) | Label, Button, Entry, Checkbutton, Radiobutton, Combobox, Spinbox, Scale, Progressbar, Separator, Listbox, Treeview, Text, Canvas |
| **Advanced** | Scrollarea, Scrollableframe, ScrolledNotebook, PlainNotebook, PagesMan, Tablelist |
| **tkutils** | TkuToolbar, Labeled, Form, NumEntry, DateEntry, TimeEntry, Tags, SearchBar, Status |

Die Palette ist scrollbar; Palette und Hierarchie-Baum teilen sich die linke
Spalte über einen ziehbaren Trenner. Auch das **Eigenschaften-Panel** ist
scrollbar (Mausrad oder Scrollbalken), falls ein Widget viele Felder hat.

`Treeview` kann über die Option **`items`** statische Knoten erhalten — eine verschachtelte Liste, jeder Knoten entweder ein einfaches Label (Blatt) oder `{Label {Kind1 Kind2 …}}` mit Kindern (rekursiv). Beispiel: `{Belege {Lieferscheine Rechnungen}} Kunden Artikel`. Leer = leerer Baum.

`Canvas` ist eine klassische Tk-Zeichenfläche (Optionen `width`, `height`,
`background`) — als Platzhalter für Seiten-/Skizzenflächen, z. B. die
A4-Fläche eines Layout-Editors.

**Aussehen / erweiterte Optionen.** Wo das jeweilige Widget sie unterstützt,
bietet das Panel zusätzlich:

| Option | Widgets |
|---|---|
| `state` (`normal`/`disabled`, bei Eingaben auch `readonly`) | Label, Button, Entry, Combobox, Checkbutton, Radiobutton, Spinbox, Scale, Listbox, Text |
| `font` | Label, Entry, Combobox, Spinbox, Listbox, Text |
| `foreground` (Textfarbe, z. B. `#cc0000` oder `red`) | Label, Entry, Combobox, Spinbox, Listbox, Text |
| `justify` (`left`/`center`/`right`) | Label, Entry, Combobox, Spinbox, Listbox |
| `wraplength` (Umbruchbreite in px, `0` = aus) | Label |
| `show` (Maskenzeichen, z. B. `*` für Passwörter) | Entry, Combobox, Spinbox |

Leere Felder bleiben wirkungslos (Standard-Aussehen). Die Optionen werden
nach dem Erzeugen generisch per `configure` gesetzt; Widgets, die eine Option
nicht kennen, ignorieren sie.

**Einfügeregeln** (in Palette und Drag & Drop identisch):

- `Menu` nur in `Menubar`, `Menu item` nur in `Menu`, `Tool button` nur in
  `Toolbar`.
- `Scrollarea` nimmt **genau ein** Kind (es umschließt ein scrollbares Widget).
- `Notebook`/`ScrolledNotebook`/`PlainNotebook`/`PagesMan` nehmen Seiten
  (jedes Kind wird eine Seite; üblich ist ein `Frame` je Seite).

---

## Anordnung: Layout-Manager pro Container

Tk erlaubt **nicht**, `pack` und `grid` im selben Container zu mischen. Darum
ist der Layout-Manager eine Eigenschaft **des Containers**, nicht des einzelnen
Kindes. Generische Container (`Frame`, `LabelFrame`, `Scrollableframe` sowie das
Fenster-Root) haben dafür **Child layout**:

- **pack** — `side` (top/bottom/left/right), `fill`, `expand`, `padx`, `pady`.
- **grid** — `row`, `column`, `sticky`, `columnspan`, `rowspan`, `padx`, `pady`.
- **place** — `x`, `y`, `anchor` (freie Platzierung fürs reine „Aussehen").

Wählst du ein **Kind**, zeigt das Panel genau die Felder, die zum **Layout
seines Eltern-Containers** passen. Kinder von Notebook/Paned/Scrollarea zeigen
„Managed by parent" — sie werden vom Container verwaltet, nicht gepackt. Für
Seiten eines Notebooks (notebook/scrollednotebook/plainnotebook) erscheint
zusätzlich ein **tab label**-Feld zum Beschriften des Reiters.

Bei **grid** bietet der Container zusätzlich **stretch cols** und
**stretch rows**: eine Liste von Spalten- bzw. Zeilenindizes (durch Leerzeichen
getrennt), die ein `-weight 1` bekommen und damit beim Vergrößern des Fensters
mitwachsen. Beispiel: `stretch cols = 1` lässt die Eingabespalte eines
Label/Feld-Formulars die Breite füllen, während die Label-Spalte kompakt bleibt.

**Root bleibt bewusst `pack`** (Toolbar oben, Statusleiste unten, Body
dazwischen). Das übliche Muster ist: Fenster = pack, ein Formular-`Frame` darin
= grid. Sollten doch einmal Manager kollidieren, stürzt die Vorschau nicht ab,
sondern meldet „Layout clash …" und überspringt nur das betroffene Widget.

---

## Drag & Drop im Baum

- Eine Zeile ziehen — die Zielzeile wird hervorgehoben.
- **Auf einen Container** fallen lassen → hinein (als letztes Kind).
- **Auf ein Nicht-Container** → Geschwister direkt dahinter (umsortieren).
- Es gelten dieselben Regeln wie in der Palette; zusätzlich:
  **kein Drop in den eigenen Teilbaum** und **Root ist unbeweglich**.
- Ein einfacher **Klick** wählt nur aus — verschoben wird erst ab ~4 px
  Mausbewegung.

---

## Speichern und Laden

`File → Save` schreibt eine **`.tkd`-Datei**, `File → Open` lädt sie. Das ist
**Entwurfs-Persistenz, kein Code**: die `.tkd` ist ein Tcl-`dict` mit dem Modell.

Grobstruktur:

```tcl
version 1
title   "My application"
root    n1
seq     42
nodes   { n1 {type root opts {} geom {…} layout pack}
          n2 {type labelframe opts {text Customer …} geom {…} layout grid} … }
kids    { n1 {n2 n7 …}  n2 {n3 n4 …} … }
parent  { n2 n1  n3 n2 … }
```

Jeder Knoten hat `type`, `opts` (Widget-Optionen), `geom`
(Platzierungs-Parameter aller Manager) und — bei Containern — `layout`. Ältere
Dateien ohne `layout` fallen sauber auf `pack` zurück.

---

## Beispiele

Im Ordner `examples/` liegen fünf Muster-Entwürfe. Öffnen mit
`wish tkudesigner.tcl --open examples/<name>.tkd`.

![Beispiel-Galerie](examples_gallery.png)

| Datei | Zeigt |
|-------|-------|
| `login_dialog.tkd` | Kleiner Dialog: grid-Formular (User/Passwort), Checkbutton, Button-Reihe (pack), Statusleiste. |
| `master_detail.tkd` | Menü + Toolbar, horizontaler PanedWindow mit Treeview (in Scrollarea) links und grid-Detailformular rechts. |
| `tab_editor.tkd` | Editor-Layout: Menü + Toolbar, ScrolledNotebook mit Text-Seiten und einer grid-Settings-Seite. |
| `data_app.tkd` | Daten-App: Toolbar, Tablelist (themed) in einer Scrollarea, Statusleiste. |
| `wizard.tkd` | Assistent: PagesMan mit gestapelten Seiten (ohne Tabs), Navigations-Buttons, Statusleiste. |
| `tkutils_demo.tkd` | tkutils-Widgets: TkuToolbar, SearchBar und ein grid-Formular mit DateEntry/NumEntry/TimeEntry/Tags/Labeled, dazu Form und Status. |

---

## Architektur: Render-Kern

Der gemeinsame Kern (Widget-Katalog, das Modell, `deserialize` und die Render-Engine `renderNode`/`renderChildren`) liegt im Paket **`tkutils::tkurender`** (Namespace `::tkurender`). `tkudesigner.tcl` (Namespace `::tkudesigner`) ist nur noch die **Editor-Schicht** und greift via `namespace path ::tkurender` auf den Kern zu; sie (Palette, Hierarchie, Eigenschaften, Undo, I/O) und macht `package require tkutils::tkurender`. Dasselbe Paket nutzt der headless-Loader `tkuload` — eine Render-Engine, zwei Frontends.

## Undo / Redo

**Edit → Undo/Redo** (`Ctrl+Z` / `Ctrl+Y`) über vollständige Modell-Snapshots: Hinzufügen, Löschen, Umhängen (Drag&Drop) und alle Eigenschafts-Änderungen sind umkehrbar; No-op-Änderungen erzeugen keinen Verlaufseintrag.

## Property-Grid

Das Eigenschaften-Panel zeigt Name + Optionen zweispaltig (Eigenschaft / Wert) mit Inline-Editoren.

## Drop-Indikator

Beim Ziehen im Baum signalisiert die Zielzeile, ob *hinein* (grün) oder *danach* (blau) abgelegt wird; der Status zeigt es zusätzlich an.


## Fehlende optionale Pakete (laut statt still)

tkutils-, tablelist- und scrollutil-Widgets sind optional. Ist ein Paket nicht ladbar, wird das **nicht verschluckt**: Der betroffene Platzhalter nennt das fehlende Paket (`⚠ tkutils::tkunumentry fehlt`) und auf stderr erscheint einmal pro Paket eine Warnung mit Hinweis — z. B. „TKUTILS_TM gesetzt? (siehe startdemo.sh)“. So ist beim Debuggen sofort sichtbar, warum ein Widget fehlt, statt nur ein anonymes „n/a“ zu sehen.

## Theme (Live-Vorschau)

**View → Theme** schaltet das ttk-Theme zur Laufzeit (`clam`/`alt`/`default`/`classic`, plattformabhängig auch `vista`/`aqua`). Editor und Vorschau werden sofort neu gestylt — so sieht man ein Design unter verschiedenen Themes.

## Benannte Widgets

Jeder Knoten (außer dem Fenster-Root) hat oben im Eigenschaften-Panel ein Feld **`name`** — ein symbolischer Bezeichner für Host-Apps. Der Name erscheint im Hierarchie-Baum (`entry (entBelegNr)`), wird in der `.tkd` gespeichert und vom Loader `tkuload` als **`byName`**-Map ausgegeben, sodass die Host-Anwendung Widgets stabil per Name greift (`dict get $ui byName entBelegNr`) statt über Position.

## Grenzen / Roadmap

- Kein Code-Export (bewusst; ein Spec-Loader-Modul für die Library wäre der
  nächste Architektur-Schritt).
- Drop verschiebt „dahinter/hinein"; ein „davor/dazwischen"-Indikator fehlt.
- `Form` (tkuform) wird über einen rohen Feldspec-String editiert; ein
  komfortabler Feld-Editor fehlt noch.

---

## Gestaltungsrichtlinien

Konventionen für den Aufbau, die Benennung und Struktur von `.tkd`-Designs (Fensterzonen, Benennungsschema, Kategorien) stehen in **`tkudesigner-hig.md`** — die maßgebliche Referenz für neue Designs und die `gen-*`-Generatoren.

## Konventionen

`package require Tcl 8.6-` / `Tk 8.6-`; kein `global`; Errorcode
`{TKUTILS DESIGNER <REASON>}`; Code und Kommentare englisch, Doku deutsch.
Reines Tk/ttk im Kern, Advanced-Widgets paket-gated.
