# tkudesigner — Gestaltungsrichtlinien (HIG)

Geerdete Richtlinie für den tkudesigner und die damit gebauten `.tkd`-Designs.
Sie hat **zwei Ebenen**, die bewusst getrennt sind:

- **A — `.tkd`-Konventionen:** wie ein gutes Design aufgebaut, benannt und
  strukturiert ist. *Das ist der unmittelbar nützliche Teil*, weil `.tkd` über
  `tkuload` zur Quelle echter Fenster in lieferschein wird.
- **B — Werkzeug-Prinzipien:** wie der Editor selbst aufgebaut ist.

Jeder Punkt ist als **[implementiert]**, **[Konvention]** (Regel, kein Code)
oder **[offen]** (Vorschlag/Zukunft) markiert — damit dies eine *Referenz* ist,
keine Wunschliste.

Orientierung an etablierten GUI-Designern (Glade, Qt Designer, Lazarus) und den
*universellen* Prinzipien der gängigen HIGs — **nicht** der wörtlichen Umsetzung
einer Desktop-HIG: ttk folgt dem Plattform-Theme (clam/vista/aqua), nicht GNOME.

---

## A. `.tkd`-Konventionen

### A.1 Fensterzonen [Konvention]

Ein vollständiges Anwendungsfenster nutzt feste Zonen — immer in dieser Rolle:

```
+--------------------------------------------------+
| Menübar                                          |
| Toolbar(s)                                       |
+-----------+--------------------------+-----------+
| Navigation| Inhalt (Mitte)           | Details/  |
| (links)   |  oben: Übersicht/Liste   | Eigensch. |
|           |  unten: Positionen/Summen| (rechts)  |
+-----------+--------------------------+-----------+
| Statusbar                                        |
+--------------------------------------------------+
```

- **Menübar** oben, **Statusbar** unten (Chrome verankert sich selbst).
- **Navigation** links (`treeview`), **Inhalt** Mitte, **Details/Eigenschaften**
  rechts.
- Horizontale Aufteilung über `panedwindow` (ziehbar), vertikale Splits ebenso.
- Referenz: `example03/warenwirtschaft_main.tkd`.

Dialoge/Teilmasken brauchen nicht alle Zonen — aber die *Rollen* bleiben
gleich (z. B. Buttonzeile unten, Inhalt darüber).

### A.2 Benennungsschema [Konvention]

Jedes **interaktive** Widget bekommt im Feld `name` einen Bezeichner nach
`<präfix><Bedeutung>` (camelCase). Der Loader gibt sie als `byName` aus, sodass
die Host-App stabil `dict get $ui byName entKunde` greift — nicht über Position.

| Präfix | Widget-Typ | Beispiel |
|--------|------------|----------|
| `frm`  | frame / labelframe | `frmKunde` |
| `nb`   | notebook | `nbMain` |
| `pw`   | panedwindow | `pwHaupt` |
| `tv`   | treeview | `tvNavigation` |
| `tbl`  | tablelist | `tblPositionen` |
| `lbl`  | label | `lblSumme` |
| `btn`  | button | `btnSpeichern` |
| `ent`  | entry | `entBelegNr` |
| `cb`   | combobox | `cbKategorie` |
| `chk`  | checkbutton | `chkAktiv` |
| `rb`   | radiobutton | `rbRechnung` |
| `spn`  | spinbox | `spnMenge` |
| `txt`  | text | `txtNotiz` |
| `lst`  | listbox | `lstUebersicht` |
| `cv`   | canvas | `cvVorschau` |
| `num`  | tkunumentry | `numNetto` |
| `dat`  | tkudateentry | `datLeistung` |
| `frm`(tkuform) | tkuform | `frmAdresse` |

Reine Layout-Container und Beschriftungs-Labels dürfen unbenannt bleiben.

**Referenz-Designs:** `example03/*.tkd` und `example02/faktura001.tkd` folgen diesem Schema durchgängig — `tkuload` gibt deren Handles als `byName` aus (z. B. `entBelegNr`, `cbStatus`, `tblPositionen`, `numNetto`). Labeled-Inputs (`tkulabeled`) tragen das Präfix ihrer Eingaberolle.

### A.3 Widget-Kategorien [implementiert / offen]

Palette-Gruppen statt einer langen Liste:

- **Container, Chrome, Widget, Advanced, tkutils** — [implementiert].
- **Data, Graphics, PDF, Database** — [offen]; setzen Widgets voraus, die es
  noch nicht gibt (DB-gebundene Tabelle, PDF-Vorschau-Widget). Bis dahin
  übernehmen `tablelist`/`canvas`/tkutils-Widgets diese Rollen.

