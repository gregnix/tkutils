# sqledit-recent.tcl -- die zuletzt geoeffneten Datenbanken.
#
# Optional wie sqledit-conn.tcl: fehlt die Datei, startet der Editor
# trotzdem, und das Menue zeigt den Eintrag dann nicht.
#
# WARUM JE BACKEND EINE DATEI. Was hier steht, ist kein Dateiname,
# sondern ein "target" -- bei SQLite ein Pfad, bei Oracle und PostgreSQL
# eine Verbindungsangabe. Die Listen zu mischen hiesse, im Menue des
# SQLite-Editors Oracle-Verbindungen anzubieten, die er nicht oeffnen
# kann.
#
# Ablage: <config>/sqledit/recent-<backend>.conf, dieselbe Wurzel wie
# die Verbindungsprofile.

namespace eval ::sqledit::recent {
    variable MAX 10
}

proc ::sqledit::recent::_dir {} {
    # Dieselbe Wurzel wie sqledit-conn. Wenn es die gibt, deren Regel
    # benutzen statt einer zweiten, die morgen abweicht.
    if {[llength [info procs ::sqledit::conn::_dir]]} {
        return [::sqledit::conn::_dir]
    }
    if {[info exists ::env(XDG_CONFIG_HOME)] && $::env(XDG_CONFIG_HOME) ne ""} {
        set base $::env(XDG_CONFIG_HOME)
    } elseif {[info exists ::env(HOME)] && $::env(HOME) ne ""} {
        set base [file join $::env(HOME) .config]
    } elseif {[info exists ::env(APPDATA)] && $::env(APPDATA) ne ""} {
        set base $::env(APPDATA)
    } else {
        set base [file join [pwd] .sqledit]
    }
    return [file join $base sqledit]
}

proc ::sqledit::recent::_backend {} {
    # _backendKey ist der eingefuehrte Name -- sqledit-conn benutzt ihn
    # seit jeher. Keinen zweiten erfinden.
    if {[llength [info procs ::sqledit::be::_backendKey]]} {
        return [::sqledit::be::_backendKey]
    }
    return default
}

proc ::sqledit::recent::_file {} {
    set safe [regsub -all {[^A-Za-z0-9_.-]} [_backend] _]
    if {$safe eq ""} { set safe default }
    return [file join [_dir] "recent-$safe.conf"]
}

# Die Liste, neueste zuerst. Leer bei Abwesenheit oder Schrott.
#
# Eine unlesbare Datei ist kein Grund abzubrechen: eine Liste zuletzt
# geoeffneter Dateien ist Bequemlichkeit, keine Angabe, ohne die man
# nicht arbeiten kann.
proc ::sqledit::recent::liste {} {
    set f [_file]
    if {![file exists $f]} { return {} }
    if {[catch {
        set ch [open $f r]
        fconfigure $ch -encoding utf-8
        set inhalt [read $ch]
        close $ch
    }]} { return {} }
    if {[catch {llength $inhalt}]} { return {} }
    return $inhalt
}

# Ein Ziel nach vorn. Schon vorhandene Eintraege wandern nach oben,
# statt ein zweites Mal zu erscheinen.
proc ::sqledit::recent::merken {target} {
    variable MAX
    if {$target eq ""} return
    set alt [liste]
    set neu [list $target]
    foreach t $alt {
        if {$t eq $target} continue
        lappend neu $t
        if {[llength $neu] >= $MAX} break
    }
    _schreiben $neu
}

proc ::sqledit::recent::vergessen {target} {
    set neu {}
    foreach t [liste] { if {$t ne $target} { lappend neu $t } }
    _schreiben $neu
}

proc ::sqledit::recent::leeren {} { _schreiben {} }

proc ::sqledit::recent::_schreiben {eintraege} {
    set d [_dir]
    if {[catch {file mkdir $d}]} return
    catch {file attributes $d -permissions 0o700}
    set f [_file]
    if {[catch {
        set ch [open $f w]
        fconfigure $ch -encoding utf-8
        puts -nonewline $ch $eintraege
        close $ch
    }]} return
    catch {file attributes $f -permissions 0o600}
    return
}

# --- Menue ------------------------------------------------------------------

# Baut das Untermenue neu. Wird bei jedem Aufklappen gerufen, damit ein
# gerade geoeffnetes Ziel sofort darin steht.
#
# Eintraege, deren Datei es nicht mehr gibt, bleiben stehen und werden
# GEKENNZEICHNET statt entfernt: wer eine Platte nicht eingehaengt hat,
# soll seine Liste nicht verlieren.
proc ::sqledit::recent::menueFuellen {m cmd} {
    $m delete 0 end
    set eintraege [liste]
    if {![llength $eintraege]} {
        $m add command -label "(keine)" -state disabled
        return
    }
    set i 1
    foreach t $eintraege {
        set beschriftung $t
        if {[llength [info procs ::sqledit::be::label]]} {
            set beschriftung "[::sqledit::be::label $t]  --  $t"
        }
        # Nur pruefen, was wie ein Pfad aussieht. Eine
        # Verbindungsangabe ist keine Datei.
        if {[string match {*[/\\]*} $t] && ![file exists $t]} {
            append beschriftung "   (nicht gefunden)"
        }
        $m add command -label "$i  $beschriftung" \
                -command [list {*}$cmd $t]
        incr i
    }
    $m add separator
    $m add command -label "Liste leeren" \
            -command [list ::sqledit::recent::leeren]
}
