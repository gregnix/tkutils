# tkutils::tkuopts -- option checking for tkutils widgets and procs.
# Description: merge options over defaults; an unknown option is an error that lists the known ones
# Category: System · runtime
#
# Up to tkutils 0.44.0 (first build) 24 procs in 20 modules took their options
# with
#     array set o {-a 1 -b 2}
#     array set o $args        ;# merges anything, known or not
# and so swallowed every unknown option: a typo such as -onresul silently did
# nothing. tkutlfmt::column had a check, but it ran AFTER the merge, when every
# given key already existed -- it could never fire (measured 2026-09-19:
# `column $t 0 number -decimalz 3` returned without error).
#
# Usage at such a site:
#     array set o {-a 1 -b 2}
#     array set o [::tkutils::tkuopts::merge TKUMYWIDGET [array get o] $args]
#
# Pure Tcl, no Tk needed. Tcl 8.6+ and 9.x. (Idea 1 of ideen-tclutils-tkutils.md.)

package require Tcl 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuopts {
    namespace export merge
    variable version 0.1
}

# merge mod defaults argv -- DEFAULTS is a list of option/value pairs (e.g.
# [array get o]); ARGV the caller's options. Returns DEFAULTS with ARGV applied.
# An option not in DEFAULTS, or a missing value, raises
#     {TKUTILS <MOD> OPTION <opt>}   unknown option "-x"\nKnown: -a -b
# MOD is the upper-case module name (TKUCALC), as the tkutils conventions ask.
proc ::tkutils::tkuopts::merge {mod defaults argv} {
    if {[llength $argv] % 2} {
        return -code error -errorcode [list TKUTILS $mod OPTION] \
            "missing value for option \"[lindex $argv end]\""
    }
    set d [dict create {*}$defaults]
    foreach {k v} $argv {
        if {![dict exists $d $k]} {
            return -code error -errorcode [list TKUTILS $mod OPTION $k] \
                "unknown option \"$k\"\nKnown: [join [lsort [dict keys $d]] { }]"
        }
        dict set d $k $v
    }
    return $d
}

package provide tkutils::tkuopts 0.1