# tkutils::tkuunits -- screen distances in px, pt, mm, cm and inch
# Description: convert screen distances between px, pt, mm, cm and inch
# Category: Tk · widgets
#
# Tk knows the units itself (winfo fpixels "2c", "10m", "1i", "12p"), but
# turning pixels back into millimetres, or one unit into another, is left to
# the caller. Needed for label and print previews: a 62 mm label on screen,
# a 0.5 pt rule, a margin in inches.
#
# All conversions go through the screen resolution of a window (default "."),
# so they follow [tk scaling]. pt is the printer's point, 1/72 inch, as in Tk.
#
# Public API:
#   ::tkutils::tkuunits::units                            ;# px pt mm cm inch
#   ::tkutils::tkuunits::toPixels value unit ?window?     ;# -> float px
#   ::tkutils::tkuunits::fromPixels px ?window?           ;# -> dict px pt mm cm inch
#   ::tkutils::tkuunits::convert value from to ?window?   ;# -> float
#
# Units: px pt mm cm inch; also the Tk letters p m c i and "in".
# Error codes: {TKUTILS TKUUNITS <REASON>} with REASON in {UNIT VALUE WINDOW}.
#
# Pure Tk. Tcl/Tk 8.6+ / 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuunits {
    namespace export units toPixels fromPixels convert
    variable version 0.1
    # unit name -> Tk distance suffix
    variable suffix {px "" pt p mm m cm c inch i}
    variable alias  {p pt m mm c cm i inch in inch}
}

proc ::tkutils::tkuunits::units {} {
    variable suffix
    return [dict keys $suffix]
}

proc ::tkutils::tkuunits::_unit {unit} {
    variable suffix
    variable alias
    if {[dict exists $alias $unit]} { set unit [dict get $alias $unit] }
    if {![dict exists $suffix $unit]} {
        return -code error -errorcode {TKUTILS TKUUNITS UNIT} \
            "unknown unit \"$unit\": must be [join [dict keys $suffix] {, }]"
    }
    return $unit
}

proc ::tkutils::tkuunits::_value {value} {
    if {![string is double -strict $value]} {
        return -code error -errorcode {TKUTILS TKUUNITS VALUE} \
            "expected a number but got \"$value\""
    }
}

proc ::tkutils::tkuunits::_window {w} {
    if {![winfo exists $w]} {
        return -code error -errorcode {TKUTILS TKUUNITS WINDOW} \
            "bad window path name \"$w\""
    }
}

# VALUE in UNIT as (fractional) pixels on WINDOW's screen.
proc ::tkutils::tkuunits::toPixels {value unit {w .}} {
    variable suffix
    _value $value
    _window $w
    set unit [_unit $unit]
    if {$unit eq "px"} { return [expr {double($value)}] }
    return [winfo fpixels $w "$value[dict get $suffix $unit]"]
}

# PX pixels in every unit, as a dict px pt mm cm inch.
proc ::tkutils::tkuunits::fromPixels {px {w .}} {
    _value $px
    _window $w
    set ppi [winfo fpixels $w 1i]
    set ppm [winfo fpixels $w 1m]
    dict create px [expr {double($px)}] pt [expr {$px * 72.0 / $ppi}] \
        mm [expr {$px / $ppm}] cm [expr {$px / ($ppm * 10.0)}] \
        inch [expr {$px / $ppi}]
}

# VALUE in unit FROM, expressed in unit TO.
proc ::tkutils::tkuunits::convert {value from to {w .}} {
    set to [_unit $to]
    dict get [fromPixels [toPixels $value $from $w] $w] $to
}

package provide tkutils::tkuunits 0.1
