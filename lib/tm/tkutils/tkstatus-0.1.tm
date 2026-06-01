# tkutils::tkstatus -- status bar widget
#
# A status bar with an expanding main message, optional named fields, and an
# optional progress bar. Pure Tk. Tcl/Tk 8.6+ and 9.x compatible.
#
# Note: the main-text accessors are setText/getText (not set/get) so the module
# does not shadow the Tcl `set` command.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkstatus {
    namespace export widget setText getText addField setField fieldText \
        progress flash
    variable state
}

proc ::tkutils::tkstatus::_cleanup {path w} {
    variable state
    if {$w eq $path} {
        if {[info exists state($path,after)] && $state($path,after) ne ""} {
            catch {after cancel $state($path,after)}
        }
        array unset state $path,*
    }
}

# Build the status bar under $path.
proc ::tkutils::tkstatus::widget {path args} {
    variable state
    ttk::frame $path
    set state($path,main) ""
    set state($path,count) 0
    set state($path,map) [dict create]
    set state($path,after) ""
    bind $path <Destroy> [list ::tkutils::tkstatus::_cleanup $path %W]

    ttk::separator $path.sep -orient horizontal
    ttk::frame $path.row
    ttk::label $path.row.main -anchor w
    pack $path.sep -side top -fill x
    pack $path.row -side top -fill x
    pack $path.row.main -side left -fill x -expand 1 -padx 4
    return $path
}

# Set / get the main message.
proc ::tkutils::tkstatus::setText {path text} {
    variable state
    set state($path,main) $text
    $path.row.main configure -text $text
    return $text
}
proc ::tkutils::tkstatus::getText {path} {
    variable state
    return $state($path,main)
}

# Add a named field on the right. Options: -width N.
proc ::tkutils::tkstatus::addField {path id args} {
    variable state
    array set o {-width 0}
    array set o $args
    set w $path.row.f[incr state($path,count)]
    ttk::label $w -relief sunken -anchor w -padding {4 0}
    if {$o(-width) > 0} { $w configure -width $o(-width) }
    pack $w -side right -padx 2
    dict set state($path,map) $id $w
    return $w
}

proc ::tkutils::tkstatus::setField {path id text} {
    variable state
    [dict get $state($path,map) $id] configure -text $text
    return $text
}

proc ::tkutils::tkstatus::fieldText {path id} {
    variable state
    return [[dict get $state($path,map) $id] cget -text]
}

# Show/update or hide a progress bar. value "" hides it; 0..100 shows it.
proc ::tkutils::tkstatus::progress {path {value ""}} {
    if {$value eq ""} {
        if {[winfo exists $path.row.pb]} { pack forget $path.row.pb }
        return ""
    }
    if {![winfo exists $path.row.pb]} {
        ttk::progressbar $path.row.pb -length 120 -mode determinate -maximum 100
    }
    pack $path.row.pb -side right -padx 4
    $path.row.pb configure -value $value
    return $value
}

# Briefly show $text, then restore the previous main message after $ms.
proc ::tkutils::tkstatus::flash {path text {ms 2000}} {
    variable state
    if {$state($path,after) ne ""} { catch {after cancel $state($path,after)} }
    set previous $state($path,main)
    $path.row.main configure -text $text
    set state($path,after) [after $ms \
        [list ::tkutils::tkstatus::_restore $path $previous]]
    return $text
}

proc ::tkutils::tkstatus::_restore {path text} {
    variable state
    set state($path,after) ""
    if {[winfo exists $path.row.main]} {
        $path.row.main configure -text $text
    }
}

package provide tkutils::tkstatus 0.1
