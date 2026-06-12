# tkutils::tkulabeled -- labeled input composites (label + control in one)
#
# Standalone "label + input" rows you can drop into any layout, when a full
# tkuform dict is more than you need. The widget is the frame at $path; the
# inner control is reachable, and one `value` accessor reads/writes it.
# Types: entry, combo, spin, check, text. Pure Tk. 8.6+ / 9.x.
#
#   tkulabeled::add .name  entry -label "Name:" -labelwidth 10
#   tkulabeled::add .lang  combo -label "Lang:" -values {Tcl Tk C}
#   tkulabeled::add .age   spin  -label "Age:"  -from 0 -to 120
#   tkulabeled::add .vip   check -label "VIP"   -variable ::vip
#   tkulabeled::add .notes text  -label "Notes:" -height 4
#   pack .name .lang .age .vip .notes -fill x
#   tkulabeled::value .name "Ada"          ;# set
#   tkulabeled::value .name                ;# get -> Ada
#
# The type is passed as a *value*, not a proc name, so nothing here shadows a
# Tcl/Tk builtin (entry/text/set ...). Error codes: {TKUTILS TKULABELED <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkulabeled {
    namespace export add value control labelwidget configure
    variable state
    # type -> {control-command default-orient}
    variable types {
        entry {ttk::entry     horizontal}
        combo {ttk::combobox  horizontal}
        spin  {ttk::spinbox   horizontal}
        check {ttk::checkbutton horizontal}
        text  {text           vertical}
    }
}

proc ::tkutils::tkulabeled::_require {path} {
    variable state
    if {![info exists state($path,type)]} {
        return -code error -errorcode {TKUTILS TKULABELED NOWIDGET} \
            "unknown labeled widget '$path'"
    }
}

proc ::tkutils::tkulabeled::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    array unset state $path,*
}

# Build a labeled composite. $type is one of entry/combo/spin/check/text.
# Composite options: -label -labelwidth -orient (horizontal|vertical).
# Any other -opt value pairs are forwarded to the inner control.
proc ::tkutils::tkulabeled::add {path type args} {
    variable state
    variable types
    if {![dict exists $types $type]} {
        return -code error -errorcode {TKUTILS TKULABELED TYPE} \
            "unknown type '$type': must be entry, combo, spin, check or text"
    }
    lassign [dict get $types $type] ctlCmd defOrient

    array set opts [list -label "" -labelwidth 0 -orient $defOrient]
    set rest {}
    foreach {o v} $args {
        switch -- $o {
            -label      { set opts(-label) $v }
            -labelwidth { set opts(-labelwidth) $v }
            -orient     { set opts(-orient) $v }
            default     { lappend rest $o $v }
        }
    }
    if {$opts(-orient) ni {horizontal vertical}} {
        return -code error -errorcode {TKUTILS TKULABELED ORIENT} \
            "bad -orient '$opts(-orient)': must be horizontal or vertical"
    }

    ttk::frame $path
    ttk::label $path.label -text $opts(-label)
    if {$opts(-labelwidth) > 0} { $path.label configure -width $opts(-labelwidth) }
    set ctl [$ctlCmd $path.ctl {*}$rest]

    if {$opts(-orient) eq "vertical"} {
        pack $path.label -side top -anchor w
        pack $ctl -side top -fill both -expand 1
    } else {
        pack $path.label -side left -anchor w -padx {0 6}
        pack $ctl -side left -fill x -expand 1
    }

    set state($path,type)    $type
    set state($path,control) $ctl
    set state($path,label)   $path.label
    bind $path <Destroy> [list ::tkutils::tkulabeled::_cleanup $path %W]
    return $path
}

# Read (1 arg) or write (2 args) the composite's value.
proc ::tkutils::tkulabeled::value {path args} {
    variable state
    _require $path
    set c $state($path,control)
    set type $state($path,type)
    if {[llength $args] == 0} {
        switch -- $type {
            entry - combo - spin { return [$c get] }
            text  { return [$c get 1.0 end-1c] }
            check {
                set var [$c cget -variable]
                if {$var eq ""} { return "" }
                return [set $var]
            }
        }
    }
    if {[llength $args] != 1} {
        return -code error -errorcode {TKUTILS TKULABELED ARGS} \
            "wrong # args: value path ?newValue?"
    }
    set v [lindex $args 0]
    switch -- $type {
        entry - spin { $c delete 0 end; $c insert 0 $v }
        combo { $c set $v }
        text  { $c delete 1.0 end; $c insert end $v }
        check {
            set var [$c cget -variable]
            if {$var ne ""} { set $var $v }
        }
    }
    return $v
}

proc ::tkutils::tkulabeled::control {path} {
    variable state
    _require $path
    return $state($path,control)
}

proc ::tkutils::tkulabeled::labelwidget {path} {
    variable state
    _require $path
    return $state($path,label)
}

# Change the caption (-label) and/or forward other options to the control.
proc ::tkutils::tkulabeled::configure {path args} {
    variable state
    _require $path
    set rest {}
    foreach {o v} $args {
        if {$o eq "-label"} {
            $state($path,label) configure -text $v
        } else {
            lappend rest $o $v
        }
    }
    if {[llength $rest]} { $state($path,control) configure {*}$rest }
    return $path
}

package provide tkutils::tkulabeled 0.1
