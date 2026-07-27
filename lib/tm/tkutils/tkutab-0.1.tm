# tkutils::tkutab -- a tabbed container with the conveniences a file manager
# needs, which bare ttk::notebook lacks: a "+" new-tab button and closeable
# tabs (middle-click, or a close entry from the caller).
#
# It is a thin wrapper over ttk::notebook: the notebook does the tab display
# and switching; tkutab adds the new-tab affordance, middle-click-to-close,
# and a callback API. Each tab's content is an empty frame the caller fills.
#
#   tkutab::widget .tabs \
#       -onnew    {::app::newTab}      ;# called when "+" is pressed
#       -onclose  {::app::closeTab}    ;# called with the content frame before it closes
#       -onselect {::app::selectTab}   ;# called with the content frame on switch
#   set f [tkutab::add .tabs "Label"]  ;# returns the content frame to fill
#   tkutab::current .tabs              ;# content frame of the active tab
#   tkutab::setLabel .tabs $f "New"    ;# rename a tab
#   tkutab::close .tabs $f             ;# close a tab programmatically
#
# The caller gets a frame path from add/current and fills it with its own
# widgets. tkutab never touches the content.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutab {
    namespace export widget add close current setLabel tabs count
    variable state
}

proc ::tkutils::tkutab::widget {path args} {
    variable state
    array set o {-onnew "" -onclose "" -onselect ""}
    array set o $args

    ttk::frame $path
    set state($path,onnew)  $o(-onnew)
    set state($path,onclose) $o(-onclose)
    set state($path,onsel)  $o(-onselect)
    set state($path,seq)    0
    bind $path <Destroy> [list ::tkutils::tkutab::_cleanup $path %W]

    # a small bar with the "+" button, then the notebook below
    ttk::frame $path.bar
    ttk::button $path.bar.new -text "+" -width 2 -style Toolbutton \
        -command [list ::tkutils::tkutab::_new $path]
    pack $path.bar.new -side left -padx 2 -pady 2
    pack $path.bar -side top -fill x

    ttk::notebook $path.nb
    pack $path.nb -side top -fill both -expand 1

    # middle-click on a tab closes it
    bind $path.nb <Button-2> [list ::tkutils::tkutab::_middleClose $path %x %y]
    # notify on tab switch
    bind $path.nb <<NotebookTabChanged>> [list ::tkutils::tkutab::_switched $path]

    return $path
}

# Add a tab with a label; return the content frame for the caller to fill.
proc ::tkutils::tkutab::add {path label} {
    variable state
    set id [incr state($path,seq)]
    set f $path.nb.tab$id
    ttk::frame $f
    $path.nb add $f -text $label
    $path.nb select $f
    return $f
}

# Close a tab given its content frame. Fires -onclose first.
proc ::tkutils::tkutab::close {path f} {
    variable state
    if {![winfo exists $f]} return
    if {$state($path,onclose) ne ""} {
        uplevel #0 [linsert $state($path,onclose) end $f]
    }
    $path.nb forget $f
    destroy $f
    return
}

# Content frame of the active tab, or "" if none.
proc ::tkutils::tkutab::current {path} {
    set sel [$path.nb select]
    return $sel
}

proc ::tkutils::tkutab::setLabel {path f label} {
    $path.nb tab $f -text $label
    return
}

proc ::tkutils::tkutab::tabs {path} {
    return [$path.nb tabs]
}

proc ::tkutils::tkutab::count {path} {
    return [llength [$path.nb tabs]]
}

# ---- internals ------------------------------------------------------------
proc ::tkutils::tkutab::_new {path} {
    variable state
    if {$state($path,onnew) ne ""} {
        uplevel #0 $state($path,onnew)
    }
}

proc ::tkutils::tkutab::_middleClose {path x y} {
    set idx [$path.nb identify tab $x $y]
    if {$idx eq ""} return
    set f [lindex [$path.nb tabs] $idx]
    close $path $f
}

proc ::tkutils::tkutab::_switched {path} {
    variable state
    if {$state($path,onsel) eq ""} return
    set f [$path.nb select]
    if {$f ne ""} { uplevel #0 [linsert $state($path,onsel) end $f] }
}

proc ::tkutils::tkutab::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    array unset state $path,*
}

package provide tkutils::tkutab 0.1
