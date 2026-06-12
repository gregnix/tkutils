# tkutils::tkukeynav -- keyboard focus navigation helpers
#
# Consistent Tab / Shift-Tab traversal plus Return-to-next-field form ergonomics,
# the way data-entry users expect. Pure Tk; works with both classic and ttk
# input widgets. Bindings are per widget and auto-released on <Destroy>.
#
#   tkukeynav::enable $entry -onreturn {save} -onescape {cancel}
#   tkukeynav::form   $formFrame -onsubmit {save}   ;# Return walks fields, last -> submit
#   tkukeynav::next $w ; tkukeynav::prev $w
#
# Error codes: {TKUTILS TKUKEYNAV <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkukeynav {
    namespace export enable disable form next prev
    variable state
    # widget classes treated as focusable form inputs
    variable inputClasses {
        Entry TEntry TCombobox Spinbox TSpinbox Text Listbox
        TCheckbutton Checkbutton TRadiobutton Radiobutton
    }
}

# --- focus movement --------------------------------------------------------

proc ::tkutils::tkukeynav::next {w} {
    set nxt [tk_focusNext $w]
    if {$nxt ne ""} { focus $nxt }
    return $nxt
}

proc ::tkutils::tkukeynav::prev {w} {
    set prv [tk_focusPrev $w]
    if {$prv ne ""} { focus $prv }
    return $prv
}

# --- per-widget enable / disable -------------------------------------------

# Install navigation on a single widget.
#   -onreturn cmd   run on <Return>     (else Return falls through)
#   -onescape cmd   run on <Escape>
#   -tab 0|1        bind Tab/Shift-Tab traversal (default 1)
proc ::tkutils::tkukeynav::enable {w args} {
    variable state
    if {![winfo exists $w]} {
        return -code error -errorcode {TKUTILS TKUKEYNAV NOWIDGET} \
            "no such widget '$w'"
    }
    array set opts {-onreturn {} -onescape {} -tab 1}
    foreach {o v} $args {
        if {![info exists opts($o)]} {
            return -code error -errorcode {TKUTILS TKUKEYNAV OPTION} \
                "unknown option '$o'"
        }
        set opts($o) $v
    }
    if {$opts(-tab)} {
        bind $w <Tab>       {+::tkutils::tkukeynav::next %W; break}
        bind $w <Shift-Tab> {+::tkutils::tkukeynav::prev %W; break}
    }
    if {$opts(-onreturn) ne ""} {
        bind $w <Return>   [list +::tkutils::tkukeynav::_run %W return $opts(-onreturn)]
        bind $w <KP_Enter> [list +::tkutils::tkukeynav::_run %W return $opts(-onreturn)]
    }
    if {$opts(-onescape) ne ""} {
        bind $w <Escape> [list +::tkutils::tkukeynav::_run %W escape $opts(-onescape)]
    }
    set state($w,enabled) 1
    bind $w <Destroy> +[list ::tkutils::tkukeynav::_cleanup $w %W]
    return $w
}

proc ::tkutils::tkukeynav::_run {w which cmd} {
    uplevel #0 $cmd
    return -code break
}

proc ::tkutils::tkukeynav::disable {w} {
    variable state
    foreach ev {<Tab> <Shift-Tab> <Return> <KP_Enter> <Escape>} {
        catch {bind $w $ev {}}
    }
    array unset state $w,*
    return
}

proc ::tkutils::tkukeynav::_cleanup {w eventW} {
    variable state
    if {$w ne $eventW} return
    array unset state $w,*
}

# --- form ergonomics -------------------------------------------------------

# Collect the focusable input descendants of $container in tab order.
proc ::tkutils::tkukeynav::_fields {container} {
    variable inputClasses
    set fields {}
    # walk the focus ring starting just after the container
    set start [tk_focusNext $container]
    set cur $start
    set guard 0
    while {$cur ne "" && [incr guard] < 1000} {
        if {[string equal $cur $container] || \
            [string match $container.* $cur]} {
            if {[winfo class $cur] in $inputClasses} { lappend fields $cur }
        }
        set cur [tk_focusNext $cur]
        if {$cur eq $start} break
    }
    return $fields
}

# Treat $container's inputs as a form: Return advances to the next field; on the
# last field it runs -onsubmit. Tab/Shift-Tab traversal is installed too.
#   -onsubmit cmd   run when Return is pressed on the last field
#   -wrap 0|1       wrap from last field back to first (default 0)
#   -onescape cmd   run on Escape in any field
proc ::tkutils::tkukeynav::form {container args} {
    if {![winfo exists $container]} {
        return -code error -errorcode {TKUTILS TKUKEYNAV NOWIDGET} \
            "no such widget '$container'"
    }
    array set opts {-onsubmit {} -wrap 0 -onescape {}}
    foreach {o v} $args {
        if {![info exists opts($o)]} {
            return -code error -errorcode {TKUTILS TKUKEYNAV OPTION} \
                "unknown option '$o'"
        }
        set opts($o) $v
    }
    set fields [_fields $container]
    set n [llength $fields]
    for {set i 0} {$i < $n} {incr i} {
        set f [lindex $fields $i]
        if {$i < $n - 1} {
            set ret [list ::tkutils::tkukeynav::next $f]
        } elseif {$opts(-wrap) && $n > 1} {
            set ret [list focus [lindex $fields 0]]
        } else {
            set ret $opts(-onsubmit)
        }
        enable $f -onreturn $ret -onescape $opts(-onescape)
    }
    return $fields
}

package provide tkutils::tkukeynav 0.1
