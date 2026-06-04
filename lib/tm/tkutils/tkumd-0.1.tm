# tkutils::tkumd -- Markdown outline viewer
#
# Tk front-end on top of the tclutils Markdown engine (tumd). Shows the document
# headings as a nested outline in a ttk::treeview. Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tumd 0.1
package require tclutils::common 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkumd {
    namespace export widget loadFile setMarkdown getHeadings
    variable state
}

proc ::tkutils::tkumd::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the outline widget under $path. Option: -height N (visible rows).
proc ::tkutils::tkumd::widget {path args} {
    variable state
    array set opts {-height 20}
    array set opts $args

    ttk::frame $path
    set state($path,headings) {}
    bind $path <Destroy> [list ::tkutils::tkumd::_cleanup $path %W]

    ttk::treeview $path.tv -show tree -height $opts(-height)
    ttk::scrollbar $path.ys -orient vertical -command [list $path.tv yview]
    $path.tv configure -yscrollcommand [list $path.ys set]
    grid $path.tv $path.ys -sticky nsew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1
    return $path
}

# Load Markdown from a string.
proc ::tkutils::tkumd::setMarkdown {path markdown} {
    variable state
    set state($path,headings) [::tclutils::tumd::headings $markdown]
    _populate $path
    return [llength $state($path,headings)]
}

proc ::tkutils::tkumd::loadFile {path filename} {
    variable state
    set state($path,headings) \
        [::tclutils::tumd::headings [::tclutils::common::readFile $filename]]
    _populate $path
    return $filename
}

# Return the list of {level title} headings.
proc ::tkutils::tkumd::getHeadings {path} {
    variable state
    return $state($path,headings)
}

proc ::tkutils::tkumd::_populate {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    array unset parentAt
    set parentAt(0) {}
    foreach h $state($path,headings) {
        lassign $h level title
        # find the nearest declared ancestor level
        set parent {}
        for {set l [expr {$level - 1}]} {$l >= 0} {incr l -1} {
            if {[info exists parentAt($l)]} {
                set parent $parentAt($l)
                break
            }
        }
        set node [$tv insert $parent end -text $title -open 1]
        set parentAt($level) $node
        # deeper levels are no longer valid parents
        foreach k [array names parentAt] {
            if {$k > $level} { unset parentAt($k) }
        }
    }
}

package provide tkutils::tkumd 0.1
