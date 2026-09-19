#!/usr/bin/env wish
# search_replace_tool.tcl -- recursive find & replace with a Treeview result
# list, content preview, encoding support and multiline search/replace.
#
# Built on tkutils (tkutoolbar, tkustatus, tkudialog) and standard Tk. The search
# and replace logic lives in pure-Tcl procs (no Tk) so it can be tested without
# a display; the GUI is only built when this file is run as the main script.

package require Tcl 8.6-

# --- locate tkutils / tclutils via the shared bootstrap ---
source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]


namespace eval ::srtool {
    variable opt
    array set opt {
        dir {} search {} replace {} pattern {*.tcl *.txt *.md}
        encoding utf-8 case 0 regex 0 recursive 1 multiline 0 allowReplace 0
        backup 1 filesonly 0
        binary 0
        datefrom {} dateto {}
        editor {}
    }
    variable results {}      ;# list of {file {hitDict ...}}
    variable cache           ;# path -> content
    array set cache {}
    variable itemInfo        ;# tree item -> {file F line L}
    array set itemInfo {}
    variable tbPath ""       ;# toolbar widget path (for enabling replace buttons)
    variable dirNodes        ;# directory -> tree node, while a search runs
    array set dirNodes {}
    variable searching 0     ;# a search loop is running
    variable cancel 0        ;# request to abort the running search
}

# =============================================================================
# Core logic (no Tk)
# =============================================================================

# Was beim Lesen ueber eine Datei herauskam: BINAER, welches Encoding
# wirklich benutzt wurde, welche Zeilenenden drin standen.
#
# Drei Dinge, die vorher still passierten:
#
#   Eine Binaerdatei wurde durchsucht wie Text. Gemessen: eine Datei mit
#   Nullbytes lieferte einen Treffer -- und "Alle ersetzen" schrieb sie
#   ueber writeFileEnc zurueck. Das ZERSTOERT sie.
#
#   writeFileEnc setzte immer -translation lf. Eine CRLF-Datei kam als
#   LF zurueck, ohne dass es jemand wollte.
#
#   Der Rueckfall auf iso8859-1 beim Lesen war unsichtbar. Geschrieben
#   wurde danach mit dem GEWAEHLTEN Encoding -- also womoeglich mit
#   einem anderen als dem gelesenen.
namespace eval ::srtool {
    variable lastRead {}
    variable hinweisText ""
    variable selPath ""
    variable ctxTarget ""
    # Verzeichnisse, die beim rekursiven Sammeln uebersprungen werden.
    # Punkt-Verzeichnisse und __pycache__ waren es schon; der Rest liegt
    # in jedem zweiten Projekt und soll nie durchsucht werden. Gemessen
    # lief node_modules vorher voll mit.
    variable skipDirs {
        __pycache__ node_modules build dist target vendor
        bower_components venv env
    }
}

# Ist der Inhalt binaer?
#
# Ein Nullbyte entscheidet -- die Faustregel jedes Werkzeugs dieser Art.
# Kein Ratespiel ueber Zeichenhaeufigkeiten: falsch positiv heisst hier,
# dass eine Textdatei nicht durchsucht wird; falsch negativ, dass eine
# Binaerdatei ueberschrieben wird. Das zweite ist der teurere Fehler.
proc ::srtool::isBinary {content} {
    expr {[string first "\x00" $content] >= 0}
}

proc ::srtool::readFileEnc {path enc} {
    variable lastRead
    set lastRead [dict create encoding $enc fallback 0 eol lf binary 0]
    set ch ""
    # -translation lf beim Lesen: Tcl wandelt sonst CRLF still um, und
    # wir koennten hinterher nicht sagen, was drin stand.
    if {[catch {
        set ch [open $path r]
        fconfigure $ch -encoding $enc -translation lf
        set d [read $ch]
        close $ch
        set d
    } data]} {
        catch {close $ch}
        set ch [open $path r]
        fconfigure $ch -encoding iso8859-1 -translation lf
        set data [read $ch]
        close $ch
        dict set lastRead encoding iso8859-1
        dict set lastRead fallback 1
    }
    if {[string first "\r\n" $data] >= 0} {
        dict set lastRead eol crlf
        set data [string map [list "\r\n" "\n"] $data]
    }
    if {[::srtool::isBinary $data]} { dict set lastRead binary 1 }
    return $data
}

# Schreiben mit DEM Encoding und DEN Zeilenenden, mit denen gelesen
# wurde -- nicht mit der Auswahl im Fenster. Eine Datei, die nur ueber
# den iso8859-1-Rueckfall lesbar war, darf nicht als UTF-8 zurueck.
proc ::srtool::writeFileEnc {path content enc {eol lf}} {
    set ch [open $path w]
    fconfigure $ch -encoding $enc -translation $eol
    puts -nonewline $ch $content
    close $ch
}

proc ::srtool::_skipDir {name} {
    variable skipDirs
    expr {[string index $name 0] eq "." || $name in $skipDirs}
}

proc ::srtool::collectFiles {dir patterns recursive} {
    set files {}
    _collect $dir $patterns $recursive files
    return [lsort -unique $files]
}
proc ::srtool::_collect {dir patterns recursive filesVar} {
    upvar 1 $filesVar files
    foreach pat $patterns {
        foreach f [glob -nocomplain -type f -directory $dir -- $pat] {
            lappend files $f
        }
    }
    if {$recursive} {
        foreach sub [glob -nocomplain -type d -directory $dir -- *] {
            if {[_skipDir [file tail $sub]]} continue
            _collect $sub $patterns $recursive files
        }
    }
}

proc ::srtool::_reFlags {opts {extra {}}} {
    set f $extra
    if {![dict get $opts case]} { lappend f -nocase }
    return $f
}

proc ::srtool::_lineOf {content offset} {
    if {$offset <= 0} { return 1 }
    return [expr {[regexp -all "\n" [string range $content 0 [expr {$offset - 1}]]] + 1}]
}

proc ::srtool::_lineMatch {line needle opts} {
    if {[dict get $opts regex]} {
        return [regexp {*}[_reFlags $opts] -- $needle $line]
    }
    if {[dict get $opts case]} {
        return [expr {[string first $needle $line] >= 0}]
    }
    return [expr {[string first [string tolower $needle] [string tolower $line]] >= 0}]
}

# Whole-content match offsets -> list of {startOffset endOffset}.
proc ::srtool::_matchOffsets {content needle opts} {
    set res {}
    if {[dict get $opts regex]} {
        set flags [_reFlags $opts {-indices -line}]
        set start 0
        set n [string length $content]
        while {$start <= $n} {
            if {![regexp {*}$flags -start $start -- $needle $content m]} break
            lassign $m s e
            if {$e < $s} {
                # zero-width match: record nothing useful, advance to avoid loop
                set start [expr {$s + 1}]
                continue
            }
            lappend res [list $s $e]
            set start [expr {$e + 1}]
        }
    } else {
        set hay $content
        set ndl $needle
        if {![dict get $opts case]} {
            set hay [string tolower $content]
            set ndl [string tolower $needle]
        }
        set len [string length $needle]
        if {$len == 0} { return {} }
        set from 0
        while {1} {
            set idx [string first $ndl $hay $from]
            if {$idx < 0} break
            lappend res [list $idx [expr {$idx + $len - 1}]]
            set from [expr {$idx + $len}]
        }
    }
    return $res
}

