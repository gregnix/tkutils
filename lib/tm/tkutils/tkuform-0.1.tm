# tkutils::tkuform -- declarative form widget
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
#   state  - combo state: normal | readonly (combo; default normal)
#   from,to- numeric range (spin)
#   height - rows (text; default 4)
#
# Layout options (widget):
#   -padding P  - frame padding (default 8)
#   -columns N  - number of side-by-side field columns (default 1). Each column
#                 is a label+control pair; fields flow left-to-right, top-down.
#                 N=1 reproduces the original single-column layout exactly.
#                 text-type fields always take their own full-width row.
#
# Error codes: {TKUTILS TKUFORM <REASON>} (OPTION, VALUE, SPEC, TYPE, NOFIELD).

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuform {
    namespace export widget get setField values setValues fieldNames widgetOf
    variable state
    variable fieldTypes {entry password check combo spin text}
}

proc ::tkutils::tkuform::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkuform::_field {spec key {default ""}} {
    if {[dict exists $spec $key]} { return [dict get $spec $key] }
    return $default
}

proc ::tkutils::tkuform::_require {path name} {
    variable state
    if {![info exists state($path,ctl,$name)]} {
        return -code error -errorcode {TKUTILS TKUFORM NOFIELD} \
            "no field '$name' in form '$path'"
    }
}

# Build the form under $path from $fieldspec. Returns $path.
proc ::tkutils::tkuform::widget {path fieldspec args} {
    variable state
    variable fieldTypes
    array set o {-padding 8 -columns 1}
    foreach {opt val} $args {
        if {![info exists o($opt)]} {
            return -code error -errorcode {TKUTILS TKUFORM OPTION} \
                "unknown option '$opt'"
        }
        set o($opt) $val
    }
    if {![string is integer -strict $o(-columns)]} {
        return -code error -errorcode {TKUTILS TKUFORM VALUE} \
            "-columns needs an integer"
    }
    set cols [expr {$o(-columns) < 1 ? 1 : $o(-columns)}]

    # Validate the whole spec up front, so a bad field leaves nothing behind.
    foreach spec $fieldspec {
        if {![dict exists $spec name]} {
            return -code error -errorcode {TKUTILS TKUFORM SPEC} \
                "field spec missing 'name': $spec"
        }
        set t [_field $spec type entry]
        if {$t ni $fieldTypes} {
            return -code error -errorcode {TKUTILS TKUFORM TYPE} \
                "unknown field type '$t' for '[dict get $spec name]'"
        }
    }

    ttk::frame $path -padding $o(-padding)
    set state($path,names) {}
    set state($path,fields) [dict create]
    bind $path <Destroy> [list ::tkutils::tkuform::_cleanup $path %W]

    set row 0
    set gridRow 0
    set col 0
    foreach spec $fieldspec {
        set name [dict get $spec name]
        set type [_field $spec type entry]
        set label [_field $spec label $name]
        set default [_field $spec default ""]
        lappend state($path,names) $name
        dict set state($path,fields) $name $spec

        ttk::label $path.l$row -text $label
        set ctl $path.f$row
        switch -- $type {
            check {
                set state($path,val,$name) $default
                ttk::checkbutton $ctl -variable ::tkutils::tkuform::state($path,val,$name)
            }
            combo {
                set state($path,val,$name) $default
                ttk::combobox $ctl -textvariable ::tkutils::tkuform::state($path,val,$name) \
                    -values [_field $spec values {}] \
                    -state [_field $spec state normal]
            }
            spin {
                set state($path,val,$name) $default
                ttk::spinbox $ctl -textvariable ::tkutils::tkuform::state($path,val,$name) \
                    -from [_field $spec from 0] -to [_field $spec to 100]
            }
            text {
                text $ctl -height [_field $spec height 4] -width 30 -wrap word
                $ctl insert end $default
            }
            password {
                set state($path,val,$name) $default
                ttk::entry $ctl -show "*" \
                    -textvariable ::tkutils::tkuform::state($path,val,$name)
            }
            default {
                set state($path,val,$name) $default
                ttk::entry $ctl \
                    -textvariable ::tkutils::tkuform::state($path,val,$name)
            }
        }
        set state($path,ctl,$name) $ctl
        set sticky [expr {$type eq "text" ? "nsew" : "ew"}]
        set anchor [expr {$type eq "text" ? "nw" : "w"}]
        # Layout: full-width row for text (or single-column mode), otherwise
        # flow into N label+control column pairs.
        if {$cols == 1 || $type eq "text"} {
            if {$col > 0} { incr gridRow; set col 0 }
            set span [expr {$cols == 1 ? 1 : ($cols * 2 - 1)}]
            grid $path.l$row -row $gridRow -column 0 -sticky $anchor -padx {0 8} -pady 3
            grid $ctl -row $gridRow -column 1 -columnspan $span -sticky $sticky -pady 3
            if {$type eq "text"} { grid rowconfigure $path $gridRow -weight 1 }
            incr gridRow
        } else {
            grid $path.l$row -row $gridRow -column [expr {$col * 2}] \
                -sticky $anchor -padx {0 8} -pady 3
            grid $ctl -row $gridRow -column [expr {$col * 2 + 1}] \
                -sticky $sticky -padx {0 12} -pady 3
            incr col
            if {$col == $cols} { set col 0; incr gridRow }
        }
        incr row
    }
    if {$cols == 1} {
        grid columnconfigure $path 1 -weight 1
    } else {
        for {set p 0} {$p < $cols} {incr p} {
            grid columnconfigure $path [expr {$p * 2 + 1}] -weight 1
        }
    }
    return $path
}

proc ::tkutils::tkuform::_ctl {path name} {
    variable state
    return $state($path,ctl,$name)
}

# Get one field's value.
proc ::tkutils::tkuform::get {path name} {
    variable state
    _require $path $name
    set type [_field [dict get $state($path,fields) $name] type entry]
    if {$type eq "text"} {
        return [string trimright [[_ctl $path $name] get 1.0 end] "\n"]
    }
    return $state($path,val,$name)
}

# Set one field's value. (Named setField, not set, to avoid shadowing the
# Tcl `set` builtin -- project rule: no builtin names as proc names.)
proc ::tkutils::tkuform::setField {path name value} {
    variable state
    _require $path $name
    set type [_field [dict get $state($path,fields) $name] type entry]
    if {$type eq "text"} {
        set c [_ctl $path $name]
        $c delete 1.0 end
        $c insert end $value
    } else {
        set state($path,val,$name) $value
    }
    return $value
}

# All field names in spec order.
proc ::tkutils::tkuform::fieldNames {path} {
    variable state
    return $state($path,names)
}

# Return all values as a dict name -> value.
proc ::tkutils::tkuform::values {path} {
    variable state
    set d [dict create]
    foreach name $state($path,names) { dict set d $name [get $path $name] }
    return $d
}

# Set several values from a dict (unknown keys are ignored).
proc ::tkutils::tkuform::setValues {path dict} {
    variable state
    dict for {name value} $dict {
        if {$name in $state($path,names)} { setField $path $name $value }
    }
    return
}

# Return the underlying control widget for a field (for custom tweaks).
proc ::tkutils::tkuform::widgetOf {path name} {
    _require $path $name
    return [_ctl $path $name]
}

package provide tkutils::tkuform 0.1
