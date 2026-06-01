# tkutils::tkcsv -- CSV table viewer
#
# Tk front-end on top of the tclutils CSV engine (tucsv). Renders parsed rows
# into a ttk::treeview. Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tucsv 0.1
package require tclutils::common 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkcsv {
    namespace export widget loadFile setData getRows
    variable state
}

proc ::tkutils::tkcsv::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the table widget under $path. Options:
#   -height N   visible rows (default 15)
#   -header 0|1 treat the first row as column headings (default 1)
proc ::tkutils::tkcsv::widget {path args} {
    variable state
    array set opts {-height 15 -header 1}
    array set opts $args

    ttk::frame $path
    set state($path,rows) {}
    set state($path,header) $opts(-header)
    bind $path <Destroy> [list ::tkutils::tkcsv::_cleanup $path %W]

    ttk::treeview $path.tv -show headings -height $opts(-height)
    ttk::scrollbar $path.ys -orient vertical -command [list $path.tv yview]
    ttk::scrollbar $path.xs -orient horizontal -command [list $path.tv xview]
    $path.tv configure -yscrollcommand [list $path.ys set] \
        -xscrollcommand [list $path.xs set]
    grid $path.tv $path.ys -sticky nsew
    grid $path.xs -sticky ew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1
    return $path
}

# Load CSV from a string. Extra args are passed to tucsv::parse (e.g. -separator).
proc ::tkutils::tkcsv::setData {path csvText args} {
    variable state
    set state($path,rows) [::tclutils::tucsv::parse $csvText {*}$args]
    _populate $path
    return [llength $state($path,rows)]
}

proc ::tkutils::tkcsv::loadFile {path filename args} {
    variable state
    set state($path,rows) [::tclutils::tucsv::file $filename {*}$args]
    _populate $path
    return $filename
}

# Return all parsed rows (including the header row, if any).
proc ::tkutils::tkcsv::getRows {path} {
    variable state
    return $state($path,rows)
}

proc ::tkutils::tkcsv::_populate {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    set rows $state($path,rows)
    if {$rows eq ""} {
        $tv configure -columns {}
        return
    }

    if {$state($path,header)} {
        set header [lindex $rows 0]
        set data [lrange $rows 1 end]
    } else {
        set ncol [llength [lindex $rows 0]]
        set header {}
        for {set i 1} {$i <= $ncol} {incr i} { lappend header "col$i" }
        set data $rows
    }

    set cols {}
    for {set i 0} {$i < [llength $header]} {incr i} { lappend cols c$i }
    $tv configure -columns $cols
    foreach c $cols h $header {
        $tv heading $c -text $h
        $tv column $c -width 120 -anchor w
    }
    foreach row $data {
        $tv insert {} end -values $row
    }
}

package provide tkutils::tkcsv 0.1