### A.4 Layout-Regeln [Konvention]

- Layout ist eine Eigenschaft des **Containers** (pack | grid | place), nicht
  des Kindes — `pack` und `grid` nie im selben Master mischen.
- Formulare: `grid` mit `stretch cols` auf der Eingabespalte (Label-Spalte
  bleibt kompakt). Listen/Tabellen: `fill both -expand 1`.
- Mindestgrößen als **Richtwert** (Theme misst zeichenbasiert, keine harte
  px-Regel): Button ~80 px, Entry ~120 px, Toolbar-Icons 16–24 px.

### A.5 Toolbar- & Menü-Regeln [Konvention]

- Toolbar-Reihenfolge: Neu, Öffnen, Speichern · | · Drucken/PDF/Export · | ·
  domänenspezifisch · | · Hilfe. Gruppen durch Separatoren trennen.
- Menü: Datei, Bearbeiten, …, Hilfe — destruktive Aktionen nicht direkt neben
  häufigen platzieren.

### A.6 Dialog-Regeln [Konvention]

- Aktionsbuttons unten rechts. Reihenfolge plattformnah: bestätigend zuletzt
  (`Abbrechen` · `Speichern`/`OK`).
- Pflichtfelder zuerst, optionale danach; eine Spalte je Feldgruppe.

---

## B. Werkzeug-Prinzipien (Editor)

### B.1 Drei-Spalten-Aufbau [implementiert]

`Palette | Designer/Vorschau | Eigenschaften`. Links zusätzlich der
**Objektbaum** (Hierarchy) unter der Palette (ziehbarer Trenner). Beide
scrollbar.

### B.2 Objektbaum immer sichtbar [implementiert]

Vollständige Widget-Hierarchie mit Typ, Beschriftung und — falls gesetzt —
`name`: `entry (entBelegNr)`. Drag & Drop zum Umhängen/Umsortieren.

### B.3 Property-Editor [implementiert]

Eigenschaften als zweispaltiges **Grid** (Eigenschaft / Wert) mit Kopfzeile und
Inline-Editoren (entry/combobox/checkbutton), plus Platzierung und (bei
Containern) Child-Layout/Stretch.

### B.3a Undo/Redo & Drop-Indikator [implementiert]

Vollständiges **Undo/Redo** über Modell-Snapshots (Menü *Edit*, `Ctrl+Z` /
`Ctrl+Y`) für Hinzufügen, Löschen, Umhängen und alle Eigenschafts-Änderungen.
Beim Ziehen im Baum zeigt ein **Drop-Indikator**, ob *hinein* (grün) oder
*danach* (blau) abgelegt wird, mit Status-Text.

### B.4 Live-Preview & Theme [implementiert]

Die Vorschau ist ein echtes Fenster aus echten Widgets (kein Bild). **View →
Theme** schaltet das ttk-Theme zur Laufzeit (`clam`/`alt`/`default`/`classic`,
plattformabhängig auch `vista`/`aqua`) und restylt Editor und Vorschau sofort.

### B.5 Echte GUI-Datei `.tkd` [implementiert]

Quelle ist die `.tkd` (ein Tcl-Dict), **kein generierter Code** — wie Glade mit
XML. Ein Window-Root, Chrome verankert sich selbst, je Container ein Layout,
benannte Widgets für die Host-Verdrahtung. `tkuload` instanziiert sie ohne
Code-Export (`byId`/`byType`/`byName`).

### B.6 Offen / bewusst zurückgestellt

- **Dockbare/Floating-Fenster** [offen] — in reinem Tk teuer (kein natives
  Docking); `panedwindow` liefert resizable, nicht floating. Niedriger ROI.
- **SVG-Icon-Set** (monochrom, 16/24 px) [offen] — braucht tksvg + eigenes Set.
- **Form-Feld-Editor** für `tkuform` statt Feldspec-String [offen].

---

## Statusübersicht

| Thema | Stand |
|-------|-------|
| Drei-Spalten-Aufbau, Objektbaum, Property-Felder | implementiert |
| `.tkd` als Quelle, Loader (`byId/byType/byName`) | implementiert |
| Benannte Widgets, Canvas, Treeview-`items`, Grid-Stretch | implementiert |
| Theme-Umschalter (Live) | implementiert |
| Property-Grid (2-spaltig), Undo/Redo, Drop-Indikator | implementiert |
| Benennungsschema, Zonen, Kategorien | Konvention (dieses Dokument) |
| SVG-Icons, Docking, Data/PDF/DB-Widgets | offen |
