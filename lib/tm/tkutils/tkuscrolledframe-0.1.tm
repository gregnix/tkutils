# tkutils::tkuscrolledframe -- scrollable frame container (thin scrollutil wrapper)
#
# A scrollable area you pack arbitrary widgets into -- the one container ttk
# does not provide natively. This is a thin, proc-style wrapper over Csaba
# Nemethi's scrollutil (scrollarea + scrollableframe), in tkutils conventions
# (path = identity, per-widget state, <Destroy> cleanup).
#
# OPTIONAL module -- needs the external `scrollutil` package (tklib); not loaded
# by the tkutils umbrella. Tcl/Tk 8.6+ / 9.x.
#
#   tkuscrolledframe::widget  .sf -width 400 -height 300
#   pack .sf -fill both -expand 1
#   pack [ttk::button [tkuscrolledframe::content .sf].b -text Hi]
#   tkuscrolledframe::see .sf [tkuscrolledframe::content .sf].b
#
# Error codes: {TKUTILS TKUSCROLLEDFRAME <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuscrolledframe {
    namespace export widget content scrollableframe scrollarea \
        see seerect xview yview autosize autofillx autofilly configure
    variable state
}

proc ::tkutils::tkuscrolledframe::_require {path} {
    variable state
    if {![info exists state($path,sf)]} {
        return -code error -errorcode {TKUTILS TKUSCROLLEDFRAME NOWIDGET} \
            "unknown scrolledframe '$path'"
    }
}

proc ::tkutils::tkuscrolledframe::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    array unset state $path,*
}

# Build a scrollable frame at $path. Options: -width -height
# -xscrollincrement -yscrollincrement (all non-negative integers).
proc ::tkutils::tkuscrolledframe::widget {path args} {
    variable state
    if {[catch {package require scrollutil}]} {
        return -code error -errorcode {TKUTILS TKUSCROLLEDFRAME NOSCROLLUTIL} \
            "the scrollutil package (tklib) is required for tkuscrolledframe"
    }
    array set opts {-width 300 -height 200 -xscrollincrement 0 -yscrollincrement 0}
    foreach {o v} $args {
        if {![info exists opts($o)]} {
            return -code error -errorcode {TKUTILS TKUSCROLLEDFRAME OPTION} \
                "unknown option '$o'"
        }
        if {![string is integer -strict $v] || $v < 0} {
            return -code error -errorcode {TKUTILS TKUSCROLLEDFRAME VALUE} \
                "option '$o' needs a non-negative integer"
        }
        set opts($o) $v
    }

    ttk::frame $path
    set area [scrollutil::scrollarea $path.sa]
    set sf [scrollutil::scrollableframe $area.sf \
        -width $opts(-width) -height $opts(-height) \
        -xscrollincrement $opts(-xscrollincrement) \
        -yscrollincrement $opts(-yscrollincrement)]
    $area setwidget $sf
    pack $area -fill both -expand 1

    set state($path,area)    $area
    set state($path,sf)      $sf
    set state($path,content) [$sf contentframe]
    bind $path <Destroy> [list ::tkutils::tkuscrolledframe::_cleanup $path %W]
    return $path
}

# The frame to pack/grid your content into.
proc ::tkutils::tkuscrolledframe::content {path} {
    variable state
    _require $path
    return $state($path,content)
}

proc ::tkutils::tkuscrolledframe::scrollableframe {path} {
    variable state
    _require $path
    return $state($path,sf)
}

proc ::tkutils::tkuscrolledframe::scrollarea {path} {
    variable state
    _require $path
    return $state($path,area)
}

# Reconfigure geometry options after creation.
proc ::tkutils::tkuscrolledframe::configure {path args} {
    variable state
    _require $path
    $state($path,sf) configure {*}$args
    return $path
}

# Scroll a child widget into view.
proc ::tkutils::tkuscrolledframe::see {path w {corner nw}} {
    variable state
    _require $path
    $state($path,sf) see $w $corner
}

proc ::tkutils::tkuscrolledframe::seerect {path x1 y1 x2 y2 {corner nw}} {
    variable state
    _require $path
    $state($path,sf) seerect $x1 $y1 $x2 $y2 $corner
}

proc ::tkutils::tkuscrolledframe::xview {path args} {
    variable state
    _require $path
    if {[llength $args] == 0} { return [$state($path,sf) xview] }
    $state($path,sf) xview {*}$args
}

proc ::tkutils::tkuscrolledframe::yview {path args} {
    variable state
    _require $path
    if {[llength $args] == 0} { return [$state($path,sf) yview] }
    $state($path,sf) yview {*}$args
}

proc ::tkutils::tkuscrolledframe::autosize {path dimensions} {
    variable state
    _require $path
    $state($path,sf) autosize $dimensions
}

proc ::tkutils::tkuscrolledframe::autofillx {path boolean} {
    variable state
    _require $path
    $state($path,sf) autofillx $boolean
}

proc ::tkutils::tkuscrolledframe::autofilly {path boolean} {
    variable state
    _require $path
    $state($path,sf) autofilly $boolean
}

package provide tkutils::tkuscrolledframe 0.1
