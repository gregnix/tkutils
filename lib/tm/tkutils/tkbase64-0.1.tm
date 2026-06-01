# tkutils::tkbase64 -- Base64 encode/decode panel
#
# Tk front-end on top of the tclutils Base64 engine (tubase64). An input area, an
# output area, and Encode/Decode buttons. Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tubase64 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkbase64 {
    namespace export widget setInput getInput getOutput encode decode
    variable state
}

proc ::tkutils::tkbase64::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the panel under $path. Options: -width N -height N.
proc ::tkutils::tkbase64::widget {path args} {
    variable state
    array set opts {-width 50 -height 6}
    array set opts $args

    ttk::frame $path
    bind $path <Destroy> [list ::tkutils::tkbase64::_cleanup $path %W]

    ttk::label $path.li -text "Input"
    text $path.in -width $opts(-width) -height $opts(-height) -wrap char \
        -yscrollcommand [list $path.iys set]
    ttk::scrollbar $path.iys -orient vertical -command [list $path.in yview]

    ttk::frame $path.btns
    ttk::button $path.btns.enc -text "Encode \u2193" \
        -command [list ::tkutils::tkbase64::encode $path]
    ttk::button $path.btns.dec -text "Decode \u2193" \
        -command [list ::tkutils::tkbase64::decode $path]
    pack $path.btns.enc $path.btns.dec -side left -padx 4

    ttk::label $path.lo -text "Output"
    text $path.out -width $opts(-width) -height $opts(-height) -wrap char \
        -yscrollcommand [list $path.oys set]
    ttk::scrollbar $path.oys -orient vertical -command [list $path.out yview]
    $path.out configure -state disabled

    grid $path.li   -            -sticky w
    grid $path.in   $path.iys    -sticky nsew
    grid $path.btns -            -pady 4
    grid $path.lo   -            -sticky w
    grid $path.out  $path.oys    -sticky nsew
    grid rowconfigure $path 1 -weight 1
    grid rowconfigure $path 4 -weight 1
    grid columnconfigure $path 0 -weight 1
    return $path
}

proc ::tkutils::tkbase64::setInput {path text} {
    $path.in delete 1.0 end
    $path.in insert end $text
    return [string length $text]
}

proc ::tkutils::tkbase64::getInput {path} {
    return [$path.in get 1.0 end-1c]
}

proc ::tkutils::tkbase64::getOutput {path} {
    return [$path.out get 1.0 end-1c]
}

proc ::tkutils::tkbase64::_setOutput {path text} {
    $path.out configure -state normal
    $path.out delete 1.0 end
    $path.out insert end $text
    $path.out configure -state disabled
}

# Encode the input to Base64. Returns the output.
proc ::tkutils::tkbase64::encode {path} {
    set out [::tclutils::tubase64::encode [getInput $path]]
    _setOutput $path $out
    return $out
}

# Decode the input from Base64. Returns the output (or an error note).
proc ::tkutils::tkbase64::decode {path} {
    if {[catch {::tclutils::tubase64::decode [getInput $path]} out]} {
        set out "(decode error: $out)"
    }
    _setOutput $path $out
    return $out
}

package provide tkutils::tkbase64 0.1
