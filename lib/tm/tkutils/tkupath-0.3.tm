# tkutils::tkupath -- a breadcrumb path bar.
# Description: a breadcrumb path bar with clickable segments
# Category: Tk · widgets
#
# Shows a path as a row of clickable segments: /srv/daten/docs becomes
# [/] [srv] [daten] [docs]. Clicking a segment fires -onnavigate with the path
# up to and including that segment, so the host can navigate there.
#
# Provider-neutral: it only splits and joins "/"-separated paths as text. It
# does not touch any filesystem, so it works for local paths, ZIP paths, DAV
# hrefs -- whatever the provider uses, as long as "/" is the separator.
#
# Windows paths (0.3): a drive path S:/projekte/daten becomes [S:] [projekte]
# [daten] and a UNC path //server/share/x becomes [//server/share] [x]; the
# first segment navigates to the drive or share root (S:/, //server/share/).
# Up to 0.2 the leading "/" was glued in front of every target, so clicking
# "projekte" sent "/S:/projekte" -- on Windows a path on the CURRENT drive, the
# host ended up on C:. Backslashes are taken as "/".
#
#   tkupath::widget .pb -onnavigate {apply {p { puts "go $p" }}}
#   tkupath::setPath .pb /srv/daten/docs
#   tkupath::getPath .pb            -> /srv/daten/docs
#
# Options:
#   -onnavigate cmd   called with the target path when a segment is clicked
#   -rootlabel s      label for the leading "/" segment (default "/")

package require Tcl 8.6-
package require tkutils::tkuopts 0.1
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkupath {
    namespace export widget setPath getPath
    variable state
}

proc ::tkutils::tkupath::widget {path args} {
    variable state
    array set o {-onnavigate "" -rootlabel "/"}
    array set o [::tkutils::tkuopts::merge TKUPATH [array get o] $args]

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

    lassign [_root [string map {\\ /} $state($path,path)]] rootText rootTarget rest
    if {$rootText eq ""} { set rootText $state($path,root) }
    # Leading root segment.
    ttk::button $path.seg0 -style Toolbutton -text $rootText \
        -command [list ::tkutils::tkupath::_go $path $rootTarget]
    pack $path.seg0 -side left

    # Remaining segments; accumulate the path as we go.
    set acc [string trimright $rootTarget /]
    set i 0
    foreach part [split [string trim $rest /] /] {
        if {$part eq ""} continue
        incr i
        append acc "/$part"
        ttk::label $path.sep$i -text ">"   ;# plain ASCII separator (renders in
                                           ;# every font / encoding, unlike a
                                           ;# Unicode chevron)
        pack $path.sep$i -side left -padx 1
        ttk::button $path.seg$i -style Toolbutton -text $part \
            -command [list ::tkutils::tkupath::_go $path $acc]
        pack $path.seg$i -side left
    }
    return
}

# Split off the root: {text target rest}. text "" means the -rootlabel.
#   /srv/daten         -> {"" / srv/daten}
#   S:/projekte/daten  -> {S: S:/ projekte/daten}    (also "S:" alone)
#   //srv/share/x      -> {//srv/share //srv/share/ x}
proc ::tkutils::tkupath::_root {p} {
    if {[regexp {^([A-Za-z]:)(/.*)?$} $p -> drive rest]} {
        return [list $drive $drive/ $rest]
    }
    if {[regexp {^(//[^/]+/[^/]+)(/.*)?$} $p -> share rest]} {
        return [list $share $share/ $rest]
    }
    return [list "" / $p]
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

package provide tkutils::tkupath 0.3