# tkutils::tkufilterbar -- a per-column filter bar: one small entry per column,
# each typing a substring that the consumer ANDs together. Mirrors the tku*
# widget style of tkutils and complements tkusearchbar (single free-text box).
#
# Typing in any field fires -command after -delay ms of inactivity (debounced)
# and on <Return>, as
#   cmd filters
# where filters is a dict {column -> text} holding only the non-empty fields.
# The set of columns is dynamic: call setColumns to (re)build the row. Clearing
# fires immediately. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkufilterbar {
    namespace export widget setColumns columns getFilters getFilter setFilter \
        clear focusFirst
    variable state
}

proc ::tkutils::tkufilterbar::_cleanup {path w} {
    variable state
    if {$w eq $path} {
        catch {after cancel $state($path,after)}
        array unset state $path,*
    }
}

# Build an (initially empty) filter bar under $path.
# Options: -command cmd, -delay ms (default 300), -width n (entry width, 10).
proc ::tkutils::tkufilterbar::widget {path args} {
    variable state
    array set o {-command "" -delay 300 -width 10}
    array set o $args

    ttk::frame $path
    set state($path,cmd) $o(-command)
    set state($path,delay) $o(-delay)
    set state($path,width) $o(-width)
    set state($path,after) ""
    set state($path,cols) {}
    bind $path <Destroy> [list ::tkutils::tkufilterbar::_cleanup $path %W]
    return $path
}

# (Re)build the row: one label + entry per column. Existing field contents are
# discarded. Each entry filters its own column.
proc ::tkutils::tkufilterbar::setColumns {path cols} {
    variable state
    foreach w [winfo children $path] { destroy $w }
    array unset state $path,val,*
    set state($path,cols) $cols
    set i 0
    foreach c $cols {
        ttk::label $path.l$i -text $c -anchor w
        set state($path,val,$i) ""
        ttk::entry $path.e$i -width $state($path,width) \
            -textvariable ::tkutils::tkufilterbar::state($path,val,$i)
        grid $path.l$i -row 0 -column $i -sticky ew -padx 1
        grid $path.e$i -row 1 -column $i -sticky ew -padx 1
        grid columnconfigure $path $i -weight 1
        bind $path.e$i <KeyRelease> [list ::tkutils::tkufilterbar::_onChange $path]
        bind $path.e$i <Return>     [list ::tkutils::tkufilterbar::_fire $path]
        incr i
    }
    return $cols
}

# --- public API ----------------------------------------------------------

proc ::tkutils::tkufilterbar::columns {path} {
    variable state
    return $state($path,cols)
}

# Dict {column -> text} of the non-empty fields, in column order.
proc ::tkutils::tkufilterbar::getFilters {path} {
    variable state
    set out {}
    set i 0
    foreach c $state($path,cols) {
        set v $state($path,val,$i)
        if {[string trim $v] ne ""} { dict set out $c $v }
        incr i
    }
    return $out
}

# Text of a single column's field ("" if unknown/empty).
proc ::tkutils::tkufilterbar::getFilter {path col} {
    variable state
    set i [lsearch -exact $state($path,cols) $col]
    if {$i < 0} { return "" }
    return $state($path,val,$i)
}

# Set one column's field programmatically (does not fire -command).
proc ::tkutils::tkufilterbar::setFilter {path col text} {
    variable state
    set i [lsearch -exact $state($path,cols) $col]
    if {$i < 0} { return "" }
    set state($path,val,$i) $text
    return $text
}

proc ::tkutils::tkufilterbar::clear {path} {
    variable state
    set i 0
    foreach c $state($path,cols) { set state($path,val,$i) ""; incr i }
    _fire $path
    return
}

proc ::tkutils::tkufilterbar::focusFirst {path} {
    variable state
    if {[llength $state($path,cols)]} { focus $path.e0; return $path.e0 }
    return ""
}

# --- internals -----------------------------------------------------------

proc ::tkutils::tkufilterbar::_onChange {path} {
    variable state
    after cancel $state($path,after)
    set state($path,after) \
        [after $state($path,delay) [list ::tkutils::tkufilterbar::_fire $path]]
}

proc ::tkutils::tkufilterbar::_fire {path} {
    variable state
    after cancel $state($path,after)
    set state($path,after) ""
    if {$state($path,cmd) ne ""} {
        uplevel #0 [linsert $state($path,cmd) end [getFilters $path]]
    }
}

package provide tkutils::tkufilterbar 0.1