# Search one file. Returns a list of hit dicts: {line N text preview}.
proc ::srtool::searchFile {path needle opts} {
    variable lastRead
    set content [readFileEnc $path [dict get $opts encoding]]
    # Eine Binaerdatei wird NICHT durchsucht. Sonst steht sie in der
    # Trefferliste, und "Alle ersetzen" schreibt sie zurueck.
    if {[dict get $lastRead binary] &&
        !([dict exists $opts binary] && [dict get $opts binary])} {
        return {}
    }
    set ml [expr {[dict get $opts multiline] || [string first "\n" $needle] >= 0}]
    set hits {}
    if {$ml} {
        foreach m [_matchOffsets $content $needle $opts] {
            lassign $m s e
            set sl [_lineOf $content $s]
            set el [_lineOf $content $e]
            set preview [lindex [split [string range $content $s $e] "\n"] 0]
            set ln [expr {$sl == $el ? $sl : "$sl-$el"}]
            lappend hits [dict create line $ln text [string range $preview 0 119]]
        }
    } else {
        set ln 0
        foreach line [split $content "\n"] {
            incr ln
            if {[_lineMatch $line $needle $opts]} {
                lappend hits [dict create line $ln text [string range $line 0 119]]
            }
        }
    }
    return $hits
}

# Search a directory tree. Returns list of {file {hitDict ...}}.
proc ::srtool::searchDir {dir patterns needle opts} {
    set out {}
    set bounds [_dateBounds $opts]
    foreach f [collectFiles $dir $patterns [dict get $opts recursive]] {
        if {![_dateFileOk $f $bounds]} continue
        set hits [searchFile $f $needle $opts]
        if {[llength $hits]} { lappend out [list $f $hits] }
    }
    return $out
}

# Match a file NAME (base name) against the needle. An empty needle matches
# every file (list all). Honours case/regex from opts; content is never read.
proc ::srtool::_nameMatch {name needle opts} {
    if {$needle eq ""} { return 1 }
    return [_lineMatch $name $needle $opts]
}

# --- date filter (by file modification time) --------------------------------
# Parse the optional datefrom/dateto ("YYYY-MM-DD") into epoch bounds
# {lo hi}; "" = unbounded. "from" starts at 00:00 of that day, "to" is
# inclusive (upper bound = start of the following day). Raises an error on a
# non-empty but unparseable date.
proc ::srtool::_dateBounds {opts} {
    set lo ""; set hi ""
    set df [expr {[dict exists $opts datefrom] ? [string trim [dict get $opts datefrom]] : ""}]
    set dt [expr {[dict exists $opts dateto]   ? [string trim [dict get $opts dateto]]   : ""}]
    if {$df ne ""} { set lo [clock scan "$df 00:00:00" -format {%Y-%m-%d %H:%M:%S}] }
    if {$dt ne ""} { set hi [expr {[clock scan "$dt 00:00:00" -format {%Y-%m-%d %H:%M:%S}] + 86400}] }
    return [list $lo $hi]
}
proc ::srtool::_dateOk {mtime bounds} {
    lassign $bounds lo hi
    if {$lo ne "" && $mtime <  $lo} { return 0 }
    if {$hi ne "" && $mtime >= $hi} { return 0 }
    return 1
}
# Combine "read the mtime safely" with the range check.
proc ::srtool::_dateFileOk {path bounds} {
    lassign $bounds lo hi
    if {$lo eq "" && $hi eq ""} { return 1 }
    if {[catch {file mtime $path} mt]} { return 0 }
    return [_dateOk $mt $bounds]
}

# Find files by NAME only (no content search). Returns list of {file {}}
# so it plugs into the same result/tree structure with no hit children.
proc ::srtool::searchDirNames {dir patterns needle opts} {
    set out {}
    set bounds [_dateBounds $opts]
    foreach f [collectFiles $dir $patterns [dict get $opts recursive]] {
        if {![_dateFileOk $f $bounds]} continue
        if {[_nameMatch [file tail $f] $needle $opts]} { lappend out [list $f {}] }
    }
    return $out
}

proc ::srtool::_escapeRe {s} {
    return [regsub -all {[\\^$.?*+()\[\]{}|]} $s {\\&}]
}

# Replace in one file. Returns the number of replacements (0 = file untouched).
proc ::srtool::replaceInFile {path needle replacement opts} {
    variable lastRead
    set enc [dict get $opts encoding]
    set content [readFileEnc $path $enc]
    # Nie in eine Binaerdatei schreiben -- auch nicht, wenn jemand sie
    # ausdruecklich durchsucht hat. Suchen ist lesend, Ersetzen nicht,
    # und der Schaden laesst sich nicht zuruecknehmen.
    if {[dict get $lastRead binary]} { return 0 }
    # Mit dem Encoding und den Zeilenenden, mit denen gelesen wurde.
    set enc [dict get $lastRead encoding]
    set eol [dict get $lastRead eol]
    set ml [expr {[dict get $opts multiline] || [string first "\n" $needle] >= 0}]
    if {[dict get $opts regex]} {
        set flags [_reFlags $opts {-all}]
        if {$ml} { lappend flags -line }
        set count [regsub {*}$flags -- $needle $content $replacement new]
    } else {
        set pat [_escapeRe $needle]
        set rep [string map {\\ \\\\ & \\&} $replacement]
        set flags {-all}
        if {![dict get $opts case]} { lappend flags -nocase }
        set count [regsub {*}$flags -- $pat $content $rep new]
    }
    if {$count > 0} {
        if {[dict exists $opts backup] && [dict get $opts backup]} {
            catch { file copy -force -- $path $path.bak }
        }
        writeFileEnc $path $new $enc $eol
    }
    return $count
}

# Build the options dict from the GUI/state variables.
proc ::srtool::currentOpts {} {
    variable opt
    return [dict create \
        case $opt(case) regex $opt(regex) recursive $opt(recursive) \
        multiline $opt(multiline) encoding $opt(encoding) backup $opt(backup) \
        filesonly $opt(filesonly) datefrom $opt(datefrom) dateto $opt(dateto) \
        binary $opt(binary)]
}

proc ::srtool::countHits {results} {
    set n 0
    foreach pair $results { incr n [llength [lindex $pair 1]] }
    return $n
}

# =============================================================================
# GUI (Tk + tkutils)
# =============================================================================

