# tkutils::tkuvalidate -- inline validation feedback for input widgets
#
# Attach a validator to an entry/combo/spinbox: on focus-out (or on every key)
# the value is checked; invalid input gets a red foreground, the ttk `invalid`
# state, and a tkuballoon message explaining why; valid input clears all that.
# Validators are tclutils::tuvalidate predicate names (email/url/integer/...) or
# any command prefix returning a boolean. Pure Tk + tclutils. 8.6+ / 9.x.
#
#   tkuvalidate::attach .email email -message "Enter a valid e-mail"
#   tkuvalidate::attach .age  integer -message "Digits only" -when key
#   if {[tkuvalidate::allValid {.email .age}]} { save }
#
# Error codes: {TKUTILS TKUVALIDATE <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-
package require tkutils::tkuballoon

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuvalidate {
    namespace export attach check valid clear allValid
    variable state
    # tclutils::tuvalidate predicates that take only the value
    variable simplePreds {email url ipv4 port alpha alnum numeric integer}
}

proc ::tkutils::tkuvalidate::_require {w} {
    variable state
    if {![info exists state($w,validator)]} {
        return -code error -errorcode {TKUTILS TKUVALIDATE NOWIDGET} \
            "no validator attached to '$w'"
    }
}

# Resolve a validator spec to a command prefix (value appended at call time).
proc ::tkutils::tkuvalidate::_resolve {spec} {
    variable simplePreds
    if {[llength $spec] == 1 && [lindex $spec 0] in $simplePreds} {
        if {[catch {package require tclutils::tuvalidate}]} {
            return -code error -errorcode {TKUTILS TKUVALIDATE NOENGINE} \
                "tclutils::tuvalidate is required for predicate '$spec'"
        }
        return [list ::tclutils::tuvalidate::[lindex $spec 0]]
    }
    return $spec
}

# Attach a validator. $validator is a tuvalidate predicate name or a command
# prefix (the widget value is appended; result must be a boolean).
#   -message s     balloon text shown while invalid
#   -when m        focusout (default) | key | both
#   -allowempty b  empty value counts as valid and shows no mark (default 1)
#   -getcmd cmd    how to read the value (default: [$w get])
#   -onvalid cmd / -oninvalid cmd   run after each check
proc ::tkutils::tkuvalidate::attach {w validator args} {
    variable state
    if {![winfo exists $w]} {
        return -code error -errorcode {TKUTILS TKUVALIDATE NOWIDGET} \
            "no such widget '$w'"
    }
    array set opts {-message {} -when focusout -allowempty 1 -getcmd {} \
        -onvalid {} -oninvalid {}}
    foreach {o v} $args {
        if {![info exists opts($o)]} {
            return -code error -errorcode {TKUTILS TKUVALIDATE OPTION} \
                "unknown option '$o'"
        }
        set opts($o) $v
    }
    if {$opts(-when) ni {focusout key both}} {
        return -code error -errorcode {TKUTILS TKUVALIDATE WHEN} \
            "bad -when '$opts(-when)': must be focusout, key or both"
    }
    set cmd [_resolve $validator]

    set state($w,validator)  $cmd
    set state($w,message)    $opts(-message)
    set state($w,allowempty) $opts(-allowempty)
    set state($w,getcmd)     $opts(-getcmd)
    set state($w,onvalid)    $opts(-onvalid)
    set state($w,oninvalid)  $opts(-oninvalid)
    set state($w,valid)      1
    catch {set state($w,origfg) [$w cget -foreground]}

    if {$opts(-when) in {focusout both}} {
        bind $w <FocusOut> +[list ::tkutils::tkuvalidate::check $w]
    }
    if {$opts(-when) in {key both}} {
        bind $w <KeyRelease> +[list ::tkutils::tkuvalidate::check $w]
    }
    bind $w <Destroy> +[list ::tkutils::tkuvalidate::_cleanup $w %W]
    return $w
}

proc ::tkutils::tkuvalidate::_value {w} {
    variable state
    if {$state($w,getcmd) ne ""} {
        return [uplevel #0 $state($w,getcmd)]
    }
    if {[catch {$w get} v]} { set v "" }
    return $v
}

# Validate now; mark the widget; return 0/1.
proc ::tkutils::tkuvalidate::check {w} {
    variable state
    _require $w
    set value [_value $w]
    if {$state($w,allowempty) && $value eq ""} {
        _mark $w 1
        set state($w,valid) 1
        if {$state($w,onvalid) ne ""} { uplevel #0 $state($w,onvalid) }
        return 1
    }
    set ok 0
    catch {set ok [expr {[uplevel #0 [list {*}$state($w,validator) $value]] ? 1 : 0}]}
    _mark $w $ok
    set state($w,valid) $ok
    if {$ok} {
        if {$state($w,onvalid) ne ""} { uplevel #0 $state($w,onvalid) }
    } else {
        if {$state($w,oninvalid) ne ""} { uplevel #0 $state($w,oninvalid) }
    }
    return $ok
}

proc ::tkutils::tkuvalidate::_mark {w ok} {
    variable state
    if {$ok} {
        catch {$w state !invalid}
        if {[info exists state($w,origfg)]} {
            catch {$w configure -foreground $state($w,origfg)}
        }
        ::tkutils::tkuballoon::clear $w
    } else {
        catch {$w state invalid}
        catch {$w configure -foreground red}
        if {$state($w,message) ne ""} {
            ::tkutils::tkuballoon::add $w $state($w,message) -delay 200
        }
    }
}

proc ::tkutils::tkuvalidate::valid {w} {
    variable state
    _require $w
    return $state($w,valid)
}

# Detach and clear any marking.
proc ::tkutils::tkuvalidate::clear {w} {
    variable state
    if {![info exists state($w,validator)]} return
    _mark $w 1
    foreach ev {<FocusOut> <KeyRelease>} { catch {bind $w $ev {}} }
    array unset state $w,*
    return
}

proc ::tkutils::tkuvalidate::_cleanup {w eventW} {
    variable state
    if {$w ne $eventW} return
    array unset state $w,*
}

# Re-check every given widget; return 1 only if all are valid.
proc ::tkutils::tkuvalidate::allValid {widgets} {
    set all 1
    foreach w $widgets {
        if {![check $w]} { set all 0 }
    }
    return $all
}

package provide tkutils::tkuvalidate 0.1
