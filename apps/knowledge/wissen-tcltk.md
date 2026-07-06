# Tcl/Tk-Wissen

Kuratierter Wissensdatensatz zum Import in die Wissensbasis. Jede `##`-Ueberschrift
traegt ein `[Bereich/Thema]`-Praefix, das der Importer als hierarchische Kategorie
anlegt. Backtick-Begriffe werden zu Tags.

---

## [Tcl/Grundlagen] Alles ist ein String (EIAS)

In Tcl ist jeder Wert ein String -- Zahlen, Listen, Dicts sind nur besondere
String-Formen. Intern haelt Tcl zusaetzlich eine typisierte Repraesentation
(z. B. als Liste), rein zur Beschleunigung ("shimmering"); semantisch zaehlt
immer der String. `string is integer -strict $x` prueft, ob ein String als
Integer taugt, ohne den Wert zu veraendern. Es gibt keine getrennten Typen fuer
Zahl und Text.

Tags: eias, string, typen, shimmering

## [Tcl/Grundlagen] Substitution und Quoting

Tcl kennt drei Substitutionen: Variablen (`$name`), Kommandos (`[cmd]`) und
Backslash (`\n`). Doppelte Anfuehrungszeichen `"..."` erlauben Substitution,
geschweifte Klammern `{...}` unterdruecken sie komplett -- ideal fuer `expr`,
`proc`-Rueumpfe und Muster. `{*}` expandiert eine Liste zu einzelnen Worten:
`cmd {*}$args`.

Tags: substitution, quoting, braces, expand

## [Tcl/Grundlagen] Kommando-Auswertung

Ein Kommando ist eine Zeile aus durch Whitespace getrennten Worten; das erste
Wort ist der Befehl, der Rest sind Argumente. `;` trennt mehrere Kommandos in
einer Zeile. Tcl wertet zuerst alle Substitutionen aus, dann ruft es das
Kommando -- es gibt keine Operator-Praezedenz auf Kommando-Ebene, nur in `expr`.
Ein `#` ist nur am Kommandoanfang ein Kommentar.

Tags: kommando, evaluation, wortsplitting

## [Tcl/Datenstrukturen] Listen

Listen sind Strings in kanonischer Form. `list a b c` baut sicher, `lappend var`
haengt an (in-place, schnell), `lindex`, `lrange`, `llength`, `lsearch`,
`lsort`, `lreplace`, `linsert` arbeiten darauf. `lsort -unique -dictionary` und
`lsearch -inline -glob` sind haeufige Varianten. `lmap` bildet eine Liste auf
eine neue ab. Immer `list`/`lappend` benutzen statt Strings manuell zu bauen.

Tags: liste, lappend, lsort, lsearch, lmap

## [Tcl/Datenstrukturen] Dicts

Ein Dict ist eine Liste aus Schluessel/Wert-Paaren. `dict create`, `dict get`,
`dict set`, `dict exists`, `dict incr`, `dict for {k v} $d {...}`. `dict with`
und `dict update` binden Werte an lokale Variablen. Dicts bewahren die
Einfuegereihenfolge und sind wertsemantisch (Kopie bei Zuweisung), anders als
Arrays.

Tags: dict, key-value, dict-for

## [Tcl/Datenstrukturen] Arrays

Arrays sind assoziative Container (`set a(key) val`), aber **keine** Werte -- sie
leben nur als Variablen, nicht als String. `array get`, `array set`,
`array names`, `array exists`, `array unset`. Fuer Rueckgabewerte und
Verschachtelung sind Dicts besser; Arrays glaenzen bei grossen, oft geaenderten
Nachschlagetabellen.

Tags: array, assoziativ, variable

## [Tcl/Sprache] expr und Operatoren

Arithmetik/Vergleiche laufen ueber `expr`. **Immer** den Ausdruck in `{}`
setzen: `expr {$a + $b}` -- das ist schneller und sicher. Operatoren: `**`
(Potenz), `eq`/`ne` (String-Gleichheit), `in`/`ni` (Enthaltensein), `?:`.
Funktionen wie `min`, `max`, `abs`, `int`, `double`. `if`/`while` werten ihre
Bedingung selbst per `expr` aus, also auch dort `{}` nutzen.

Tags: expr, operatoren, arithmetik, braces

## [Tcl/Sprache] Kontrollfluss