proc ::srtool::buildGui {} {
    variable opt
    package require Tk 8.6-
    package require tkutils
    package require tkutils::tkueditor
    package require tclutils::tuopen
    package require tclutils::tuexe

    wm title . "Such- und Ersetzen-Tool"
    if {$opt(dir) eq ""} { set opt(dir) [pwd] }

    # --- toolbar ---
    set tb [::tkutils::tkutoolbar::widget .tb]
    pack $tb -side top -fill x
    ::tkutils::tkutoolbar::addButton $tb search  "Suchen"             ::srtool::doSearch
    ::tkutils::tkutoolbar::addButton $tb cancel  "Abbrechen"          ::srtool::cancelSearch
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb repall   "Alle ersetzen"      ::srtool::doReplaceAll
    ::tkutils::tkutoolbar::addButton $tb repsel   "Ausgewaehlte ersetzen" ::srtool::doReplaceSelected
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb clear    "Leeren"             ::srtool::clearResults
    # safeguard stage 1: replace buttons start disabled, enabled only when the
    # "Ersetzen erlauben" switch is on AND a search produced hits AND the
    # replacement field is non-empty (see updateReplaceButtons).
    set ::srtool::tbPath $tb
    ::tkutils::tkutoolbar::setEnabled $tb cancel 0
    ::tkutils::tkutoolbar::setEnabled $tb repall 0
    ::tkutils::tkutoolbar::setEnabled $tb repsel 0

    # --- parameters ---
    set p [ttk::frame .params -padding 6]
    pack $p -side top -fill x

    ttk::label $p.ldir -text "Verzeichnis:"
    ttk::entry $p.dir -textvariable ::srtool::opt(dir)
    ttk::button $p.browse -text "Durchsuchen..." -command ::srtool::chooseDir
    grid $p.ldir $p.dir $p.browse -sticky ew -padx 2 -pady 2

    ttk::label $p.lsearch -text "Suchtext:"
    ttk::entry $p.search -textvariable ::srtool::opt(search)
    text $p.searchml -height 4 -width 40 -wrap none \
        -yscrollcommand [list $p.searchsb set]
    ttk::scrollbar $p.searchsb -orient vertical -command [list $p.searchml yview]
    grid $p.lsearch $p.search -sticky ew -padx 2 -pady 2

    ttk::label $p.lrepl -text "Ersetzen:"
    ttk::entry $p.repl -textvariable ::srtool::opt(replace)
    text $p.replml -height 4 -width 40 -wrap none \
        -yscrollcommand [list $p.replsb set]
    ttk::scrollbar $p.replsb -orient vertical -command [list $p.replml yview]
    grid $p.lrepl $p.repl -sticky ew -padx 2 -pady 2

    ttk::label $p.lpat -text "Dateimuster:"
    ttk::entry $p.pat -textvariable ::srtool::opt(pattern)
    grid $p.lpat $p.pat -sticky ew -padx 2 -pady 2

    ttk::label $p.ldate -text "Geaendert:"
    set df [ttk::frame $p.datef]
    ttk::label $df.lf -text "von"
    ttk::entry $df.from -textvariable ::srtool::opt(datefrom) -width 12
    ttk::label $df.lt -text "bis"
    ttk::entry $df.to -textvariable ::srtool::opt(dateto) -width 12
    ttk::label $df.hint -text "(JJJJ-MM-TT, optional)" -foreground gray40
    pack $df.lf $df.from $df.lt $df.to $df.hint -side left -padx {0 4}
    grid $p.ldate $df -sticky w -padx 2 -pady 2

    ttk::label $p.lenc -text "Encoding:"
    ttk::combobox $p.enc -textvariable ::srtool::opt(encoding) \
        -values [lsort [encoding names]] -width 14
    grid $p.lenc $p.enc -sticky w -padx 2 -pady 2

    ttk::label $p.led -text "Editor:"
    ttk::entry $p.ed -textvariable ::srtool::opt(editor)
    grid $p.led $p.ed -sticky ew -padx 2 -pady 2

    # Zwei Reihen statt einer. Gemessen brauchten die sieben Schalter
    # 866 px nebeneinander; Tk schneidet nicht ab, sondern stellt gar
    # nicht dar, was nicht hineinpasst -- unter etwa 900 px
    # Fensterbreite waren "Backup" und "Nur Dateinamen" weg.
    #
    # Erste Reihe: was die SUCHE bestimmt. Zweite: was beim ERSETZEN
    # passiert. Die Trennung ist nicht nur Platz: die untere Reihe
    # schreibt, die obere liest.
    set o [ttk::frame $p.opts]
    set o1 [ttk::frame $o.a]
    set o2 [ttk::frame $o.b]
    pack $o1 $o2 -side top -anchor w
    ttk::checkbutton $o1.case -text "Gross/Klein beachten" \
        -variable ::srtool::opt(case)
    ttk::checkbutton $o1.regex -text "Regex" -variable ::srtool::opt(regex)
    ttk::checkbutton $o1.rec  -text "Unterverz." -variable ::srtool::opt(recursive)
    ttk::checkbutton $o1.ml   -text "Mehrzeilig" -variable ::srtool::opt(multiline) \
        -command ::srtool::toggleMultiline
    ttk::checkbutton $o1.files -text "Nur Dateinamen" \
        -variable ::srtool::opt(filesonly) -command ::srtool::updateReplaceButtons
    pack $o1.case $o1.regex $o1.rec $o1.ml $o1.files -side left -padx 6
    ttk::checkbutton $o2.allow -text "Ersetzen erlauben" \
        -variable ::srtool::opt(allowReplace) -command ::srtool::updateReplaceButtons
    # Backup ist VORGABE AN. Der Bestaetigungsdialog sagt "kann nicht
    # rueckgaengig gemacht werden" -- dann soll die Sicherung nicht an
    # einem Haken haengen, den man vergessen kann. Wer sie nicht will,
    # macht ihn aus; das ist eine Entscheidung, kein Versehen.
    ttk::checkbutton $o2.bak -text "Backup (.bak)" -variable ::srtool::opt(backup)
    ttk::checkbutton $o2.bin -text "Binaerdateien einbeziehen" \
        -variable ::srtool::opt(binary)
    pack $o2.allow $o2.bak $o2.bin -side left -padx 6
    grid $o - - -sticky w -pady 2

    grid columnconfigure $p 1 -weight 1

    # --- middle: results | preview ---
    set pw [ttk::panedwindow .pw -orient horizontal]
    pack $pw -side top -fill both -expand 1

    set left [ttk::frame $pw.left]
    set tv [ttk::treeview $left.tv -columns {line hit} \
        -yscrollcommand [list $left.ys set] \
        -xscrollcommand [list $left.xs set]]
    $tv heading #0 -text "Datei/Verzeichnis"
    $tv heading line -text "Zeile"
    $tv heading hit -text "Treffer"
    # #0 breiter und mit -stretch 0, damit ein langer Pfad nicht auf
    # Kosten der Trefferspalte gequetscht wird -- der Rollbalken unten
    # macht ihn erreichbar. Ohne den war ein abgeschnittener Pfad
    # endgueltig weg: man konnte nicht einmal hinsehen.
    $tv column #0 -width 340 -minwidth 120 -stretch 0 -anchor w
    $tv column line -width 60 -minwidth 40 -stretch 0 -anchor e
    $tv column hit -width 420 -minwidth 100 -stretch 1 -anchor w
    $tv tag configure dir  -foreground "#1a4f8b"
    # Treffer nicht mehr dunkelrot: die Auswahl faerbt den Hintergrund
    # blau, und Rot auf Blau ist kaum zu lesen. Schwarzer Text, und die
    # STELLE ist im Vorschaufenster gelb markiert -- dort, wo man
    # hinsieht.
    $tv tag configure hit  -foreground "#202020"
    ttk::scrollbar $left.ys -orient vertical -command [list $tv yview]
    ttk::scrollbar $left.xs -orient horizontal -command [list $tv xview]
    grid $tv $left.ys -sticky nsew
    grid $left.xs -row 1 -column 0 -sticky ew
    grid rowconfigure $left 0 -weight 1
    grid columnconfigure $left 0 -weight 1

    # Der volle Pfad des ausgewaehlten Knotens, unter dem Baum.
    #
    # Der Baum zeigt den Pfad relativ und gekuerzt; wer wissen will, WO
    # die Datei liegt, soll nicht raten muessen. Eine Zeile, die immer
    # da ist, ist besser als ein Tooltip, den man erst treffen muss.
    ttk::label $left.path -textvariable ::srtool::selPath -anchor w \
        -padding {2 2} -relief sunken
    grid $left.path -row 2 -column 0 -columnspan 2 -sticky ew

    set right [ttk::frame $pw.right]
    text $right.t -wrap none -font TkFixedFont \
        -yscrollcommand [list $right.ys set] -xscrollcommand [list $right.xs set]
    $right.t tag configure hitline -background "#dce8ff"
    $right.t tag configure match -background "#fff3a0"
    $right.t tag configure lineno -foreground "#888888"
    $right.t configure -state disabled
    ttk::scrollbar $right.ys -orient vertical -command [list $right.t yview]
    ttk::scrollbar $right.xs -orient horizontal -command [list $right.t xview]
    grid $right.t $right.ys -sticky nsew
    grid $right.xs -sticky ew
    grid rowconfigure $right 0 -weight 1
    grid columnconfigure $right 0 -weight 1

    $pw add $left
    $pw add $right

    # Eine Zeile fuer das, was uebersprungen oder umgangen wurde.
    # Sichtbar, aber nicht laut -- sie ist leer, solange nichts zu sagen
    # ist.
    ttk::label .hint -textvariable ::srtool::hinweisText -anchor w \
        -foreground "#a04000" -padding {6 0}

    # --- status ---
    set st [::tkutils::tkustatus::widget .st]

    # DIE REIHENFOLGE ZAEHLT. pack verteilt in der Reihenfolge der
    # Aufrufe: was zuerst gepackt wird, bekommt seinen Platz zuerst, und
    # was mit -expand 1 gepackt ist, bekommt den Rest.
    #
    # .pw stand vorher VOR der Statusleiste und nahm sich den Raum; als
    # der Parameterblock um zwanzig Pixel wuchs, blieb fuer die
    # Statusleiste nichts uebrig -- gemessen 1 px hoch statt 21. Eine
    # Zeile, die es gibt und die niemand sieht, ist dasselbe wie eine
    # Option, die nichts tut.
    #
    # Also: erst die festen Streifen unten, dann die Flaeche, die den
    # Rest nimmt.
    pack forget .pw
    pack $st -side bottom -fill x
    pack .hint -side bottom -fill x
    pack .pw -side top -fill both -expand 1
    ::tkutils::tkustatus::addField $st files -width 18
    # Eigenes Feld fuer die Trefferzahl. Vorher stand sie nur im
    # Haupttext und verschwand hinter einem langen Pfad oder hinter der
    # flash-Meldung nach dem Ersetzen.
    ::tkutils::tkustatus::addField $st hit -width 16
    ::tkutils::tkustatus::setText $st "Bereit."

    # --- Kontextmenue Baum ---
    set m [menu .ctx -tearoff 0]
    $m add command -label "Im eingebauten Editor oeffnen" -command ::srtool::openInBuiltinEditor
    $m add command -label "Im Editor oeffnen (extern)" -command ::srtool::openInEditor
    $m add command -label "Datei oeffnen (extern)" -command ::srtool::openExternal
    $m add command -label "Ordner im Explorer oeffnen" -command ::srtool::openFolder
    $m add separator
    $m add command -label "Vollen Pfad kopieren" -command ::srtool::copyPath
    $m add command -label "Dateinamen kopieren" -command ::srtool::copyName
    $m add command -label "Trefferzeile kopieren" -command ::srtool::copyHitLine
    $m add command -label "Alle Treffer kopieren" -command ::srtool::copyAllHits
    $m add separator
    $m add command -label "Alle aufklappen" -command {::srtool::expandAll 1}
    $m add command -label "Alle zuklappen" -command {::srtool::expandAll 0}

    # --- Kontextmenue Vorschau ---
    #
    # Es gab keins. Man sah den Fund und konnte ihn nicht mitnehmen --
    # bei einem Werkzeug, das zum Finden da ist, die naheliegendste
    # Handlung.
    set mv [menu .ctxview -tearoff 0]
    $mv add command -label "Auswahl kopieren" -accelerator Strg+C \
        -command {::srtool::copySelection .pw.right.t}
    $mv add command -label "Zeile kopieren" -command ::srtool::copyPreviewLine
    $mv add command -label "Alles kopieren" \
        -command {::srtool::copyAll .pw.right.t}
    $mv add separator
    $mv add command -label "Alles markieren" -accelerator Strg+A \
        -command {.pw.right.t tag add sel 1.0 end}

    # --- Kontextmenue Eingabefelder ---
    #
    # Ausschneiden, Kopieren, Einfuegen. Tk kann das ueber die
    # Standardbindungen, aber ohne Menue findet es nur, wer die
    # Tastenkuerzel kennt.
    set me [menu .ctxentry -tearoff 0]
    $me add command -label "Ausschneiden" -accelerator Strg+X \
        -command {::srtool::entryEdit cut}
    $me add command -label "Kopieren" -accelerator Strg+C \
        -command {::srtool::entryEdit copy}
    $me add command -label "Einfuegen" -accelerator Strg+V \
        -command {::srtool::entryEdit paste}
    $me add separator
    $me add command -label "Alles markieren" \
        -command {::srtool::entryEdit selectall}

    # bindings
    bind $tv <<TreeviewSelect>> ::srtool::onSelect
    bind $tv <Double-1> ::srtool::openInBuiltinEditor
    # Rechtsklick WAEHLT den Knoten unter dem Zeiger.
    #
    # Vorher tat er das nicht: das Menue wirkte auf das, was VORHER
    # ausgewaehlt war. Wer auf eine andere Datei rechtsklickte und
    # "Im Editor oeffnen" waehlte, bekam die alte -- und beim Kopieren
    # den falschen Pfad in der Zwischenablage, ohne es zu merken.
    bind $tv <Button-3> {::srtool::treePopup %W %x %y %X %Y}
    # Alle Eingabefelder, auch die mehrzeiligen. Namen aus dem Aufbau
    # abgeschrieben und NICHT geraten -- beim ersten Anlauf stand hier
    # ".params.pattern", und das Feld heisst ".params.pat".
    foreach __w [list $p.dir $p.search $p.repl $p.pat $p.ed \
                      $p.searchml $p.replml] {
        if {[winfo exists $__w]} {
            bind $__w <Button-3> {::srtool::entryPopup %W %X %Y}
        }
    }
    bind .pw.right.t <Button-3> {::srtool::viewPopup %W %X %Y}
    bind . <Control-f> {focus .params.search ; break}
    bind . <Escape> {::srtool::onEscape}
    bind . <F3> {::srtool::nextHit 1 ; break}
    bind . <Shift-F3> {::srtool::nextHit -1 ; break}
    bind $p.search <Return> ::srtool::doSearch
    bind $p.searchml <Control-Return> ::srtool::doSearch
    bind $p.repl <KeyRelease> ::srtool::updateReplaceButtons
    bind $p.replml <KeyRelease> ::srtool::updateReplaceButtons

    toggleMultiline
}

