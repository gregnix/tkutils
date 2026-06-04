#!/usr/bin/env tclsh
# tkdavaccount demo: enter DAV server details, test the connection, and -- once
# the test succeeds -- provision and browse collections on the server using the
# tclutils::tudav helpers. Works against a self-hosted Radicale (default 5232):
#   printf 'alice:pw\n' > rad.htpasswd
#   python3 -m radicale --server-hosts 127.0.0.1:5232 --auth-type htpasswd \
#       --auth-htpasswd-filename rad.htpasswd --auth-htpasswd-encryption plain \
#       --rights-type owner_only --storage-filesystem-folder ./rad-data
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
package require tkutils::tkdavaccount
package require tclutils::tudav

namespace eval demo {}

proc demo::log {msg} {
    .log configure -state normal
    .log insert end "$msg\n"
    .log see end
    .log configure -state disabled
}

# Build a tudav client from the account form (base URL + credentials).
proc demo::client {} {
    set cfg [::tkutils::tkdavaccount::getConfig .a]
    return [::tclutils::tudav::client [dict get $cfg url] \
        -user [dict get $cfg user] -password [dict get $cfg password]]
}

proc demo::collPath {} { return [string trim [.act.path get]] }

# Create an address book or calendar at the entered path.
proc demo::mk {kind} {
    set p [demo::collPath]
    if {$p eq ""} { demo::log "! enter a collection path first"; return }
    if {[catch {
        set c [demo::client]
        switch -- $kind {
            addressbook { ::tclutils::tudav::mkAddressbook $c $p -displayname "Demo Contacts" }
            calendar    { ::tclutils::tudav::mkCalendar    $c $p -displayname "Demo Calendar" }
        }
        demo::log "create $kind $p  ->  [::tclutils::tudav::lastStatus $c]"
        ::tclutils::tudav::destroy $c
    } err]} {
        demo::log "! create $kind failed: $err"
    }
}

# List the resources in the entered collection path.
proc demo::browse {} {
    if {[catch {
        set c [demo::client]
        set res [::tclutils::tudav::listResources $c -path [demo::collPath]]
        demo::log "list [demo::collPath]  ->  [llength $res] item(s)"
        foreach r $res { demo::log "    [dict get $r href]" }
        ::tclutils::tudav::destroy $c
    } err]} {
        if {[string match {*404*} $err]} {
            demo::log "  collection [demo::collPath] not found -- create it first, or check the path/user"
        } else {
            demo::log "! list failed: $err"
        }
    }
}

# Discover the child collections (address books/calendars) under the path.
proc demo::discover {} {
    if {[catch {
        set c [demo::client]
        set cols [::tclutils::tudav::listCollections $c -path [demo::collPath]]
        demo::log "collections under [demo::collPath]  ->  [llength $cols]"
        foreach col $cols {
            demo::log [format "    %-11s %s  (%s)" [dict get $col kind] \
                [dict get $col href] [dict get $col displayname]]
        }
        ::tclutils::tudav::destroy $c
    } err]} {
        if {[string match {*404*} $err]} {
            demo::log "  nothing at [demo::collPath] (404) -- discover the principal, e.g. /<user>/"
        } else {
            demo::log "! discover failed: $err"
        }
    }
}

proc demo::enable {on} {
    set st [expr {$on ? "normal" : "disabled"}]
    foreach w {.act.path .act.btns.disc .act.btns.ab .act.btns.cal .act.btns.ls} { $w configure -state $st }
}

wm title . "tkdavaccount demo"

set a [::tkutils::tkdavaccount::widget .a -type carddav \
    -command {apply {{ok msg} {
        .out configure -text [expr {$ok ? "\u2713 connection ok" : "\u2717 $msg"}]
        demo::enable $ok
        if {$ok} {
            demo::log "connection ok -- you can now create/list collections"
            set u [dict get [::tkutils::tkdavaccount::getConfig .a] user]
            if {$u ne "" && [string trim [.act.path get]] eq "/alice/contacts/"} {
                .act.path delete 0 end
                .act.path insert 0 "/$u/contacts/"
            }
        }
    }}}]
::tkutils::tkdavaccount::setConfig $a {url http://127.0.0.1:5232/ user alice password pw type carddav}

ttk::label .out -text "Enter server details and click Test connection."

ttk::labelframe .act -text "Collection (enabled after a successful test)"
ttk::label .act.pl -text "Path:"
ttk::entry .act.path -width 40
.act.path insert 0 "/alice/contacts/"
ttk::frame .act.btns
ttk::button .act.btns.disc -text "Discover" -command {demo::discover}
ttk::button .act.btns.ab  -text "Create address book" -command {demo::mk addressbook}
ttk::button .act.btns.cal -text "Create calendar"      -command {demo::mk calendar}
ttk::button .act.btns.ls  -text "List"                 -command {demo::browse}
pack .act.btns.disc .act.btns.ab .act.btns.cal .act.btns.ls -side left -padx 2
grid .act.pl .act.path -sticky w -padx 4 -pady 4
grid .act.btns -       -sticky w -padx 4 -pady {0 4}

text .log -height 9 -width 60 -state disabled

pack $a   -fill x    -padx 8 -pady 8
pack .out -fill x    -padx 8 -pady {0 8}
pack .act -fill x    -padx 8 -pady {0 8}
pack .log -fill both -expand 1 -padx 8 -pady {0 8}

demo::enable 0

# DEMO_NOLOOP lets a test harness drive the procs without entering the event loop.
if {![info exists ::env(DEMO_NOLOOP)]} { vwait forever }
