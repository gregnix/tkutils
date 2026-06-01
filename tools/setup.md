# setup.tcl (tkutils) — die tkutils/tclutils-Libraries auffindbar machen

Diese Datei ist mit der gleichnamigen Datei im tclutils-Paket identisch: sie
sucht von ihrem eigenen Ort aus nach oben und fügt **beide** Libraries
(tkutils und tclutils) zum Tcl-Modulpfad hinzu — tkutils benötigt tclutils.
Es ist also egal, ob sie aus `tkutils-*/tools/` oder `tclutils-*/tools/`
gesourct wird.

`setup.tcl` ist ein kleiner Bootstrap, der Tcl mitteilt, wo die Libraries
`tkutils` und `tclutils` liegen. Danach funktioniert `package require` in der
eigenen Anwendung ohne weitere Pfadangaben. Diese Datei liegt im Paket unter
`tkutils-<version>/tools/` (und ebenso bei tclutils), damit sie nicht verloren geht.

## Warum es nötig ist

tclutils und tkutils sind **Tcl-Module** (`tcl::tm`). Tcl findet ein Modul nur,
wenn das passende `lib/tm`-Verzeichnis im Modul-Suchpfad steht. Standardmäßig
sucht Tcl nur in festen Systempfaden (siehe `tcl::tm::path list`) — eine frisch
entpackte Library liegt da nicht. Ohne diesen Schritt kommt beim Start die
Meldung „can't find package …" bzw. „library not found".

`setup.tcl` erledigt genau diesen einen Schritt: es ruft für jede Library
`tcl::tm::path add <…/lib/tm>` auf, jeweils für die höchste gefundene Version.

## Ablage

`setup.tcl` darf an zwei Stellen liegen — beide werden automatisch erkannt:

**a) im Paket** (so ausgeliefert), damit es nicht verloren geht:

```
~/lib/tcltk/
├── tclutils-0.33.0/
│   ├── tools/
│   │   ├── setup.tcl
│   │   └── setup.md
│   └── lib/tm/…
└── tkutils-0.4.0/
    └── lib/tm/…
```

**b) direkt neben den Library-Ordnern:**

```
~/lib/tcltk/
├── setup.tcl
├── tclutils-0.33.0/
└── tkutils-0.4.0/
```

In beiden Fällen sucht `setup.tcl` von seinem eigenen Ort aus **nach oben**, bis
ein Verzeichnis mit `tclutils-*`/`tkutils-*`-Ordnern gefunden wird. Mehrere
Versionen dürfen nebeneinander liegen — es wird automatisch die **höchste**
gewählt.

## Benutzung in der Anwendung

Ganz oben in der App `setup.tcl` sourcen, dann die gewünschten Pakete laden:

```tcl
# Variante a) aus dem Paket heraus:
source ~/lib/tcltk/tkutils-0.27.0/tools/setup.tcl

# Variante b) direkt daneben:
# source ~/lib/tcltk/setup.tcl

package require tclutils::tubin
package require tkutils::tkcsv
```

Beide Libraries werden zum Modulpfad hinzugefügt, weil tkutils intern tclutils
braucht. Ein GUI-Programm tritt danach wie üblich in die Event-Loop ein.

## Was setup.tcl genau tut

```tcl
apply {{} {
    set dir [file dirname [file normalize [info script]]]
    set base $dir
    for {set i 0} {$i < 6} {incr i} {
        if {[llength [glob -nocomplain -directory $dir -type d tclutils-* tkutils-*]] > 0} {
            set base $dir
            break
        }
        set parent [file dirname $dir]
        if {$parent eq $dir} break
        set dir $parent
    }
    foreach lib {tclutils tkutils} {
        foreach d [lsort -decreasing -dictionary \
                [glob -nocomplain -directory $base -type d ${lib}-*]] {
            set tm [file join $d lib tm]
            if {[file isdirectory $tm]} {
                tcl::tm::path add $tm
                break
            }
        }
    }
}}
```

- `info script` → das Verzeichnis von `setup.tcl` selbst. Es werden **keine
  absoluten Pfade fest verdrahtet**; alles ist relativ zu dieser Datei.
- Die Schleife geht bis zu 6 Ebenen nach oben, bis sie das Wurzelverzeichnis mit
  den Library-Ordnern findet (deckt `tools/` und das Daneben-Layout ab).
- Pro Library werden die Ordner `tclutils-*` bzw. `tkutils-*` absteigend nach
  Version sortiert (`-dictionary`, damit `0.10 > 0.9`); der erste mit
  vorhandenem `lib/tm` wird hinzugefügt.
- `-type d` ignoriert `.zip`-Dateien o. Ä. Der `apply`-Block lässt keine
  Hilfsvariablen im globalen Namespace zurück.

## Alternative ohne setup.tcl

Wer die `source`-Zeile nicht in jede App schreiben will, kopiert den **Inhalt**
von `lib/tm` (also die Umbrella-Datei `tclutils-0.33.0.tm` **und** den Ordner
`tclutils/`) in eines der Verzeichnisse, die `tcl::tm::path list` ohnehin
anzeigt. Dann genügt `package require` ohne jeden Pfad-Schritt.

## Was man nicht tun sollte

Die Moduldateien **nicht** in `tclutils::common-0.1.tm` (mit `::`) umbenennen.
Die tm-Suche bildet `tclutils::common` auf den Pfad `tclutils/common-0.1.tm`
(Unterordner) ab — flache `::`-Namen findet sie nicht. Das Unterordner-Layout
der ausgelieferten Archive muss erhalten bleiben.

## Schnelldiagnose bei „library not found"

1. Liegt `setup.tcl` im Paket unter `tclutils-*/tools/` oder neben den
   `tclutils-*`/`tkutils-*`-Ordnern?
2. Existiert in der gewählten Version der Pfad `…/lib/tm/tclutils/` mit den
   `*.tm`-Dateien (Unterordner-Layout, nicht flach umbenannt)?
3. Test: nach `source setup.tcl` einmal `puts [tcl::tm::path list]` — die beiden
   `lib/tm`-Pfade müssen auftauchen.
4. Für die Entwicklung im Quellbaum kann der Pfad auch über die Umgebungsvariable
   `TCLUTILS_TM` gesetzt werden (Tests/Demos der Libraries nutzen das).