`if {cond} {...} elseif {...} else {...}`. `while`, `for {init} {cond} {step}`.
`foreach` kann mehrere Variablen und mehrere Listen: `foreach {k v} $pairs {...}`
bzw. `foreach a $l1 b $l2 {...}`. `switch -glob`/`-regexp -- $x { pat {body} }`;
`--` beendet die Optionen. `break`, `continue`. Koerper immer in `{}`.

Tags: if, while, for, foreach, switch

## [Tcl/Sprache] proc, args und Defaults

`proc name {a b {c 5} args} {body}`: `c` hat einen Default, `args` sammelt den
Rest als Liste. Rueckgabe mit `return $wert` (oder implizit der letzte Ausdruck).
`return -code error`, `-level`, `-errorcode` steuern den Rueckgabe-Code. Argumente
werden by-value uebergeben; fuer by-reference `upvar`.

Tags: proc, args, defaults, return

## [Tcl/Sprache] Scope: upvar und uplevel

Lokale Variablen sind default. `global name` und `variable name` binden globale
bzw. Namespace-Variablen. `upvar 1 $varName local` bindet die Variable des
Aufrufers (Call-by-Name). `uplevel 1 {script}` fuehrt Code im Scope des Aufrufers
aus -- die Basis fuer eigene Kontrollstrukturen.

Tags: scope, upvar, uplevel, variable

## [Tcl/String] Das string-Kommando

`string length`, `string index`, `string range`, `string first/last`,
`string match ?-nocase? pattern $s` (Glob), `string map {a b c d} $s`
(Mehrfach-Ersetzung), `string trim/trimleft/trimright`, `string tolower/toupper`,
`string repeat`, `string is CLASS`. `string map` ist oft schneller und klarer als
`regsub` fuer feste Ersetzungen.

Tags: string, string-map, string-match

## [Tcl/String] regexp und regsub

`regexp ?-nocase? ?-all? ?-inline? ?-line? re $s ?match sub1 ...?` matcht und
extrahiert; `-inline` liefert die Treffer als Liste, `-all` alle, Capture-Gruppen
`(...)`. `regsub ?-all? re $s repl ?varName?` ersetzt; im Ersatz stehen `\1`,
`\2` fuer Gruppen und `&` fuer den ganzen Treffer. Klammere das Muster in `{}`,
damit `$`/`[` nicht substituiert werden.

Tags: regexp, regsub, regex, capture

## [Tcl/Namespaces] Namespaces und Variablen

`namespace eval ::foo { ... }` erstellt/betritt einen Namespace. Prozeduren und
Variablen darin sind ueber `::foo::name` erreichbar. In einer Prozedur bindet
`variable v` die Namespace-Variable. `namespace export` legt fest, was `namespace
import` uebernehmen darf. `namespace current`, `namespace which` helfen beim
Aufloesen.

Tags: namespace, variable, export, scope

## [Tcl/Namespaces] Ensembles

`namespace ensemble create` macht aus den exportierten Prozeduren eines Namespace
ein Kommando mit Subkommandos: `::foo bar ...` ruft `::foo::bar`. Mit `-map`
lassen sich Subkommandos auf beliebige Kommandos umlenken. So sind die
eingebauten Ensembles wie `string`, `dict`, `chan` aufgebaut.

Tags: ensemble, subkommando, namespace

## [Tcl/Fehler] try, throw und errorCode

`try {body} trap {ERR CODE} {msg opt} {handler} finally {cleanup}` ist die
moderne Fehlerbehandlung; `trap` faengt nach `errorCode`-Praefix. `throw {LIB MOD
REASON} "message"` wirft mit maschinenlesbarem Code. `catch {script} msg opt`
bleibt fuer einfache Faelle. In `opt` steckt `-errorcode` und `-errorinfo`.

Tags: try, throw, catch, errorcode, fehler

## [Tcl/OO] TclOO Grundlagen

`oo::class create Punkt { variable x y; constructor {ax ay} {set x $ax; set y
$ay}; method move {dx dy} {incr x $dx; incr y $dy} }`. `my methode` ruft eigene
Methoden, `self` ist das Objekt. `superclass`, `mixin`, `filter` fuer Vererbung
und Aspekte. Instanzen: `set p [Punkt new 1 2]` oder `Punkt create p 1 2`.

Tags: tcloo, oo, klasse, method, konstruktor

## [Tcl/Fortgeschritten] Coroutines

`coroutine name cmd args` startet `cmd` als Coroutine; im Inneren gibt `yield
?wert?` die Kontrolle mit einem Wert zurueck und wartet auf den naechsten Aufruf
`name ?wert?`. `yieldto` uebergibt direkt an ein anderes Kommando. Ideal fuer
Generatoren und ereignisgesteuerten Code ohne verschachtelte Callbacks.

