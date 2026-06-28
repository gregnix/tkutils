# tkutils/tclutils module-path bootstrap, shared by the apps under apps/.
#
# Sourced relative to the calling script:
#     source [file join [file dirname [info script]] .. _lib paths.tcl]
#
# Adds the tclutils and tkutils module directories to the Tcl module path,
# trying these locations in order of priority and adding only those that exist:
#   1. TCLUTILS_TM / TKUTILS_TM            explicit override (wins)
#   2. <tcl-install>/<pkg>/lib/tm          next to the Tcl library (Linux+Win)
#   3. /usr/local/share/tcltk/<pkg>/lib/tm system-wide share (Unix)
#   4. $XDG_DATA_HOME|~/.local/share/tcltk/<pkg>/lib/tm   per-user (XDG)
#   5. <repo-parent>/<pkg>/lib/tm          side-by-side source checkout
#
# Non-existent candidates are skipped silently; a genuinely missing package
# surfaces later as a loud `package require` error -- that is the intended
# loud signal, not this resolver.

namespace eval ::tkupaths {}

proc ::tkupaths::add {} {
    # this file lives at <repo>/apps/_lib/paths.tcl
    set self      [file dirname [file normalize [info script]]]
    set repoRoot  [file dirname [file dirname $self]]   ;# <repo>
    set parent    [file dirname $repoRoot]              ;# holds sibling repos
    set tcllib    [file dirname [info library]]         ;# next to tcl library

    if {[info exists ::env(XDG_DATA_HOME)] && $::env(XDG_DATA_HOME) ne ""} {
        set xdg $::env(XDG_DATA_HOME)
    } elseif {[info exists ::env(HOME)]} {
        set xdg [file join $::env(HOME) .local share]
    } else {
        set xdg ""
    }

    foreach pkg {tclutils tkutils} ev {TCLUTILS_TM TKUTILS_TM} {
        # highest priority first; added in reverse so env ends up at the head
        set cands {}
        if {[info exists ::env($ev)] && $::env($ev) ne ""} {
            lappend cands $::env($ev)
        }
        lappend cands [file join $tcllib $pkg lib tm]
        lappend cands [file join / usr local share tcltk $pkg lib tm]
        if {$xdg ne ""} { lappend cands [file join $xdg tcltk $pkg lib tm] }
        lappend cands [file join $parent $pkg lib tm]

        foreach d [lreverse $cands] {
            if {[file isdirectory $d] && $d ni [::tcl::tm::path list]} {
                ::tcl::tm::path add $d
            }
        }
    }
}
::tkupaths::add