proc ::srtool::toggleMultiline {} {
    variable opt
    set p .params
    # Den INHALT mitnehmen. Vorher tauschte diese Prozedur nur die
    # Widgets im Gitter: wer einzeilig tippte und dann "Mehrzeilig"
    # ankreuzte, suchte mit leerem Text -- und umgekehrt suchte er nach
    # dem alten einzeiligen Text weiter. Ein stiller Verlust der
    # Eingabe, und das schlimmste daran ist, dass das Feld daneben
    # gefuellt aussieht.
    if {$opt(multiline)} {
        foreach {von nach} [list $p.search $p.searchml $p.repl $p.replml] {
            set t [$von get]
            $nach delete 1.0 end
            if {$t ne ""} { $nach insert end $t }
        }
    } else {
        foreach {von nach} [list $p.searchml $p.search $p.replml $p.repl] {
            set t [string trimright [$von get 1.0 end] "\n"]
            # Beim Zurueckschalten geht alles ab der ersten Zeile
            # verloren -- ein Entry kann nur eine. Das ist unvermeidlich,
            # aber es soll die ERSTE sein und nicht gar nichts.
            set t [lindex [split $t "\n"] 0]
            $nach delete 0 end
            if {$t ne ""} { $nach insert 0 $t }
        }
    }
    if {$opt(multiline)} {
        grid forget $p.search
        grid $p.searchml $p.searchsb -row 1 -column 1 -sticky ew -padx 2 -pady 2
        grid forget $p.repl
        grid $p.replml $p.replsb -row 2 -column 1 -sticky ew -padx 2 -pady 2
    } else {
        grid forget $p.searchml $p.searchsb
        grid $p.search -row 1 -column 1 -sticky ew -padx 2 -pady 2
        grid forget $p.replml $p.replsb
        grid $p.repl -row 2 -column 1 -sticky ew -padx 2 -pady 2
    }
}

proc ::srtool::getSearch {} {
    variable opt
    if {$opt(multiline) && [winfo exists .params.searchml]} {
        return [string trimright [.params.searchml get 1.0 end] "\n"]
    }
    return $opt(search)
}
proc ::srtool::getReplace {} {
    variable opt
    if {$opt(multiline) && [winfo exists .params.replml]} {
        return [string trimright [.params.replml get 1.0 end] "\n"]
    }
    return $opt(replace)
}