Tags: coroutine, yield, generator, eventloop

## [Tcl/Fortgeschritten] Traces

`trace add variable v {read write unset} cb` ruft `cb` bei Zugriff. `trace add
command name {rename delete} cb` und `trace add execution name {enter leave} cb`
beobachten Kommandos. Nuetzlich fuer Beobachter-Muster, Lazy-Init und Debugging;
sparsam einsetzen, da jeder Zugriff den Callback ausloest.

Tags: trace, beobachter, debug

## [Tcl/IO] Dateien und Kanaele

`set ch [open $path r]`, `read $ch`, `gets $ch line`, `puts $ch $data`,
`close $ch`. **Immer** `fconfigure $ch -encoding utf-8 -translation lf` setzen,
wenn die Kodierung/Zeilenenden feststehen sollen. `chan` ist das Ensemble dazu.
Fuer Binaerdaten `-translation binary` und `binary scan`/`binary format`.

Tags: datei, channel, encoding, fconfigure

## [Tcl/IO] exec und Pipes

`exec cmd arg ...` startet einen Prozess und liefert dessen stdout; `2>@1` leitet
stderr um, `<< $data` speist stdin, `&` startet im Hintergrund. Ein Pipe-Kanal
`set ch [open "|cmd args" r]` erlaubt schrittweises Lesen. `exec` wirft bei
Exit-Code != 0 -- in `catch`/`try` fangen.

Tags: exec, pipe, prozess, stdout

## [Tcl/Migration] Tcl 8.6 zu 9.0

Wichtigste Aenderungen: fuehrende Null ist **nicht** mehr oktal -- `0600` ist
dezimal, oktal schreibt man `0o600`. Default-Encoding ist utf-8. Interne
Integers sind beliebig gross (bignum). Neue Befehle wie `lseq`, `lpop`,
`lremove` gibt es erst ab 8.7/9.0. `file`-Rueckgaben und einige C-APIs aendern
sich -- Erweiterungen ggf. neu bauen.

Tags: migration, tcl9, oktal, encoding, kompatibilitaet

## [Tk/Grundlagen] Widget-Pfade und Hierarchie

Jedes Widget hat einen Pfadnamen, der die Hierarchie kodiert: `.` ist das
Hauptfenster, `.f` ein Kind, `.f.b` dessen Kind. Der Pfad **ist** das
Widget-Kommando: `.f.b configure -text Hi`. `winfo children .`, `winfo exists`,
`winfo class`, `winfo toplevel` fragen die Struktur ab. `destroy .f` loescht
Widget samt Kindern.

Tags: widget, pfad, hierarchie, winfo

## [Tk/Grundlagen] Classic vs ttk

Klassische Widgets (`button`, `label`, `entry`) sind direkt gestylt; die
themed-Widgets (`ttk::button`, `ttk::treeview`, `ttk::notebook`) folgen einem
Theme und wirken nativer. ttk-Optik steuert man ueber `-style` und
`ttk::style`, nicht ueber `-bg`/`-fg`. Fuer neue GUIs ttk bevorzugen; `text`,
`canvas`, `listbox`, `toplevel` gibt es nur klassisch.

Tags: ttk, themed, style, classic

## [Tk/Geometrie] pack

`pack` ordnet Kinder an einer Seite an: `-side left|right|top|bottom`, `-fill
x|y|both`, `-expand 1` verteilt freien Platz, `-padx/-pady`, `-anchor`. Die
Reihenfolge der `pack`-Aufrufe bestimmt das Layout. Gut fuer einfache
Zeilen/Spalten und Toolbars; fuer Raster ist `grid` klarer.

Tags: pack, geometrie, layout, side, fill

## [Tk/Geometrie] grid

`grid $w -row r -column c -rowspan/-columnspan -sticky nsew -padx -pady`. `sticky`
bestimmt, an welche Zellenraender das Widget klebt (Dehnung). Entscheidend fuer
Resizing: `grid rowconfigure $parent r -weight 1` und `columnconfigure ...
-weight 1` geben Zeilen/Spalten Dehnungsgewicht. Der beste Allrounder fuer
Formulare.

Tags: grid, geometrie, layout, sticky, weight

## [Tk/Geometrie] place

