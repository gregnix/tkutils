# tkutils::tkutoolbar -- toolbar widget
#
# A horizontal toolbar holding buttons, toggles, separators and arbitrary
# embedded widgets, addressed by caller-chosen ids. Pure Tk. Tcl/Tk 8.6+ / 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutoolbar {
    namespace export widget addButton addToggle addSeparator addWidget \
        setEnabled buttonWidget items
    variable state
}

proc ::tkutils::tkutoolbar::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the toolbar under $path.
proc ::tkutils::tkutoolbar::widget {path args} {
    variable state
    ttk::frame $path -padding 2
    set state($path,count) 0
    set state($path,items) {}
    set state($path,map) [dict create]
    bind $path <Destroy> [list ::tkutils::tkutoolbar::_cleanup $path %W]
    return $path
}

proc ::tkutils::tkutoolbar::_add {path id w} {
    variable state
    pack $w -side left -padx 1 -pady 1
    if {$id ne ""} {
        dict set state($path,map) $id $w
        lappend state($path,items) $id
    }
    return $w
}

# Add a push button. Returns the button widget.
proc ::tkutils::tkutoolbar::addButton {path id label command args} {
    variable state
    set w $path.w[incr state($path,count)]
    ttk::button $w -text $label -command $command -style Toolbutton {*}$args
    return [_add $path $id $w]
}

# Add a toggle (checkbutton) bound to $varName. Returns the widget.
proc ::tkutils::tkutoolbar::addToggle {path id label varName args} {
    variable state
    set w $path.w[incr state($path,count)]
    ttk::checkbutton $w -text $label -variable $varName -style Toolbutton {*}$args
    return [_add $path $id $w]
}

proc ::tkutils::tkutoolbar::addSeparator {path} {
    variable state
    set w $path.w[incr state($path,count)]
    ttk::separator $w -orient vertical
    pack $w -side left -fill y -padx 3 -pady 1
    return $w
}

# Embed an already-created child widget of $path into the toolbar.
proc ::tkutils::tkutoolbar::addWidget {path id w} {
    return [_add $path $id $w]
}

# Enable or disable an item by id.
proc ::tkutils::tkutoolbar::setEnabled {path id enabled} {
    variable state
    set w [dict get $state($path,map) $id]
    if {$enabled} {
        $w state !disabled
    } else {
        $w state disabled
    }
    return $enabled
}

# Return the widget path for an item id.
proc ::tkutils::tkutoolbar::buttonWidget {path id} {
    variable state
    return [dict get $state($path,map) $id]
}

# Return the list of item ids in insertion order.
proc ::tkutils::tkutoolbar::items {path} {
    variable state
    return $state($path,items)
}

package provide tkutils::tkutoolbar 0.1