# Enable the replace buttons only when all guards pass:
#   stage 4: the "Ersetzen erlauben" switch is on
#   stage 1: a search produced hits (results non-empty)
#   stage 2: the replacement field is not empty (no accidental delete-by-empty)
proc ::srtool::updateReplaceButtons {} {
    variable opt
    variable results
    variable tbPath
    if {$tbPath eq "" || ![winfo exists $tbPath]} return
    set ok [expr {!$opt(filesonly) && $opt(allowReplace) && [llength $results] > 0 \
                  && [string length [getReplace]] > 0}]
    ::tkutils::tkutoolbar::setEnabled $tbPath repall $ok
    ::tkutils::tkutoolbar::setEnabled $tbPath repsel $ok
}

proc ::srtool::chooseDir {} {
    variable opt
    set d [tk_chooseDirectory -initialdir $opt(dir) -title "Verzeichnis waehlen"]
    if {$d ne ""} { set opt(dir) $d }
}

proc ::srtool::clearResults {} {
    array unset ::srtool::dirNodes
    array set ::srtool::dirNodes {}
    variable results
    variable cache
    variable itemInfo
    set results {}
    array unset cache
    array unset itemInfo
    array set cache {}
    array set itemInfo {}
    .pw.left.tv delete [.pw.left.tv children {}]
    .pw.right.t configure -state normal
    .pw.right.t delete 1.0 end
    .pw.right.t configure -state disabled
    ::tkutils::tkustatus::setText .st "Bereit."
    ::tkutils::tkustatus::setField .st files ""
    updateReplaceButtons
}

proc ::srtool::doSearch {} {
    variable opt
    variable results
    variable searching
    variable cancel
    if {$searching} return
    set needle [getSearch]
    if {$needle eq "" && !$opt(filesonly)} {
        ::tkutils::tkudialog::showWarning "Bitte einen Suchtext eingeben."
        return
    }
    if {![file isdirectory $opt(dir)]} {
        ::tkutils::tkudialog::showError "Verzeichnis nicht gefunden:\n$opt(dir)"
        return
    }
    clearResults
    set opts [currentOpts]
    set names $opt(filesonly)
    if {[catch {_dateBounds $opts} bounds]} {
        ::tkutils::tkudialog::showWarning \
            "Ungueltiges Datum. Bitte Format JJJJ-MM-TT verwenden (Felder leer = keine Grenze)."
        return
    }
    if {[catch {collectFiles $opt(dir) $opt(pattern) $opt(recursive)} files err]} {
        ::tkutils::tkudialog::showError "Suchfehler:\n[dict get $err -errorinfo]"
        return
    }
    set total [llength $files]
    set results {}
    set searching 1
    set cancel 0
    _searchSetBusy 1
    set i 0
    set hitsN 0
    set reFehler 0
    set reText ""
    set gezeigt 0
    set ersterGezeigt 0
    set fallbacks {}
    set binaer 0
    foreach f $files {
        incr i
        if {[_dateFileOk $f $bounds]} {
            if {$names} {
                if {[_nameMatch [file tail $f] $needle $opts]} {
                    lappend results [list $f {}]
                }
            } else {
                if {[catch {searchFile $f $needle $opts} hits]} {
                    # Ein ungueltiger regulaerer Ausdruck ergab vorher
                    # NULL TREFFER ohne ein Wort -- die Suche sah aus,
                    # als gaebe es nichts zu finden. Beim ersten Mal
                    # gemeldet und dann abgebrochen: derselbe Fehler
                    # wiederholt sich in jeder Datei.
                    if {!$reFehler} {
                        set reFehler 1
                        set reText $hits
                    }
                    set hits {}
                }
                if {[llength $hits]} {
                    lappend results [list $f $hits]
                    incr hitsN [llength $hits]
                }
                # Was beim Lesen auffiel, wird GEZAEHLT statt
                # geschluckt: eine Datei, die nur ueber den
                # iso8859-1-Rueckfall lesbar war, und eine, die
                # binaer ist.
                if {[dict exists $::srtool::lastRead fallback] &&
                    [dict get $::srtool::lastRead fallback]} {
                    lappend fallbacks [file tail $f]
                }
                if {[dict exists $::srtool::lastRead binary] &&
                    [dict get $::srtool::lastRead binary]} {
                    incr binaer
                }
            }
        }
        # Den Baum WAEHREND der Suche wachsen lassen, nicht erst danach.
        #
        # Vorher lief populateTree nach der letzten Datei; bei einem
        # grossen Baum sah man minutenlang nichts als eine Zahl. Jetzt
        # wird jede Datei mit Treffern sofort angehaengt -- und der
        # erste Treffer wird gewaehlt, sobald es einen gibt.
        if {[llength $results] > $gezeigt} {
            for {set k $gezeigt} {$k < [llength $results]} {incr k} {
                ::srtool::addResultNode [lindex $results $k]
            }
            set gezeigt [llength $results]
            if {!$ersterGezeigt} {
                set ersterGezeigt [::srtool::selectFirstHit]
            }
        }
        # keep the UI responsive and let the Abbrechen button / Escape through
        if {$i % 20 == 0} {
            set prog [expr {$names ? "[llength $results] Datei(en)" \
                                    : "$hitsN Treffer"}]
            catch {::tkutils::tkustatus::setText .st "Suche... $i/$total Dateien, $prog"}
            catch {::tkutils::tkustatus::progress .st $i $total}
            update
            if {$cancel} break
        }
    }
    set searching 0
    _searchSetBusy 0
    # Nicht mehr populateTree: der Baum ist waehrend des Laufs gewachsen.
    # Nur der Rest, den die letzte Runde nicht mehr angehaengt hat.
    for {set k $gezeigt} {$k < [llength $results]} {incr k} {
        ::srtool::addResultNode [lindex $results $k]
    }
    catch {::tkutils::tkustatus::progress .st 0 0}
    set fn [llength $results]
    set pre [expr {$cancel ? "Abgebrochen -- " : ""}]
    set suf [expr {$cancel ? " ($i/$total durchsucht)" : ""}]
    if {$names} {
        ::tkutils::tkustatus::setText .st "$pre$fn Datei(en) gefunden$suf."
    } else {
        ::tkutils::tkustatus::setText .st "$pre$hitsN Treffer in $fn Datei(en)$suf."
    }
    ::tkutils::tkustatus::setField .st files "$fn Datei(en)"
    # Der erste Treffer ist schon gewaehlt -- die Schleife oben tut das,
    # sobald es einen gibt. Hier stand derselbe Aufruf noch einmal, und
    # die Gegenprobe "ersten Treffer nicht waehlen" blieb deshalb gruen:
    # sie traf nur eine von zwei Stellen. Zwei Wege fuer dieselbe Sache
    # sind einer zuviel.
    # Was uebersprungen oder umgangen wurde, gehoert in die Anzeige --
    # nicht in ein catch. Eine Suche, die schweigt, sieht aus wie eine
    # Suche, die nichts gefunden hat.
    set hinweise {}
    if {$binaer} { lappend hinweise "$binaer Binaerdatei(en) uebersprungen" }
    if {[llength $fallbacks]} {
        lappend hinweise "[llength $fallbacks] Datei(en) nur als iso8859-1\
                lesbar (z.B. [lindex $fallbacks 0])"
    }
    set ::srtool::hinweisText [join $hinweise " -- "]
    catch {.hint configure -text $::srtool::hinweisText}
    if {$reFehler} {
        ::tkutils::tkudialog::showWarning \
            "Der Suchausdruck ist als regulaerer Ausdruck ungueltig:\n\n$reText"
    }
    updateReplaceButtons
}

# Request abort of the running search (Abbrechen button / Escape while busy).
proc ::srtool::cancelSearch {} {
    variable searching
    variable cancel
    if {$searching} {
        set cancel 1
        catch {::tkutils::tkustatus::setText .st "Abbruch..."}
    }
}

