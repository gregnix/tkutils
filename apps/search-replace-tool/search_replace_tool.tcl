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
        editor {}
    }
    variable results {}      ;# list of {file {hitDict ...}}
    variable cache           ;# path -> content
    array set cache {}
    variable itemInfo        ;# tree item -> {file F line L}
    array set itemInfo {}
    variable tbPath ""       ;# toolbar widget path (for enabling replace buttons)
}

# =============================================================================
# Core logic (no Tk)
# =============================================================================

proc ::srtool::readFileEnc {path enc} {
    set ch ""
    if {[catch {
        set ch [open $path r]
        fconfigure $ch -encoding $enc
        set d [read $ch]
        close $ch
        set d
    } data]} {
        catch {close $ch}
        set ch [open $path r]
        fconfigure $ch -encoding iso8859-1
        set data [read $ch]
        close $ch
    }
    return $data
}

proc ::srtool::writeFileEnc {path content enc} {
    set ch [open $path w]
    fconfigure $ch -encoding $enc -translation lf
    puts -nonewline $ch $content
    close $ch
}

proc ::srtool::_skipDir {name} {
    expr {[string index $name 0] eq "." || $name eq "__pycache__"}
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
    set content [readFileEnc $path [dict get $opts encoding]]
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
    foreach f [collectFiles $dir $patterns [dict get $opts recursive]] {
        set hits [searchFile $f $needle $opts]
        if {[llength $hits]} { lappend out [list $f $hits] }
    }
    return $out
}

proc ::srtool::_escapeRe {s} {
    return [regsub -all {[\\^$.?*+()\[\]{}|]} $s {\\&}]
}

# Replace in one file. Returns the number of replacements (0 = file untouched).
proc ::srtool::replaceInFile {path needle replacement opts} {
    set enc [dict get $opts encoding]
    set content [readFileEnc $path $enc]
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
    if {$count > 0} { writeFileEnc $path $new $enc }
    return $count
}

# Build the options dict from the GUI/state variables.
proc ::srtool::currentOpts {} {
    variable opt
    return [dict create \
        case $opt(case) regex $opt(regex) recursive $opt(recursive) \
        multiline $opt(multiline) encoding $opt(encoding)]
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
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb repall   "Alle ersetzen"      ::srtool::doReplaceAll
    ::tkutils::tkutoolbar::addButton $tb repsel   "Ausgewaehlte ersetzen" ::srtool::doReplaceSelected
    ::tkutils::tkutoolbar::addSeparator $tb
    ::tkutils::tkutoolbar::addButton $tb clear    "Leeren"             ::srtool::clearResults
    # safeguard stage 1: replace buttons start disabled, enabled only when the
    # "Ersetzen erlauben" switch is on AND a search produced hits AND the
    # replacement field is non-empty (see updateReplaceButtons).
    set ::srtool::tbPath $tb
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

    ttk::label $p.lenc -text "Encoding:"
    ttk::combobox $p.enc -textvariable ::srtool::opt(encoding) \
        -values [lsort [encoding names]] -width 14
    grid $p.lenc $p.enc -sticky w -padx 2 -pady 2

    ttk::label $p.led -text "Editor:"
    ttk::entry $p.ed -textvariable ::srtool::opt(editor)
    grid $p.led $p.ed -sticky ew -padx 2 -pady 2

    set o [ttk::frame $p.opts]
    ttk::checkbutton $o.case -text "Gross/Klein" -variable ::srtool::opt(case)
    ttk::checkbutton $o.regex -text "Regex" -variable ::srtool::opt(regex)
    ttk::checkbutton $o.rec  -text "Unterverz." -variable ::srtool::opt(recursive)
    ttk::checkbutton $o.ml   -text "Mehrzeilig" -variable ::srtool::opt(multiline) \
        -command ::srtool::toggleMultiline
    ttk::checkbutton $o.allow -text "Ersetzen erlauben" \
        -variable ::srtool::opt(allowReplace) -command ::srtool::updateReplaceButtons
    pack $o.case $o.regex $o.rec $o.ml $o.allow -side left -padx 6
    grid $o - - -sticky w -pady 2

    grid columnconfigure $p 1 -weight 1

    # --- middle: results | preview ---
    set pw [ttk::panedwindow .pw -orient horizontal]
    pack $pw -side top -fill both -expand 1

    set left [ttk::frame $pw.left]
    set tv [ttk::treeview $left.tv -columns {line hit} \
        -yscrollcommand [list $left.ys set]]
    $tv heading #0 -text "Datei/Verzeichnis"
    $tv heading line -text "Zeile"
    $tv heading hit -text "Treffer"
    $tv column #0 -width 240 -anchor w
    $tv column line -width 60 -anchor e
    $tv column hit -width 280 -anchor w
    $tv tag configure dir  -foreground "#1a4f8b"
    $tv tag configure hit  -foreground "#a00000"
    ttk::scrollbar $left.ys -orient vertical -command [list $tv yview]
    grid $tv $left.ys -sticky nsew
    grid rowconfigure $left 0 -weight 1
    grid columnconfigure $left 0 -weight 1

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

    # --- status ---
    set st [::tkutils::tkustatus::widget .st]
    pack $st -side bottom -fill x
    ::tkutils::tkustatus::addField $st files -width 18
    ::tkutils::tkustatus::setText $st "Bereit."

    # context menu
    set m [menu .ctx -tearoff 0]
    $m add command -label "Im eingebauten Editor oeffnen" -command ::srtool::openInBuiltinEditor
    $m add command -label "Im Editor oeffnen (extern)" -command ::srtool::openInEditor
    $m add command -label "Datei oeffnen (extern)" -command ::srtool::openExternal
    $m add command -label "Ordner im Explorer oeffnen" -command ::srtool::openFolder
    $m add command -label "Pfad kopieren" -command ::srtool::copyPath
    $m add separator
    $m add command -label "Alle aufklappen" -command {::srtool::expandAll 1}
    $m add command -label "Alle zuklappen" -command {::srtool::expandAll 0}

    # bindings
    bind $tv <<TreeviewSelect>> ::srtool::onSelect
    bind $tv <Double-1> ::srtool::openInBuiltinEditor
    bind $tv <Button-3> {tk_popup .ctx %X %Y}
    bind . <Control-f> {focus .params.search ; break}
    bind . <Escape> {::srtool::clearResults}
    bind $p.search <Return> ::srtool::doSearch
    bind $p.searchml <Control-Return> ::srtool::doSearch
    bind $p.repl <KeyRelease> ::srtool::updateReplaceButtons
    bind $p.replml <KeyRelease> ::srtool::updateReplaceButtons

    toggleMultiline
}

