# tkutils::tkform -- declarative form widget
#
# Builds a labelled form from a field specification and collects the values as
# a dict. Field types: entry, password, check, combo, spin, text. Pure Tk.
# Tcl/Tk 8.6+ and 9.x compatible.
#
# A field spec is a list of field dicts, each with:
#   name   - key used in the values dict (required)
#   label  - text shown to the left (defaults to name)
#   type   - entry | password | check | combo | spin | text (default entry)
#   default- initial value (default "")
#   values - list of choices (combo)
#   from,to- numeric range (spin)
#   height - rows (text; default 4)

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkform {
    namespace export widget get set values setValues fieldNames widgetOf
    variable state
}

proc ::tkutils::tkform::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkform::_field {spec key {default ""}} {
    if {[dict exists $spec $key]} { return [dict get $spec $key] }
    return $default
}

# Build the form under $path from $fieldspec. Returns $path.
proc ::tkutils::tkform::widget {path fieldspec args} {
    variable state
    ::array set o {-padding 8}
    ::array set o $args

    ttk::frame $path -padding $o(-padding)
    ::set state($path,names) {}
    ::set state($path,fields) [dict create]
    bind $path <Destroy> [list ::tkutils::tkform::_cleanup $path %W]

    ::set row 0
    foreach spec $fieldspec {
        ::set name [dict get $spec name]
        ::set type [_field $spec type entry]
        ::set label [_field $spec label $name]
        ::set default [_field $spec default ""]
        lappend state($path,names) $name
        dict set state($path,fields) $name $spec

        ttk::label $path.l$row -text $label
        ::set ctl $path.f$row
        switch -- $type {
            check {
                ::set state($path,val,$name) $default
                ttk::checkbutton $ctl -variable ::tkutils::tkform::state($path,val,$name)
            }
            combo {
                ::set state($path,val,$name) $default
                ttk::combobox $ctl -textvariable ::tkutils::tkform::state($path,val,$name) \
                    -values [_field $spec values {}]
            }
            spin {
                ::set state($path,val,$name) $default
                ttk::spinbox $ctl -textvariable ::tkutils::tkform::state($path,val,$name) \
                    -from [_field $spec from 0] -to [_field $spec to 100]
            }
            text {
                text $ctl -height [_field $spec height 4] -width 30 -wrap word
                $ctl insert end $default
            }
            password {
                ::set state($path,val,$name) $default
                ttk::entry $ctl -show "*" \
                    -textvariable ::tkutils::tkform::state($path,val,$name)
            }
            default {
                ::set state($path,val,$name) $default
                ttk::entry $ctl \
                    -textvariable ::tkutils::tkform::state($path,val,$name)
            }
        }
        ::set state($path,ctl,$name) $ctl
        ::set sticky [expr {$type eq "text" ? "nsew" : "ew"}]
        ::set anchor [expr {$type eq "text" ? "nw" : "w"}]
        grid $path.l$row -row $row -column 0 -sticky $anchor -padx {0 8} -pady 3
        grid $ctl        -row $row -column 1 -sticky $sticky -pady 3
        if {$type eq "text"} { grid rowconfigure $path $row -weight 1 }
        incr row
    }
    grid columnconfigure $path 1 -weight 1
    return $path
}

proc ::tkutils::tkform::_ctl {path name} {
    variable state
    return $state($path,ctl,$name)
}

# Get one field's value.
proc ::tkutils::tkform::get {path name} {
    variable state
    ::set type [_field [dict get $state($path,fields) $name] type entry]
    if {$type eq "text"} {
        return [string trimright [[_ctl $path $name] get 1.0 end] "\n"]
    }
    return $state($path,val,$name)
}

# Set one field's value.
proc ::tkutils::tkform::set {path name value} {
    variable state
    ::set type [_field [dict get $state($path,fields) $name] type entry]
    if {$type eq "text"} {
        ::set c [_ctl $path $name]
        $c delete 1.0 end
        $c insert end $value
    } else {
        ::set state($path,val,$name) $value
    }
    return $value
}

# All field names in spec order.
proc ::tkutils::tkform::fieldNames {path} {
    variable state
    return $state($path,names)
}

# Return all values as a dict name -> value.
proc ::tkutils::tkform::values {path} {
    variable state
    ::set d [dict create]
    foreach name $state($path,names) { dict set d $name [get $path $name] }
    return $d
}

# Set several values from a dict (unknown keys are ignored).
proc ::tkutils::tkform::setValues {path dict} {
    variable state
    dict for {name value} $dict {
        if {$name in $state($path,names)} { set $path $name $value }
    }
    return
}

# Return the underlying control widget for a field (for custom tweaks).
proc ::tkutils::tkform::widgetOf {path name} {
    return [_ctl $path $name]
}

package provide tkutils::tkform 0.1