# Toggle the toolbar between idle and searching state.
proc ::srtool::_searchSetBusy {busy} {
    variable tbPath
    if {$tbPath eq "" || ![winfo exists $tbPath]} return
    catch {::tkutils::tkutoolbar::setEnabled $tbPath search [expr {!$busy}]}
    catch {::tkutils::tkutoolbar::setEnabled $tbPath cancel $busy}
    if {$busy} {
        catch {::tkutils::tkutoolbar::setEnabled $tbPath repall 0}
        catch {::tkutils::tkutoolbar::setEnabled $tbPath repsel 0}
    }
}

# Escape: abort a running search, otherwise clear the results.
proc ::srtool::onEscape {} {
    variable searching
    variable results
    if {$searching} {
        cancelSearch
        return
    }
    # Im Ruhezustand loeschte Esc vorher wortlos die Trefferliste. Nach
    # einer langen Suche ist das ein Datenverlust ohne Nachfrage -- und
    # Esc ist die Taste, die man drueckt, um einen Dialog wegzubekommen.
    if {![llength $results]} { return }
    if {[::tkutils::tkudialog::confirm \
            "Trefferliste leeren?\n\n[llength $results] Datei(en)."]} {
        clearResults
    }
}

# Alle Trefferknoten in Anzeigereihenfolge -- die Grundlage fuer
# "erster Treffer" und fuer F3.
proc ::srtool::hitNodes {} {
    variable itemInfo
    set tv .pw.left.tv
    set out {}
    foreach d [$tv children {}] {
        foreach f [$tv children $d] {
            foreach h [$tv children $f] { lappend out $h }
            # Im Dateinamen-Modus gibt es keine Trefferzeilen; dann ist
            # die Datei selbst der Treffer.
            if {![llength [$tv children $f]]} { lappend out $f }
        }
    }
    return $out
}

proc ::srtool::selectFirstHit {} {
    set nodes [::srtool::hitNodes]
    if {![llength $nodes]} { return 0 }
    ::srtool::gotoHit [lindex $nodes 0]
    return 1
}

proc ::srtool::gotoHit {node} {
    set tv .pw.left.tv
    if {$node eq "" || ![$tv exists $node]} { return }
    $tv selection set $node
    $tv focus $node
    $tv see $node
    ::srtool::onSelect
    ::srtool::showHitCount
}

# "Treffer k von N" -- eine Zahl, an der man sieht, wo man ist.
proc ::srtool::showHitCount {} {
    set nodes [::srtool::hitNodes]
    set n [llength $nodes]
    if {!$n} { return }
    set sel [lindex [.pw.left.tv selection] 0]
    set k [lsearch -exact $nodes $sel]
    if {$k < 0} { return }
    catch {::tkutils::tkustatus::setField .st hit "Treffer [expr {$k+1}]/$n"}
}

# Weiter und zurueck. Laeuft um: nach dem letzten kommt der erste. Das
# ist bei einer Trefferliste die uebliche Erwartung -- wer am Ende
# stehenbleibt, weiss nicht, ob er fertig ist oder die Taste klemmt.
proc ::srtool::nextHit {{schritt 1}} {
    set nodes [::srtool::hitNodes]
    set n [llength $nodes]
    if {!$n} { return }
    set sel [lindex [.pw.left.tv selection] 0]
    set k [lsearch -exact $nodes $sel]
    if {$k < 0} { set k [expr {$schritt > 0 ? -1 : 0}] }
    set k [expr {($k + $schritt + $n) % $n}]
    ::srtool::gotoHit [lindex $nodes $k]
}

# Eine Ergebniszeile anhaengen. Herausgeloest aus populateTree, damit
# sie WAEHREND der Suche gerufen werden kann -- eine Prozedur fuer
# beides, nicht zwei, die auseinanderlaufen.
proc ::srtool::addResultNode {pair} {
    variable itemInfo
    variable dirNodes
    set tv .pw.left.tv
    set wurzel [file normalize $::srtool::opt(dir)]
    lassign $pair file hits
    set dir [file dirname $file]
    if {![info exists dirNodes($dir)]} {
        set dirNodes($dir) [$tv insert {} end -open 1 -tags dir \
            -text [::srtool::relPath $dir $wurzel] -values [list "" ""]]
    }
    set dn $dirNodes($dir)
    set lbl [expr {[llength $hits] ? "([llength $hits] Treffer)" : "Datei"}]
    set fn [$tv insert $dn end -text [file tail $file] -open 1 \
        -values [list "" $lbl]]
    set itemInfo($fn) [list file $file line ""]
    foreach hit $hits {
        set hn [$tv insert $fn end -tags hit \
            -text "Zeile [dict get $hit line]" \
            -values [list [dict get $hit line] [dict get $hit text]]]
        set itemInfo($hn) [list file $file line [dict get $hit line]]
    }
    # Die Trefferzahl am Ordnerknoten mitzaehlen.
    set bisher 0
    regexp {^(\d+)} [lindex [$tv item $dn -values] 1] -> bisher
    set dazu [expr {[llength $hits] ? [llength $hits] : 1}]
    $tv item $dn -values [list "" "[expr {$bisher + $dazu}] Treffer"]
}

proc ::srtool::populateTree {} {
    variable results
    variable itemInfo
    variable dirNodes
    set tv .pw.left.tv
    $tv delete [$tv children {}]
    array unset itemInfo
    array set itemInfo {}
    array unset dirNodes
    array set dirNodes {}
    # Der Pfad RELATIV zur Suchwurzel. Vorher stand dort der absolute,
    # und ohne Horizontal-Rollbalken war er abgeschnitten -- bei
    # /home/greg/Project/2026/code/... sah man von der Spalte nichts
    # ausser dem Anfang, der bei allen Knoten gleich ist.
    set wurzel [file normalize $::srtool::opt(dir)]
    set dirNodes [dict create]
    set dirHits [dict create]
    foreach pair $results {
        lassign $pair file hits
        set dir [file dirname $file]
        dict incr dirHits $dir [expr {[llength $hits] ? [llength $hits] : 1}]
    }
    foreach pair $results {
        lassign $pair file hits
        set dir [file dirname $file]
        if {![dict exists $dirNodes $dir]} {
            set kurz [::srtool::relPath $dir $wurzel]
            set dn [$tv insert {} end -open 1 -tags dir \
                -text $kurz -values [list "" "[dict get $dirHits $dir] Treffer"]]
            dict set dirNodes $dir $dn
        }
        set dn [dict get $dirNodes $dir]
        set lbl [expr {[llength $hits] ? "([llength $hits] Treffer)" : "Datei"}]
        set fn [$tv insert $dn end -text [file tail $file] -open 1 \
            -values [list "" $lbl]]
        set itemInfo($fn) [list file $file line ""]
        foreach hit $hits {
            # Die Spalte #0 war bei Trefferzeilen LEER -- nur Einrueckung.
            # Jetzt steht die Zeilennummer dort, wo das Auge sie sucht.
            set hn [$tv insert $fn end -tags hit \
                -text "Zeile [dict get $hit line]" \
                -values [list [dict get $hit line] [dict get $hit text]]]
            set itemInfo($hn) [list file $file line [dict get $hit line]]
        }
    }
}

# Ein Pfad relativ zur Suchwurzel. Liegt er ausserhalb, bleibt er
# absolut -- ein "../../.." waere unleserlicher als der ganze Pfad.
proc ::srtool::relPath {pfad wurzel} {
    set pfad [file normalize $pfad]
    if {$pfad eq $wurzel} { return "." }
    set w [file split $wurzel]
    set p [file split $pfad]
    if {[llength $p] > [llength $w] &&
        [lrange $p 0 [expr {[llength $w]-1}]] eq $w} {
        return [file join {*}[lrange $p [llength $w] end]]
    }
    return $pfad
}