proc ::srtool::toggleMultiline {} {
    variable opt
    set p .params
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
    set ok [expr {$opt(allowReplace) && [llength $results] > 0 \
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
    set needle [getSearch]
    if {$needle eq ""} {
        ::tkutils::tkudialog::showWarning "Bitte einen Suchtext eingeben."
        return
    }
    if {![file isdirectory $opt(dir)]} {
        ::tkutils::tkudialog::showError "Verzeichnis nicht gefunden:\n$opt(dir)"
        return
    }
    clearResults
    ::tkutils::tkustatus::setText .st "Suche laeuft..."
    update idletasks
    if {[catch {
        searchDir $opt(dir) $opt(pattern) $needle [currentOpts]
    } results err]} {
        set results {}
        ::tkutils::tkudialog::showError "Suchfehler:\n[dict get $err -errorinfo]"
        return
    }
    populateTree
    set h [countHits $results]
    set f [llength $results]
    ::tkutils::tkustatus::setText .st "$h Treffer in $f Datei(en) gefunden."
    ::tkutils::tkustatus::setField .st files "$f Datei(en)"
    updateReplaceButtons
}

proc ::srtool::populateTree {} {
    variable results
    variable itemInfo
    set tv .pw.left.tv
    $tv delete [$tv children {}]
    array unset itemInfo
    array set itemInfo {}
    set dirNodes [dict create]
    foreach pair $results {
        lassign $pair file hits
        set dir [file dirname $file]
        if {![dict exists $dirNodes $dir]} {
            set dn [$tv insert {} end -text $dir -open 1 -tags dir]
            dict set dirNodes $dir $dn
        }
        set dn [dict get $dirNodes $dir]
        set fn [$tv insert $dn end -text [file tail $file] -open 1 \
            -values [list "" "([llength $hits] Treffer)"]]
        set itemInfo($fn) [list file $file line ""]
        foreach hit $hits {
            set hn [$tv insert $fn end -text "" -tags hit \
                -values [list [dict get $hit line] [dict get $hit text]]]
            set itemInfo($hn) [list file $file line [dict get $hit line]]
        }
    }
}

proc ::srtool::onSelect {} {
    variable itemInfo
    set sel [.pw.left.tv selection]
    if {$sel eq ""} return
    set item [lindex $sel 0]
    if {![info exists itemInfo($item)]} return
    set file [dict get $itemInfo($item) file]
    set line [dict get $itemInfo($item) line]
    showPreview $file $line
}

proc ::srtool::showPreview {file line} {
    variable opt
    variable cache
    if {![info exists cache($file)]} {
        set cache($file) [readFileEnc $file $opt(encoding)]
    }
    set t .pw.right.t
    $t configure -state normal
    $t delete 1.0 end
    set n 0
    foreach l [split $cache($file) "\n"] {
        incr n
        $t insert end [format "%5d  " $n] lineno
        $t insert end "$l\n"
    }
    $t configure -state disabled
    if {$line ne ""} {
        set first [lindex [split $line -] 0]
        set last [lindex [split $line -] end]
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
