# tkutils::tkdiff -- line diff viewer
#
# Tk front-end on top of the tclutils diff engine (tudiff). Shows the structured
# diff with per-line highlighting. Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tudiff 0.1
package require tclutils::common 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkdiff {
    namespace export widget setTexts loadFiles getOps
    variable state
}

proc ::tkutils::tkdiff::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the diff widget under $path. Options: -width N, -height N.
proc ::tkutils::tkdiff::widget {path args} {
    variable state
    array set opts {-width 90 -height 24}
    array set opts $args

    ttk::frame $path
    set state($path,ops) {}
    bind $path <Destroy> [list ::tkutils::tkdiff::_cleanup $path %W]

    text $path.t -width $opts(-width) -height $opts(-height) \
        -wrap none -font TkFixedFont
    ttk::scrollbar $path.ys -orient vertical -command [list $path.t yview]
    ttk::scrollbar $path.xs -orient horizontal -command [list $path.t xview]
    $path.t configure -yscrollcommand [list $path.ys set] \
        -xscrollcommand [list $path.xs set] -state disabled
    grid $path.t $path.ys -sticky nsew
    grid $path.xs -sticky ew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    $path.t tag configure delete -background "#ffe0e0" -foreground "#a00000"
    $path.t tag configure insert -background "#e0ffe0" -foreground "#006000"
    $path.t tag configure equal  -foreground "#404040"
    return $path
}

# Diff two strings. Extra args are passed to tudiff::text.
proc ::tkutils::tkdiff::setTexts {path oldText newText args} {
    variable state
    set state($path,ops) [::tclutils::tudiff::text $oldText $newText {*}$args]
    _render $path
    return [llength $state($path,ops)]
}

proc ::tkutils::tkdiff::loadFiles {path oldFile newFile args} {
    set old [::tclutils::common::readFile $oldFile]
    set new [::tclutils::common::readFile $newFile]
    return [setTexts $path $old $new {*}$args]
}

# Return the list of {op token} diff operations.
proc ::tkutils::tkdiff::getOps {path} {
    variable state
    return $state($path,ops)
}

proc ::tkutils::tkdiff::_render {path} {
    variable state
    set t $path.t
    $t configure -state normal
    $t delete 1.0 end
    foreach pair $state($path,ops) {
        lassign $pair op token
        switch -- $op {
            delete { set prefix "- " }
            insert { set prefix "+ " }
            default { set prefix "  "; set op equal }
        }
        $t insert end "$prefix$token\n" $op
    }
    $t configure -state disabled
}

package provide tkutils::tkdiff 0.1