`place` positioniert absolut oder relativ: `-x/-y` in Pixeln, `-relx/-rely`
(0.0-1.0) relativ zum Elter, `-relwidth/-relheight`, `-anchor`. Praezise, aber
skaliert nicht automatisch mit Inhalt -- fuer Overlays, Splash-Elemente und
Spezialfaelle, nicht fuer normale Layouts.

Tags: place, geometrie, absolut, relativ

## [Tk/Events] bind und Events

`bind $w <Event> {script}` verknuepft Ereignisse. Muster: `<Button-1>`,
`<KeyPress-Return>`, `<<Paste>>`. Prozent-Substitutionen im Script: `%W` (Widget),
`%x %y` (Koordinaten), `%K` (Keysym), `%A` (Zeichen). `return -code break` bzw.
`break` stoppt weitere Bindungen. `bindtags` legt die Reihenfolge der
Binding-Ebenen fest (Widget, Klasse, Toplevel, all).

Tags: bind, event, binding, bindtags, keysym

## [Tk/Events] Event-Loop und after

Tk ist ereignisgesteuert; die GUI reagiert nur, solange die Event-Loop laeuft.
`after ms {script}` plant verzoegert, `after idle {script}` laeuft, wenn nichts
mehr ansteht, `after cancel $id` bricht ab. `update idletasks` arbeitet
anstehende Neuzeichnungen ab (ohne Nutzer-Events), `vwait var` wartet blockierend
auf eine Variable. Lange Berechnungen aufteilen, sonst friert die GUI ein.

Tags: eventloop, after, update, vwait

## [Tk/Widgets] Das text-Widget

Das `text`-Widget adressiert Positionen als `zeile.spalte` (`1.0` = Anfang),
plus `end`, `insert`, `sel.first`/`sel.last` und arithmetische Indizes
(`"insert + 2 chars"`, `"end - 1 line"`). `tag add/configure` formatiert Bereiche
und bindet Events; `mark set` setzt bewegliche Marken. Extrem maechtig fuer
Editoren und formatierten Text.

Tags: text, widget, index, tag, mark

## [Tk/Widgets] Canvas

Das `canvas`-Widget zeichnet Items (`create line/rectangle/oval/text/image`), die
per numerischer ID **oder** per Tag angesprochen werden. `coords`, `move`,
`itemconfigure`, `bind $c <Button-1> ...` auf Items via Tag. Koordinaten sind
Canvas-relativ; `scrollregion` und `xview/yview` fuer grosse Flaechen.

Tags: canvas, item, tag, coords

## [Tk/Widgets] Variablen-Bindung

Viele Widgets spiegeln eine Variable: `-textvariable` (entry/label),
`-variable` (checkbutton/radiobutton), `-listvariable` (listbox),
`ttk::combobox -textvariable`. Aendert sich die Variable, aktualisiert sich das
Widget und umgekehrt -- die Basis fuer MVC in Tk. Globale oder Namespace-Variable
verwenden, kein lokaler Scope.

Tags: textvariable, variable, binding, mvc

## [Tk/Dialoge] Dialoge und Toplevels

`toplevel .dlg` ist ein eigenstaendiges Fenster; `wm title/geometry/transient/
protocol` steuert Fensterrahmen und -verhalten. `grab .dlg` macht es modal,
`tkwait window .dlg` oder `tkwait variable` blockiert bis zum Schliessen. Fertige
Dialoge: `tk_messageBox`, `tk_getOpenFile`, `tk_chooseColor`.

Tags: toplevel, dialog, grab, modal

## [Tk/Styling] ttk-Styling

`ttk::style configure Stil.TButton -foreground blue` aendert Aussehen;
`ttk::style map` setzt zustandsabhaengige Werte (z. B. bei `active`, `disabled`).
`ttk::style layout` beschreibt den Aufbau aus Elementen. Eigene Stile per Praefix
(`Danger.TButton`) und `-style` am Widget. `ttk::style theme use` wechselt das
Theme.

Tags: ttk, style, theme, layout

## [Tk/Virtuelle-Events] Virtual Events

Virtuelle Events `<<Name>>` entkoppeln Bedeutung von konkreten Tasten:
`<<Paste>>`, `<<TreeviewSelect>>`, `<<ComboboxSelected>>` oder eigene. Ausloesen
mit `event generate $w <<Name>> -data $wert`; im Handler liest `%d` die
mitgegebenen Daten. Ideal, um Widgets lose zu koppeln und eigene GUI-Signale zu
definieren.

Tags: virtualevent, event, generate
