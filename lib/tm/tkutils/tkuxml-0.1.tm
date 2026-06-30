# tkutils::tkuxml -- XML tree viewer
# Description: XML tree viewer
# Category: Tk · widgets
#
# Tk front-end that shows an XML document as a nested tree. Parsing is done by
# tDOM. tDOM is an EXTERNAL dependency (not part of tclutils); this widget is
# therefore optional and is not pulled in by the tkutils umbrella package -- load
# it directly with `package require tkutils::tkuxml` once tdom is available.
# Tcl/Tk 8.6+ and 9.x compatible (where a matching tDOM build exists).

package require Tcl 8.6-
package require Tk 8.6-
package require tdom
package require tclutils::common 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuxml {
    namespace export widget setXml loadFile getRoot
    variable state
}

proc ::tkutils::tkuxml::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    if {[info exists state($path,doc)] && $state($path,doc) ne ""} {
        catch {$state($path,doc) delete}
    }
    array unset state $path,*
}

# Build the tree widget under $path. Option: -height N (visible rows).
proc ::tkutils::tkuxml::widget {path args} {
    variable state
    array set opts {-height 20}
    array set opts $args

    ttk::frame $path
    set state($path,doc) ""
    bind $path <Destroy> [list ::tkutils::tkuxml::_cleanup $path %W]

    ttk::treeview $path.tv -columns {info} -show {tree headings} \
        -height $opts(-height)
    $path.tv heading #0 -text "node"
    $path.tv heading info -text "attributes / text"
    $path.tv column #0 -width 240 -anchor w
    $path.tv column info -width 300 -anchor w
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

# Parse and display XML from a string. Returns the root element name.
proc ::tkutils::tkuxml::setXml {path xml} {
    variable state
    if {$state($path,doc) ne ""} { catch {$state($path,doc) delete} }
    set state($path,doc) [dom parse $xml]
    _populate $path
    return [getRoot $path]
}

proc ::tkutils::tkuxml::loadFile {path filename} {
    variable state
    setXml $path [::tclutils::common::readFile $filename]
    set state($path,file) $filename
    return $filename
}

# Return the root element's name (or "" if nothing is loaded).
proc ::tkutils::tkuxml::getRoot {path} {
    variable state
    if {$state($path,doc) eq ""} { return "" }
    return [[$state($path,doc) documentElement] nodeName]
}

proc ::tkutils::tkuxml::_populate {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    if {$state($path,doc) eq ""} return
    _insertNode $tv {} [$state($path,doc) documentElement]
}

proc ::tkutils::tkuxml::_insertNode {tv parent node} {
    set attrs {}
    foreach a [$node attributes] {
        # attribute names may be returned as plain names or {name ns uri}
        set aname [lindex $a 0]
        lappend attrs "$aname=\"[$node getAttribute $aname]\""
    }
    set id [$tv insert $parent end -text [$node nodeName] \
        -values [list [join $attrs " "]] -open 1]
    foreach c [$node childNodes] {
        switch -- [$c nodeType] {
            ELEMENT_NODE { _insertNode $tv $id $c }
            TEXT_NODE -
            CDATA_SECTION_NODE {
                set t [string trim [$c nodeValue]]
                if {$t ne ""} {
                    $tv insert $id end -text "#text" -values [list $t]
                }
            }
        }
    }
}

package provide tkutils::tkuxml 0.1