proc ::srtool::onSelect {} {
    variable itemInfo
    set sel [.pw.left.tv selection]
    if {$sel eq ""} return
    set item [lindex $sel 0]
    if {![info exists itemInfo($item)]} return
    set file [dict get $itemInfo($item) file]
    set line [dict get $itemInfo($item) line]
    set ::srtool::selPath [expr {$line eq "" ? $file : "$file : $line"}]
    showPreview $file $line
    ::srtool::showHitCount
}

# Wieviele Zeilen die Vorschau hoechstens zeigt.
#
# Gemessen an einer Datei mit 200000 Zeilen (5 MB): showPreview brauchte
# 1596 ms und baute 200002 Zeilen ins Widget. Waehrenddessen steht die
# Anwendung -- und zwar bei JEDEM Klick auf einen Treffer, weil die
# Vorschau jedes Mal neu aufgebaut wird.
#
# Gezeigt wird stattdessen die UMGEBUNG der Trefferzeile. Wer die ganze
# Datei will, hat den eingebauten Editor im Kontextmenue; die Vorschau
# ist zum Hinsehen da, nicht zum Lesen.
namespace eval ::srtool {
    variable previewMax 2000
    variable previewAround 400
}

proc ::srtool::showPreview {file line} {
    variable opt
    variable cache
    variable previewMax
    variable previewAround
    if {![info exists cache($file)]} {
        set cache($file) [readFileEnc $file $opt(encoding)]
    }
    set alle [split $cache($file) "\n"]
    set gesamt [llength $alle]

    # Welcher Ausschnitt? Ohne Trefferzeile der Anfang, sonst die
    # Umgebung. Die Zeilennummern bleiben die ECHTEN -- eine Vorschau,
    # die bei 1 zu zaehlen anfaengt, waehrend der Treffer in Zeile 4711
    # steht, ist schlimmer als keine.
    set von 1
    set bis $gesamt
    set gekuerzt 0
    if {$gesamt > $previewMax} {
        set gekuerzt 1
        if {$line ne ""} {
            set mitte [lindex [split $line -] 0]
            set von [expr {max(1, $mitte - $previewAround)}]
            set bis [expr {min($gesamt, $mitte + $previewAround)}]
        } else {
            set bis $previewMax
        }
    }

    set t .pw.right.t
    $t configure -state normal
    $t delete 1.0 end
    if {$gekuerzt && $von > 1} {
        $t insert end "   ... Zeilen 1 bis [expr {$von - 1}] nicht gezeigt\n" lineno
    }
    set n [expr {$von - 1}]
    foreach l [lrange $alle [expr {$von - 1}] [expr {$bis - 1}]] {
        incr n
        $t insert end [format "%5d  " $n] lineno
        $t insert end "$l\n"
    }
    if {$gekuerzt && $bis < $gesamt} {
        $t insert end "   ... Zeilen [expr {$bis + 1}] bis $gesamt nicht gezeigt\n" lineno
    }
    $t configure -state disabled
    if {$gekuerzt} {
        set ::srtool::hinweisText "Vorschau gekuerzt: Zeilen $von-$bis von\
                $gesamt -- die ganze Datei im Editor (Kontextmenue)"
        catch {.hint configure -text $::srtool::hinweisText}
    }
    if {$line ne ""} {
        set first [lindex [split $line -] 0]
        set last [lindex [split $line -] end]
        # Die Zeile im WIDGET ist nicht die Zeile in der DATEI, sobald
        # gekuerzt wurde. Ein Versatz, der genau einmal gerechnet wird.
        set versatz [expr {$von - 1 - ($gekuerzt && $von > 1 ? 1 : 0)}]
        set first [expr {$first - $versatz}]
        set last [expr {$last - $versatz}]
        $t tag add hitline $first.0 [expr {$last + 1}].0
        $t see $first.0
        # mark the matches within the hit line(s) yellow
        catch {
            set needle [getSearch]
            if {$needle ne "" && [string first "\n" $needle] < 0} {
                set mode [expr {$opt(regex) ? "-regexp" : "-exact"}]
                set ci [expr {$opt(case) ? {} : {-nocase}}]
                set idx $first.0
                set stop [expr {$last + 1}].0
                while {1} {
                    set pos [$t search {*}$mode {*}$ci -count cnt -- \
                        $needle $idx $stop]
                    if {$pos eq "" || $cnt == 0} break
                    $t tag add match $pos "$pos + $cnt chars"
                    set idx "$pos + $cnt chars"
                }
            }
        }
    }
}

proc ::srtool::selectedFiles {} {
    variable itemInfo
    set files {}
    foreach item [.pw.left.tv selection] {
        if {[info exists itemInfo($item)]} {
            lappend files [dict get $itemInfo($item) file]
        }
    }
    return [lsort -unique $files]
}

proc ::srtool::doReplaceAll {} {
    variable results
    if {![llength $results]} { return }
    set files {}
    foreach pair $results { lappend files [lindex $pair 0] }
    _replace $files "Alle [countHits $results] Treffer in [llength $files] Datei(en) ersetzen?"
}

proc ::srtool::doReplaceSelected {} {
    set files [selectedFiles]
    if {![llength $files]} {
        ::tkutils::tkudialog::showWarning "Keine Auswahl im Ergebnisbaum."
        return
    }
    _replace $files "Treffer in [llength $files] ausgewaehlten Datei(en) ersetzen?"
}

proc ::srtool::_replace {files question} {
    set needle [getSearch]
    if {$needle eq ""} return
    if {![::tkutils::tkudialog::confirm "$question\n\nAchtung: kann nicht rueckgaengig gemacht werden!"]} {
        return
    }
    set repl [getReplace]
    set total 0
    set touched 0
    foreach f $files {
        if {[catch {replaceInFile $f $needle $repl [currentOpts]} c]} continue
        incr total $c
        if {$c > 0} { incr touched }
    }
    ::tkutils::tkustatus::flash .st "$total Ersetzung(en) in $touched Datei(en)." 3000
    doSearch
}

proc ::srtool::expandAll {open} {
    set tv .pw.left.tv
    foreach item [_allItems $tv {}] { $tv item $item -open $open }
}
proc ::srtool::_allItems {tv node} {
    set acc {}
    foreach c [$tv children $node] {
        lappend acc $c
        lappend acc {*}[_allItems $tv $c]
    }
    return $acc
}

proc ::srtool::_selectedFile {} {
    variable itemInfo
    set sel [.pw.left.tv selection]
    if {$sel eq ""} { return "" }
    set item [lindex $sel 0]
    if {![info exists itemInfo($item)]} { return "" }
    return [dict get $itemInfo($item) file]
}

proc ::srtool::openExternal {} {
    set f [_selectedFile]
    if {$f eq ""} return
    # open with the OS default application (xdg-open / open / cmd start)
    if {[catch {::tclutils::tuopen::launch $f} err]} {
        ::tkutils::tkudialog::showError "Datei konnte nicht geoeffnet werden:\n$err"
    }
}

proc ::srtool::openInEditor {} {
    set f [_selectedFile]
    if {$f eq ""} return
    set ed [resolveEditor]
    if {$ed eq ""} {
        ::tkutils::tkudialog::showError \
            "Kein Editor gefunden.\nBitte im Feld \"Editor\" einen Befehl eintragen\n(z.B. gedit, kate, mousepad, code)."
        return
    }
    # pass -editor explicitly so tuopen does NOT fall back to xdg-open
    # (xdg-open would launch the OS default handler, not necessarily an editor)
    if {[catch {::tclutils::tuopen::edit $f -editor $ed} err]} {
        ::tkutils::tkudialog::showError "Editor konnte nicht geoeffnet werden:\n$err"
    }
}

