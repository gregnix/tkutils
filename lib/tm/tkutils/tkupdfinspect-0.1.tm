# tkutils::tkupdfinspect -- PDF structure inspector (read-only)
#
# A Tk front-end on top of the tclutils PDF engine (tupdf). Shows a tree of the
# document summary, Info metadata, trailer, ZUGFeRD detection and the indirect
# objects; selecting a node renders its detail in a read-only text pane. The
# editor stays a viewer: it never writes to the PDF. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tupdf

namespace eval ::tkutils {}
namespace eval ::tkutils::tkupdfinspect {
    namespace export widget loadFile currentFile summary treeWidget textWidget
    variable state
}

proc ::tkutils::tkupdfinspect::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the inspector under $path. Options: -width N -height N (the text pane's
# character geometry).
proc ::tkutils::tkupdfinspect::widget {path args} {
    variable state
    array set opts {-width 64 -height 24}
    array set opts $args

    ttk::frame $path
    set state($path,file)    ""
    set state($path,summary) {}
    bind $path <Destroy> [list ::tkutils::tkupdfinspect::_cleanup $path %W]

    ttk::panedwindow $path.pw -orient horizontal

    # left: structure tree
    ttk::frame $path.pw.l
    ttk::treeview $path.pw.l.tree -show tree -selectmode browse
    ttk::scrollbar $path.pw.l.ys -orient vertical -command [list $path.pw.l.tree yview]
    $path.pw.l.tree configure -yscrollcommand [list $path.pw.l.ys set]
    grid $path.pw.l.tree $path.pw.l.ys -sticky nsew
    grid rowconfigure    $path.pw.l 0 -weight 1
    grid columnconfigure $path.pw.l 0 -weight 1

    # right: detail text (read-only, monospace)
    ttk::frame $path.pw.r
    text $path.pw.r.t -width $opts(-width) -height $opts(-height) -wrap none \
        -state disabled
    ttk::scrollbar $path.pw.r.ys -orient vertical   -command [list $path.pw.r.t yview]
    ttk::scrollbar $path.pw.r.xs -orient horizontal -command [list $path.pw.r.t xview]
    $path.pw.r.t configure -yscrollcommand [list $path.pw.r.ys set] \
        -xscrollcommand [list $path.pw.r.xs set]
    grid $path.pw.r.t $path.pw.r.ys -sticky nsew
    grid $path.pw.r.xs -sticky ew
    grid rowconfigure    $path.pw.r 0 -weight 1
    grid columnconfigure $path.pw.r 0 -weight 1

    $path.pw add $path.pw.l -weight 1
    $path.pw add $path.pw.r -weight 3
    grid $path.pw -sticky nsew
    grid rowconfigure    $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    bind $path.pw.l.tree <<TreeviewSelect>> [list ::tkutils::tkupdfinspect::_show $path]
    return $path
}

proc ::tkutils::tkupdfinspect::treeWidget {path} { return $path.pw.l.tree }
proc ::tkutils::tkupdfinspect::textWidget {path} { return $path.pw.r.t }
proc ::tkutils::tkupdfinspect::currentFile {path} {
    variable state
    return $state($path,file)
}

# The cached summary dict from the last loadFile (convenience accessor).
proc ::tkutils::tkupdfinspect::summary {path} {
    variable state
    return $state($path,summary)
}

# Inspect $filename: read the structure via tupdf and populate the tree. The
# first node (Document) is selected so the summary shows immediately.
proc ::tkutils::tkupdfinspect::loadFile {path filename} {
    variable state
    set tree $path.pw.l.tree
    $tree delete [$tree children {}]

    # tupdf raises {TCLUTILS TUPDF FORMAT} for non-PDF input; surface it.
    set sm [::tclutils::tupdf::summary $filename]
    set state($path,file)    $filename
    set state($path,summary) $sm

    # The item -values carry a {kind ?arg?} spec the selection handler renders.
    $tree insert {} end -id doc      -text "Document"   -values [list summary]
    $tree insert {} end -id meta     -text "Metadata"   -values [list metadata]
    $tree insert {} end -id trailer  -text "Trailer"    -values [list trailer]
    $tree insert {} end -id zugferd  -text "ZUGFeRD"    -values [list zugferd]

    set ids [::tclutils::tupdf::objects $filename]
    $tree insert {} end -id objects -text "Objects ([llength $ids])" \
        -values [list objects]
    foreach id $ids {
        $tree insert objects end -id obj-$id -text "obj $id" \
            -values [list object $id]
    }

    $tree selection set doc
    _show $path
    return $filename
}

# Render the selected node's detail into the (read-only) text pane.
proc ::tkutils::tkupdfinspect::_show {path} {
    variable state
    set tree $path.pw.l.tree
    set sel [$tree selection]
    if {$sel eq ""} { return }
    set spec [$tree item $sel -values]
    set kind [lindex $spec 0]
    set arg  [lindex $spec 1]
    set fn   $state($path,file)

    switch -- $kind {
        summary  { set out [_fmtDict [_orderedSummary $state($path,summary)]] }
        metadata { set out [_fmtDict [::tclutils::tupdf::metadata $fn]] }
        trailer  {
            set out [::tclutils::tupdf::trailer $fn]
            if {$out eq ""} { set out "(no trailer dictionary found)" }
        }
        zugferd  { set out [_fmtDict [::tclutils::tupdf::zugferd $fn]] }
        objects  { set out "Select an object to view its raw content." }
        object   {
            if {[catch {::tclutils::tupdf::object $fn $arg} out]} {
                set out "object $arg: $out"
            }
        }
        default  { set out "" }
    }
    _setText $path $out
    return
}

# Format a dict as aligned "key: value" lines.
proc ::tkutils::tkupdfinspect::_fmtDict {d} {
    set w 0
    foreach {k v} $d { if {[string length $k] > $w} { set w [string length $k] } }
    set lines {}
    foreach {k v} $d {
        lappend lines [format "%-*s  %s" $w $k $v]
    }
    return [join $lines \n]
}

# Put the well-known summary keys first, then any remaining (metadata) keys.
proc ::tkutils::tkupdfinspect::_orderedSummary {sm} {
    set order {version size objects pages encrypted linearized acroform \
               zugferdDetected zugferdProfile}
    set out {}
    foreach k $order {
        if {[dict exists $sm $k]} { lappend out $k [dict get $sm $k] }
    }
    foreach {k v} $sm {
        if {$k ni $order} { lappend out $k $v }
    }
    return $out
}

proc ::tkutils::tkupdfinspect::_setText {path s} {
    set t $path.pw.r.t
    $t configure -state normal
    $t delete 1.0 end
    $t insert end $s
    $t configure -state disabled
    $t see 1.0
}

package provide tkutils::tkupdfinspect 0.1
