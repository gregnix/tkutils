# tkutils::tksearchbar -- a search bar: entry with debounced change callback,
# a clear button, and an optional filter drop-down.
#
# Typing fires -command after -delay ms of inactivity (debounced), as
#   cmd searchText filterValue
# Clearing and changing the filter fire immediately. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tksearchbar {
    namespace export widget getText setText clear getFilter setFilter focusSearch
    variable state
}

proc ::tkutils::tksearchbar::_cleanup {path w} {
    variable state
    if {$w eq $path} {
        after cancel $state($path,after)
        array unset state $path,*
    }
}

# Build the search bar under $path.
# Options: -command cmd, -delay ms (default 300), -filters list, -width n.
proc ::tkutils::tksearchbar::widget {path args} {
    variable state
    array set opts {-command "" -delay 300 -filters {} -width 28}
    array set opts $args

    ttk::frame $path
    set state($path,cmd) $opts(-command)
    set state($path,delay) $opts(-delay)
    set state($path,after) ""
    set state($path,text) ""
    set state($path,filter) ""
    bind $path <Destroy> [list ::tkutils::tksearchbar::_cleanup $path %W]

    ttk::entry $path.e -width $opts(-width) \
        -textvariable ::tkutils::tksearchbar::state($path,text)
    ttk::button $path.clear -text "\u00d7" -width 2 \
        -command [list ::tkutils::tksearchbar::clear $path]
    grid $path.e $path.clear -sticky ew -padx {0 2}
    grid columnconfigure $path 0 -weight 1
    bind $path.e <KeyRelease> [list ::tkutils::tksearchbar::_onChange $path]
    bind $path.e <Return>     [list ::tkutils::tksearchbar::_fire $path]

    if {[llength $opts(-filters)] > 0} {
        set state($path,filter) [lindex $opts(-filters) 0]
        ttk::separator $path.sep -orient vertical
        ttk::combobox $path.filter -values $opts(-filters) -state readonly \
            -width 14 -textvariable ::tkutils::tksearchbar::state($path,filter)
        grid $path.sep -row 0 -column 2 -sticky ns -padx 4
        grid $path.filter -row 0 -column 3 -sticky e
        bind $path.filter <<ComboboxSelected>> \
            [list ::tkutils::tksearchbar::_fire $path]
    }
    return $path
}

# --- public API ----------------------------------------------------------

proc ::tkutils::tksearchbar::getText {path} {
    variable state
    return $state($path,text)
}

# Set the search text programmatically (does not fire -command).
proc ::tkutils::tksearchbar::setText {path text} {
    variable state
    set state($path,text) $text
    return $text
}

proc ::tkutils::tksearchbar::clear {path} {
    variable state
    set state($path,text) ""
    _fire $path
    return ""
}

proc ::tkutils::tksearchbar::getFilter {path} {
    variable state
    return $state($path,filter)
}

proc ::tkutils::tksearchbar::setFilter {path value} {
    variable state
    set state($path,filter) $value
    return $value
}

proc ::tkutils::tksearchbar::focusSearch {path} {
    focus $path.e
    return $path.e
}

# --- internals -----------------------------------------------------------

# Debounce: (re)schedule a fire -delay ms from the last keystroke.
proc ::tkutils::tksearchbar::_onChange {path} {
    variable state
    after cancel $state($path,after)
    set state($path,after) \
        [after $state($path,delay) [list ::tkutils::tksearchbar::_fire $path]]
}

proc ::tkutils::tksearchbar::_fire {path} {
    variable state
    after cancel $state($path,after)
    set state($path,after) ""
    if {$state($path,cmd) ne ""} {
        uplevel #0 [linsert $state($path,cmd) end \
            $state($path,text) $state($path,filter)]
    }
}

package provide tkutils::tksearchbar 0.1