# Open the hit's directory in the OS file manager (Explorer / Finder / ...).
proc ::srtool::openFolder {} {
    set f [_selectedFile]
    if {$f eq ""} return
    if {[catch {::tclutils::tuopen::openDir $f} err]} {
        ::tkutils::tkudialog::showError "Ordner konnte nicht geoeffnet werden:\n$err"
    }
}

# Open the selected file in a built-in tkueditor window (no external program,
# no xdg-open). Jumps to the hit line and highlights the search term. The
# window is reused for subsequent files. Ctrl-S saves.
proc ::srtool::openInBuiltinEditor {} {
    variable itemInfo
    set f [_selectedFile]
    if {$f eq ""} return
    set line 1
    set sel [.pw.left.tv selection]
    if {$sel ne ""} {
        set it [lindex $sel 0]
        if {[info exists itemInfo($it)]} {
            set ln [dict get $itemInfo($it) line]
            if {[string is integer -strict $ln] && $ln >= 1} { set line $ln }
        }
    }
    set top .builtineditor
    if {![winfo exists $top]} {
        toplevel $top
        ::tkutils::tkueditor::widget $top.ed -width 100 -height 30
        pack $top.ed -fill both -expand 1
        bind $top <Control-s> [list ::srtool::_saveBuiltin $top.ed]
    }
    set ed $top.ed
    if {[catch {::tkutils::tkueditor::loadFile $ed $f} err]} {
        ::tkutils::tkudialog::showError "Datei konnte nicht geladen werden:\n$err"
        return
    }
    catch {::tkutils::tkueditor::highlightAll $ed [getSearch]}
    catch {::tkutils::tkueditor::gotoLine $ed $line}
    wm title $top "Editor - [file tail $f]   (Strg+S speichert)"
    raise $top
    focus $ed
}

proc ::srtool::_saveBuiltin {ed} {
    if {[catch {::tkutils::tkueditor::saveFile $ed} err]} {
        ::tkutils::tkudialog::showError "Speichern fehlgeschlagen:\n$err"
        return
    }
    ::tkutils::tkustatus::flash .st \
        "Gespeichert: [file tail [::tkutils::tkueditor::currentFile $ed]]" 2000
}

# Pick an editor command: explicit field > $EDITOR/$VISUAL > a known GUI editor.
# Deliberately never returns xdg-open (that is the "open external" action).
proc ::srtool::resolveEditor {} {
    variable opt
    if {[string trim $opt(editor)] ne ""} { return $opt(editor) }
    foreach v {EDITOR VISUAL} {
        if {[info exists ::env($v)] && $::env($v) ne ""} { return $::env($v) }
    }
    if {$::tcl_platform(platform) eq "windows"} { return notepad }
    if {[string match -nocase *darwin* $::tcl_platform(os)]} { return [list open -e] }
    # locate a known GUI editor via tclutils::tuexe (PATH + platform extensions)
    return [::tclutils::tuexe::find {code gedit kate mousepad geany xed kwrite gvim}]
}

# --- Kontextmenues: Aufklappen und Kopieren ----------------------------

# Rechtsklick im Baum. Waehlt ZUERST den Knoten unter dem Zeiger, dann
# klappt das Menue auf -- sonst wirkt es auf die vorherige Auswahl.
proc ::srtool::treePopup {tv x y X Y} {
    set item [$tv identify item $x $y]
    if {$item ne ""} {
        $tv selection set $item
        $tv focus $item
        ::srtool::onSelect
    }
    tk_popup .ctx $X $Y
}

proc ::srtool::viewPopup {w X Y} {
    tk_popup .ctxview $X $Y
}

# Fuer die Eingabefelder: das Menue muss wissen, WELCHES Feld gemeint
# ist. Ein Menue fuer alle, und der Zielpfad in einer Variablen.
proc ::srtool::entryPopup {w X Y} {
    set ::srtool::ctxTarget $w
    focus $w
    tk_popup .ctxentry $X $Y
}

proc ::srtool::entryEdit {was} {
    set w $::srtool::ctxTarget
    if {$w eq "" || ![winfo exists $w]} { return }
    set istText [expr {[winfo class $w] eq "Text"}]
    switch -- $was {
        cut   { if {$istText} {tk_textCut $w} else {tk_textCut $w} }
        copy  { if {$istText} {tk_textCopy $w} else {tk_textCopy $w} }
        paste { if {$istText} {tk_textPaste $w} else {tk_textPaste $w} }
        selectall {
            if {$istText} {
                $w tag add sel 1.0 end
            } else {
                $w selection range 0 end
            }
        }
    }
}

# In die Zwischenablage, und SAGEN, dass es drin ist. Ein Kopieren, das
# nichts meldet, laesst den Benutzer im Zweifel -- und er drueckt noch
# einmal.
proc ::srtool::toClipboard {text {was "kopiert"}} {
    if {$text eq ""} { return 0 }
    clipboard clear
    clipboard append -- $text
    set n [llength [split $text "\n"]]
    catch {::tkutils::tkustatus::setText .st \
        "$was: [expr {$n > 1 ? "$n Zeilen" : "[string length $text] Zeichen"}]"}
    return 1
}

proc ::srtool::copyName {} {
    variable itemInfo
    set item [lindex [.pw.left.tv selection] 0]
    if {$item eq "" || ![info exists itemInfo($item)]} { return }
    ::srtool::toClipboard [file tail [dict get $itemInfo($item) file]] \
        "Dateiname kopiert"
}

# Die Trefferzeile, wie sie im Baum steht: Datei, Zeilennummer, Text.
# Das ist das Format, das man in eine Notiz oder eine Meldung klebt.
proc ::srtool::copyHitLine {} {
    variable itemInfo
    set tv .pw.left.tv
    set item [lindex [$tv selection] 0]
    if {$item eq "" || ![info exists itemInfo($item)]} { return }
    set file [dict get $itemInfo($item) file]
    set line [dict get $itemInfo($item) line]
    if {$line eq ""} { return [::srtool::copyPath] }
    set text [lindex [$tv item $item -values] 1]
    ::srtool::toClipboard "$file:$line: $text" "Trefferzeile kopiert"
}

# Alle Treffer als Liste. Dasselbe Format wie eine Zeile, damit man
# beides ohne Nachdenken zusammenfuegen kann.
proc ::srtool::copyAllHits {} {
    variable results
    set out {}
    foreach pair $results {
        lassign $pair file hits
        if {![llength $hits]} {
            lappend out $file
            continue
        }
        foreach hit $hits {
            lappend out "$file:[dict get $hit line]: [dict get $hit text]"
        }
    }
    ::srtool::toClipboard [join $out "\n"] "Trefferliste kopiert"
}

proc ::srtool::copySelection {w} {
    if {[catch {$w get sel.first sel.last} t]} {
        # Ohne Markierung die Zeile, in der die Einfuegemarke steht --
        # das ist fast immer gemeint und besser als gar nichts.
        return [::srtool::copyPreviewLine]
    }
    ::srtool::toClipboard $t "Auswahl kopiert"
}

proc ::srtool::copyPreviewLine {} {
    set w .pw.right.t
    # Die markierte Trefferzeile, sonst die Zeile unter der Marke.
    set r [$w tag ranges hitline]
    if {[llength $r]} {
        set z [lindex [split [lindex $r 0] .] 0]
    } else {
        set z [lindex [split [$w index insert] .] 0]
    }
    ::srtool::toClipboard [string trimright [$w get $z.0 $z.end]] \
        "Zeile kopiert"
}

proc ::srtool::copyAll {w} {
    ::srtool::toClipboard [string trimright [$w get 1.0 end] "\n"] \
        "Vorschau kopiert"
}

proc ::srtool::treePopup_dummy {} {}

proc ::srtool::copyPath {} {
    set f [_selectedFile]
    if {$f eq ""} return
    clipboard clear
    clipboard append $f
}

# =============================================================================
# Build the GUI only when run as the main script (so tests can source us).
# =============================================================================
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    ::srtool::buildGui
}
