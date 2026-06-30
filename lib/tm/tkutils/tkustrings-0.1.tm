# tkutils::tkustrings -- printable strings viewer
# Description: printable strings viewer
# Category: Tk · widgets
#
# Tk front-end on top of the tclutils strings engine (tustrings). Extracts the
# printable ASCII strings from binary data (like the Unix `strings` tool) and
# lists them. Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tustrings 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkustrings {
    namespace export widget loadFile setData getStrings
    variable state
}

proc ::tkutils::tkustrings::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the viewer under $path. Option: -height N (visible rows).
proc ::tkutils::tkustrings::widget {path args} {
    variable state
    array set opts {-height 18}
    array set opts $args

    ttk::frame $path
    set state($path,strings) {}
    bind $path <Destroy> [list ::tkutils::tkustrings::_cleanup $path %W]

    listbox $path.lb -height $opts(-height) -activestyle dotbox \
        -yscrollcommand [list $path.ys set] -xscrollcommand [list $path.xs set]
    ttk::scrollbar $path.ys -orient vertical -command [list $path.lb yview]
    ttk::scrollbar $path.xs -orient horizontal -command [list $path.lb xview]
    grid $path.lb $path.ys -sticky nsew
    grid $path.xs -sticky ew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1
    return $path
}

# Extract strings from binary data. Extra args pass to tustrings::extract
# (e.g. -minlength N). Returns the number of strings found.
proc ::tkutils::tkustrings::setData {path data args} {
    variable state
    set state($path,strings) [::tclutils::tustrings::extract $data {*}$args]
    _populate $path
    return [llength $state($path,strings)]
}

# Extract strings from a file. Extra args pass to tustrings::file.
proc ::tkutils::tkustrings::loadFile {path filename args} {
    variable state
    set state($path,strings) [::tclutils::tustrings::file $filename {*}$args]
    _populate $path
    return [llength $state($path,strings)]
}

# Return the list of extracted strings.
proc ::tkutils::tkustrings::getStrings {path} {
    variable state
    return $state($path,strings)
}

proc ::tkutils::tkustrings::_populate {path} {
    variable state
    $path.lb delete 0 end
    foreach s $state($path,strings) { $path.lb insert end $s }
}

package provide tkutils::tkustrings 0.1
