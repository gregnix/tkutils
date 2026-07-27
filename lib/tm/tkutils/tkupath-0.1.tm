# tkutils::tkupath -- a breadcrumb path bar.
#
# Shows a path as a row of clickable segments: /home/greg/docs becomes
# [/] [home] [greg] [docs]. Clicking a segment fires -onnavigate with the path
# up to and including that segment, so the host can navigate there.
#
# Provider-neutral: it only splits and joins "/"-separated paths as text. It
# does not touch any filesystem, so it works for local paths, ZIP paths, DAV
# hrefs -- whatever the provider uses, as long as "/" is the separator.
#
#   tkupath::widget .pb -onnavigate {apply {p { puts "go $p" }}}
#   tkupath::setPath .pb /home/greg/docs
#   tkupath::getPath .pb            -> /home/greg/docs
#
# Options:
#   -onnavigate cmd   called with the target path when a segment is clicked
#   -rootlabel s      label for the leading "/" segment (default "/")

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkupath {
    namespace export widget setPath getPath
    variable state
}

proc ::tkutils::tkupath::widget {path args} {
    variable state
    array set o {-onnavigate "" -rootlabel "/"}
    array set o $args

    ttk::frame $path
    set state($path,onnav) $o(-onnavigate)
    set state($path,root)  $o(-rootlabel)
    set state($path,path)  "/"
    bind $path <Destroy> [list ::tkutils::tkupath::_cleanup $path %W]

    _rebuild $path
    return $path
}

# Set the displayed path and rebuild the segment buttons.
proc ::tkutils::tkupath::setPath {path p} {
    variable state
    if {$p eq ""} { set p "/" }
    set state($path,path) $p
    _rebuild $path
    return
}

proc ::tkutils::tkupath::getPath {path} {
    variable state
    return $state($path,path)
}

# Build one button per segment. The accumulated path is stored per button so
# the callback gets the right target, not just the segment label.
proc ::tkutils::tkupath::_rebuild {path} {
    variable state
    foreach w [winfo children $path] { destroy $w }

    set p $state($path,path)
    # Leading root segment.
    ttk::button $path.seg0 -style Toolbutton -text $state($path,root) \
        -command [list ::tkutils::tkupath::_go $path "/"]
    pack $path.seg0 -side left

    # Remaining segments; accumulate the path as we go.
    set acc ""
    set i 0
    foreach part [split [string trim $p /] /] {
        if {$part eq ""} continue
        incr i
        append acc "/$part"
        ttk::label $path.sep$i -text "\u203a"   ;# a small ">" separator
        pack $path.sep$i -side left -padx 1
        ttk::button $path.seg$i -style Toolbutton -text $part \
            -command [list ::tkutils::tkupath::_go $path $acc]
        pack $path.seg$i -side left
    }
    return
}

proc ::tkutils::tkupath::_go {path target} {
    variable state
    # update our own display immediately, then notify the host
    setPath $path $target
    if {$state($path,onnav) ne ""} {
        uplevel #0 [linsert $state($path,onnav) end $target]
    }
    return
}

proc ::tkutils::tkupath::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    array unset state $path,*
    return
}

package provide tkutils::tkupath 0.1
