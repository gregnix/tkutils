# tkutils::tkujson -- JSON tree viewer
# Description: JSON tree viewer
# Category: Tk · widgets
#
# Tk front-end on top of the tclutils JSON engine. Uses tujson::parseTyped so
# objects, arrays and scalars can be told apart and shown as a nested tree.
# Requires tclutils 0.28.0+ (parseTyped). Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tujson 0.1
package require tclutils::common 0.1

if {![llength [info commands ::tclutils::tujson::parseTyped]]} {
    return -code error -errorcode {TKUTILS TKJSON DEP} \
        "tkutils::tkujson requires tclutils::tujson with parseTyped (tclutils 0.28.0+)"
}

namespace eval ::tkutils {}
namespace eval ::tkutils::tkujson {
    namespace export widget loadFile setJson getTree
    variable state
}

proc ::tkutils::tkujson::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the tree widget under $path. Option: -height N (visible rows).
proc ::tkutils::tkujson::widget {path args} {
    variable state
    array set opts {-height 20}
    array set opts $args

    ttk::frame $path
    set state($path,tree) {}
    bind $path <Destroy> [list ::tkutils::tkujson::_cleanup $path %W]

    ttk::treeview $path.tv -columns {value} -show {tree headings} \
        -height $opts(-height)
    $path.tv heading #0 -text "key"
    $path.tv heading value -text "value"
    $path.tv column #0 -width 220 -anchor w
    $path.tv column value -width 260 -anchor w
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

# Parse and display JSON from a string. Returns the root node's type.
proc ::tkutils::tkujson::setJson {path jsonText} {
    variable state
    set state($path,tree) [::tclutils::tujson::parseTyped $jsonText]
    _populate $path
    return [lindex $state($path,tree) 0]
}

proc ::tkutils::tkujson::loadFile {path filename} {
    variable state
    set state($path,tree) \
        [::tclutils::tujson::parseTyped [::tclutils::common::readFile $filename]]
    _populate $path
    return $filename
}

# Return the typed parse tree ({type value}, see tujson::parseTyped).
proc ::tkutils::tkujson::getTree {path} {
    variable state
    return $state($path,tree)
}

proc ::tkutils::tkujson::_populate {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    if {$state($path,tree) eq ""} return
    _insert $tv {} "(root)" $state($path,tree)
}

proc ::tkutils::tkujson::_insert {tv parent label node} {
    lassign $node type val
    switch -- $type {
        object {
            set id [$tv insert $parent end -text $label \
                -values [list "object ([dict size $val])"] -open 1]
            dict for {k child} $val {
                _insert $tv $id $k $child
            }
        }
        array {
            set id [$tv insert $parent end -text $label \
                -values [list "array ([llength $val])"] -open 1]
            set i 0
            foreach child $val {
                _insert $tv $id "\[$i\]" $child
                incr i
            }
        }
        string  { $tv insert $parent end -text $label -values [list "\"$val\""] }
        number  { $tv insert $parent end -text $label -values [list $val] }
        boolean { $tv insert $parent end -text $label -values [list $val] }
        null    { $tv insert $parent end -text $label -values [list "null"] }
        default { $tv insert $parent end -text $label -values [list $val] }
    }
}

package provide tkutils::tkujson 0.1
