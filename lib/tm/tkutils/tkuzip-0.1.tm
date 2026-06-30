# tkutils::tkuzip -- ZIP archive browser
# Description: ZIP archive browser
# Category: Tk · widgets
#
# Tk front-end on top of the tclutils ZIP engine (tuzip). Lists archive members
# in a ttk::treeview. Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuzip 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuzip {
    namespace export widget openFile getEntries selectedMember
    variable state
}

proc ::tkutils::tkuzip::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the browser under $path. Option: -height N (visible rows).
proc ::tkutils::tkuzip::widget {path args} {
    variable state
    array set opts {-height 18}
    array set opts $args

    ttk::frame $path
    set state($path,entries) {}
    set state($path,zip) ""
    bind $path <Destroy> [list ::tkutils::tkuzip::_cleanup $path %W]

    ttk::treeview $path.tv -columns {size csize method} \
        -show {tree headings} -height $opts(-height)
    $path.tv heading #0 -text "name"
    $path.tv heading size -text "size"
    $path.tv heading csize -text "compressed"
    $path.tv heading method -text "method"
    $path.tv column #0 -width 240 -anchor w
    $path.tv column size -width 90 -anchor e
    $path.tv column csize -width 110 -anchor e
    $path.tv column method -width 90 -anchor w
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

# Open a ZIP file and list its members. Returns the member count.
proc ::tkutils::tkuzip::openFile {path zipfile} {
    variable state
    set state($path,entries) [::tclutils::tuzip::entries $zipfile]
    set state($path,zip) $zipfile
    _populate $path
    return [llength $state($path,entries)]
}

# Return the raw entries (list of dicts from tuzip::entries).
proc ::tkutils::tkuzip::getEntries {path} {
    variable state
    return $state($path,entries)
}

# Return the name of the selected member, or "".
proc ::tkutils::tkuzip::selectedMember {path} {
    set sel [$path.tv selection]
    if {$sel eq ""} { return "" }
    return [$path.tv item [lindex $sel 0] -text]
}

proc ::tkutils::tkuzip::_method {m} {
    switch -- $m {
        0 { return "store" }
        8 { return "deflate" }
        default { return $m }
    }
}

proc ::tkutils::tkuzip::_populate {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    foreach e $state($path,entries) {
        $tv insert {} end -text [dict get $e name] -values [list \
            [dict get $e uncompressedSize] \
            [dict get $e compressedSize] \
            [_method [dict get $e method]]]
    }
}

package provide tkutils::tkuzip 0.1
