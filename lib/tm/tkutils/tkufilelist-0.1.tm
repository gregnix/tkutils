# tkutils::tkufilelist -- a detail file list, filled from a storage provider.
#
# The list counterpart to tkufiletree: where the tree shows the hierarchy, the
# list shows the contents of one directory with columns (name, size, type).
# Both read through the same provider interface, so the list works over local
# files, ZIP, WebDAV, ... unchanged.
#
# Built on tkutils::tkutablelist (which wraps the Tablelist megawidget), so it
# inherits click-to-sort headers and selection for free.
#
#   tkufilelist::widget .fl -provider $p -dir /some/path \
#       -onactivate {apply {e { puts "open [dict get $e path]" }}}
#
# Options:
#   -provider P    a tuprovider object (default: a fresh local provider)
#   -dir D         directory to show (default: provider root "/" or cwd)
#   -files B       show files (default 1); dirs are always shown
#   -showhidden B  show dotfiles (default 0)
#   -onactivate S  script called with the entry dict on double-click/Return
#   -onselect  S   script called with the entry dict on selection change
#   -height N      visible rows (default 16)
#
# The row's entry dict is kept per row so callbacks get the full provider
# entry, not just the visible cells.

package require Tcl 8.6-
package require Tk 8.6-
package require tkutils::tkutablelist

namespace eval ::tkutils {}
namespace eval ::tkutils::tkufilelist {
    namespace export widget setDir dir refresh selectedEntry selectedEntries setFilter
    variable state
}

proc ::tkutils::tkufilelist::widget {path args} {
    variable state
    array set o {
        -provider "" -dir "" -files 1 -showhidden 0
        -onactivate "" -onselect "" -height 16 -filter ""
    }
    array set o $args
    if {$o(-provider) eq ""} {
        package require tclutils::tuprovider
        set o(-provider) [::tclutils::tuprovider open local]
    }
    if {$o(-dir) eq ""} { set o(-dir) "/" }

    set state($path,prov)   $o(-provider)
    set state($path,dir)    $o(-dir)
    set state($path,files)  $o(-files)
    set state($path,hidden) $o(-showhidden)
    set state($path,filter) $o(-filter)   ;# glob applied to file names ("" = all)
    set state($path,onact)  $o(-onactivate)
    set state($path,onsel)  $o(-onselect)
    set state($path,rows)   {}   ;# row index -> entry dict

    ::tkutils::tkutablelist::widget $path \
        -columns {Name {Size -align right} Type} \
        -selectcommand [list ::tkutils::tkufilelist::_onselect $path] \
        -doublecommand [list ::tkutils::tkufilelist::_onactivate $path]

    _fill $path
    return $path
}

# Re-read the current directory through the provider and rebuild the rows.
proc ::tkutils::tkufilelist::_fill {path} {
    variable state
    set prov $state($path,prov)
    set dir  $state($path,dir)
    ::tkutils::tkutablelist::clear $path
    set state($path,rows) {}

    set dirs {}
    set files {}
    foreach e [$prov list $dir] {
        set name [dict get $e name]
        if {$name eq "." || $name eq ".."} { continue }
        if {!$state($path,hidden) && [string match ".*" $name]} { continue }
        if {[dict get $e type] eq "dir"} {
            lappend dirs [list $name $e]
        } elseif {$state($path,files)} {
            # a name filter (glob, case-insensitive) narrows files but not the
            # directories, so navigation stays possible while filtering files.
            set flt $state($path,filter)
            if {$flt ne "" && ![string match -nocase $flt $name]} { continue }
            lappend files [list $name $e]
        }
    }
    set dirs  [lsort -index 0 -dictionary $dirs]
    set files [lsort -index 0 -dictionary $files]

    set idx 0
    foreach pair [concat $dirs $files] {
        lassign $pair name e
        set type [dict get $e type]
        set size [dict get $e size]
        set shown [expr {$type eq "dir" ? "" : [_humanSize $size]}]
        ::tkutils::tkutablelist::insert $path [list $name $shown $type]
        # Store the entry as a Tablelist ROW ATTRIBUTE, which travels with the
        # row when the user click-sorts a header. Indexing state($path,rows) by
        # the fill-time position would go stale after a sort and make the
        # selection resolve to the wrong file.
        [::tkutils::tkutablelist::tableWidget $path] rowattrib $idx entry $e
        dict set state($path,rows) $idx $e
        incr idx
    }
    return
}

# Human-readable size; "" stays "".
proc ::tkutils::tkufilelist::_humanSize {bytes} {
    if {$bytes eq "" || ![string is integer -strict $bytes]} { return "" }
    set units {B KB MB GB TB}
    set n $bytes ; set i 0
    while {$n >= 1024 && $i < [llength $units]-1} {
        set n [expr {$n / 1024.0}] ; incr i
    }
    if {$i == 0} { return "$bytes B" }
    return [format "%.1f %s" $n [lindex $units $i]]
}

# Change directory and refresh.
proc ::tkutils::tkufilelist::setDir {path dir} {
    variable state
    set state($path,dir) $dir
    _fill $path
    return
}

proc ::tkutils::tkufilelist::refresh {path} { _fill $path }

# Set the file-name filter (a glob, case-insensitive; "" shows all) and refill.
proc ::tkutils::tkufilelist::setFilter {path glob} {
    variable state
    set state($path,filter) $glob
    _fill $path
}

# The directory currently shown. A public accessor so callers do not have to
# reach into the private state array.
proc ::tkutils::tkufilelist::dir {path} {
    variable state
    return $state($path,dir)
}

# Entry dict of the first selected row, or "".
proc ::tkutils::tkufilelist::selectedEntry {path} {
    set sel [::tkutils::tkutablelist::selection $path]
    if {![llength $sel]} { return "" }
    return [_entryAt $path [lindex $sel 0]]
}

# All selected entries (the list is -selectmode extended), in row order.
proc ::tkutils::tkufilelist::selectedEntries {path} {
    set out {}
    foreach idx [::tkutils::tkutablelist::selection $path] {
        set e [_entryAt $path $idx]
        if {$e ne ""} { lappend out $e }
    }
    return $out
}

# Entry stored on a row, read via its row attribute so it stays correct after a
# header click-sort reorders the rows.
proc ::tkutils::tkufilelist::_entryAt {path idx} {
    if {[catch {[::tkutils::tkutablelist::tableWidget $path] rowattrib $idx entry} e]} {
        return ""
    }
    return $e
}

proc ::tkutils::tkufilelist::_onselect {path args} {
    variable state
    if {$state($path,onsel) eq ""} return
    set e [selectedEntry $path]
    if {$e ne ""} { uplevel #0 [linsert $state($path,onsel) end $e] }
}

proc ::tkutils::tkufilelist::_onactivate {path args} {
    variable state
    if {$state($path,onact) eq ""} return
    set e [selectedEntry $path]
    if {$e ne ""} { uplevel #0 [linsert $state($path,onact) end $e] }
}

package provide tkutils::tkufilelist 0.1
