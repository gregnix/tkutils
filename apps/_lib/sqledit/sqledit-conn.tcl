# sqledit-conn.tcl -- shared connection-profile store for the sqledit editor
# family. Backends (postgres, oracle, ...) call these procs to let the user
# save and recall named connection profiles; file-based backends (sqlite,
# tdbc-sqlite) do not need it.
#
# API (all guarded by the callers with `info commands ::sqledit::conn::names`):
#   ::sqledit::conn::names  backend            -> sorted list of profile names
#   ::sqledit::conn::get    backend name       -> profile dict, or "" if absent
#   ::sqledit::conn::save   backend name dict  -> persist the profile
#   ::sqledit::conn::delete backend name       -> remove the profile
#   ::sqledit::conn::stripSecret dict          -> dict without the password key
#
# A profile is a plain key->value dict (backend-specific fields, e.g.
# {connect host:port/svc user scott password tiger}).
#
# Storage: one file per backend at <config>/sqledit/<backend>.conf, where
# <config> is $XDG_CONFIG_HOME, else ~/.config, else %APPDATA% (Windows),
# else a local fallback. The file holds a single Tcl dict
# {name {k v ...} name {k v ...} ...}. It is read purely as a list (never
# source'd/eval'd, so a tampered file cannot run code) and written with
# 0600 permissions; the directory is created 0700.
#
# Passwords are persisted ONLY when the caller leaves them in the dict --
# the connection dialogs strip the password via stripSecret unless the user
# ticks "Save password". This module never adds or removes secrets on its own
# beyond the explicit stripSecret helper.

package require Tcl 8.6-

namespace eval ::sqledit::conn {
    # keys treated as secrets by stripSecret
    variable secretKeys {password passwd pwd secret}
}

# --- storage location -------------------------------------------------------
proc ::sqledit::conn::_dir {} {
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

# Sanitise the backend key so it is a safe single filename component.
proc ::sqledit::conn::_file {backend} {
    set safe [regsub -all {[^A-Za-z0-9_.-]} $backend _]
    if {$safe eq ""} { set safe backend }
    return [file join [_dir] "$safe.conf"]
}

# --- read / write -----------------------------------------------------------
# Returns the profile dict for a backend, or {} on absence / corruption.
proc ::sqledit::conn::_read {backend} {
    set f [_file $backend]
    if {![file exists $f]} { return {} }
    set data {}
    if {[catch {
        set ch [open $f r]
        fconfigure $ch -encoding utf-8
        set data [read $ch]
        close $ch
    }]} {
        return {}
    }
    # Trust the content only if it parses as a well-formed dict; a hand-edited
    # or truncated file otherwise yields an empty store rather than an error.
    if {[catch {dict size $data}]} { return {} }
    return $data
}

proc ::sqledit::conn::_write {backend profiles} {
    set d [_dir]
    file mkdir $d
    catch {file attributes $d -permissions 0o700}
    set f [_file $backend]
    set ch [open $f w]
    fconfigure $ch -encoding utf-8
    puts -nonewline $ch $profiles
    close $ch
    catch {file attributes $f -permissions 0o600}
    return
}

# --- public API -------------------------------------------------------------
proc ::sqledit::conn::names {backend} {
    return [lsort -dictionary [dict keys [_read $backend]]]
}

proc ::sqledit::conn::get {backend name} {
    set all [_read $backend]
    if {[dict exists $all $name]} { return [dict get $all $name] }
    return ""
}

proc ::sqledit::conn::save {backend name profile} {
    set name [string trim $name]
    if {$name eq ""} {
        return -code error -errorcode {SQLEDIT CONN NONAME} "profile name is empty"
    }
    set all [_read $backend]
    dict set all $name $profile
    _write $backend $all
    return $name
}

proc ::sqledit::conn::delete {backend name} {
    set all [_read $backend]
    if {[dict exists $all $name]} {
        dict unset all $name
        _write $backend $all
    }
    return
}

proc ::sqledit::conn::stripSecret {profile} {
    variable secretKeys
    foreach k $secretKeys {
        if {[dict exists $profile $k]} { dict unset profile $k }
    }
    return $profile
}
