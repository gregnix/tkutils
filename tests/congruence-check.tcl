#!/usr/bin/env tclsh
# congruence-check.tcl -- verify that every module of the tablelist extension
# family has its companion artifacts (module .tm, doc, demo, man page, test).
# Reports a matrix and exits non-zero if anything is missing.
#
# Usage:
#   tclsh congruence-check.tcl ?-tkutils DIR? ?-tclutils DIR?
# DIRs default to the repository roots relative to this script
#   (.. for tkutils, ../../tclutils for tclutils).

set here [file dirname [file normalize [info script]]]
set tkuRoot [file normalize [file join $here ..]]
set tcuRoot [file normalize [file join $here .. .. tclutils]]
foreach {k v} $argv {
    switch -- $k {
        -tkutils  { set tkuRoot [file normalize $v] }
        -tclutils { set tcuRoot [file normalize $v] }
    }
}

# {module ns root}  -- ns is the package prefix dir, root the repo root
set family {
    tkutlsort   tkutils  TKU
    tkutlfmt    tkutils  TKU
    tkutlclip   tkutils  TKU
    tkutlfooter tkutils  TKU
    tkutlfind   tkutils  TKU
    tkutlstate  tkutils  TKU
    tkutltree   tkutils  TKU
    tunum       tclutils TCU
}

proc roots {which} {
    global tkuRoot tcuRoot
    return [expr {$which eq "TKU" ? $tkuRoot : $tcuRoot}]
}

# artifact path templates relative to the repo root
proc paths {name nsdir which} {
    set r [roots $which]
    return [dict create \
        module [file join $r lib tm $nsdir $name-0.1.tm] \
        doc    [file join $r docs $name.md] \
        demo   [file join $r examples demo-$name.tcl] \
        man    [file join $r man mann $name.n] \
        test   [file join $r tests $name.test]]
}

set cols {module doc demo man test}
puts [format "%-12s %-6s %-6s %-6s %-6s %-6s" module {*}$cols]
puts [string repeat - 44]
set missing 0
foreach {name nsdir which} $family {
    set p [paths $name $nsdir $which]
    set line [format "%-12s" $name]
    foreach c $cols {
        if {[file exists [dict get $p $c]]} {
            append line [format " %-6s" ok]
        } else {
            append line [format " %-6s" MISS]
            incr missing
        }
    }
    puts $line
}
puts [string repeat - 44]
if {$missing == 0} {
    puts "OK -- all artifacts present"
    exit 0
} else {
    puts "INCOMPLETE -- $missing artifact(s) missing"
    exit 1
}
