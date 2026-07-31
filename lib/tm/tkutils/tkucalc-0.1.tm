# tkutils::tkucalc -- a calculator widget.
#
# A small desktop calculator: a display plus a button grid, with keyboard
# support. Replaces ad-hoc global-variable calculator scripts with a reusable,
# namespaced tku*-style widget. Pure Tk + expr; nothing external. 8.6+ / 9.x.
#
# The arithmetic core is a separate, testable command:
#
#   ::tkutils::tkucalc::evaluate "2+3*4"     -> 14
#   ::tkutils::tkucalc::evaluate "10 / 4"    -> 2.5
#   ::tkutils::tkucalc::evaluate "2^10"      -> 1024   (^ is power)
#   ::tkutils::tkucalc::evaluate "3,5 + 1"   -> 4.5    (German decimal comma)
#
# It normalizes the on-screen math symbols and the German decimal comma, allows
# only a safe whitelist of characters, and evaluates in a SAFE interpreter, so a
# hand-typed expression can never run commands or touch the file system.
#
#   ::tkutils::tkucalc::widget .calc ?-onresult script?
#
# -onresult, if given, is appended the result string after each successful "="
# (for logging, or to feed the value elsewhere).

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkucalc {
    namespace export widget evaluate clear getHistory clearHistory
    variable state
}

# ---- arithmetic core (GUI-free, testable) ---------------------------------
# Turn a display expression into a number, or throw on a bad expression.
proc ::tkutils::tkucalc::evaluate {text} {
    # on-screen symbols and German comma -> plain ASCII operators
    set e [string map [list \u00d7 * \u00f7 / \u2212 - , .] $text]
    # only digits, operators, parens, decimal point, exponent letter, ^ and %
    if {![regexp {^[-+*/().0-9eE ^%]*$} $e]} {
        error "invalid characters in expression"
    }
    if {[string trim $e] eq ""} { error "empty expression" }
    # ^ means power
    set e [string map {^ **} $e]
    # force floating-point so 10/4 is 2.5, not integer-division 2: turn every
    # whole-number literal into x.0. Skip this when % (modulo) is present, since
    # modulo needs integer operands. Tcl's regexp has no lookbehind, so walk the
    # numbers by index and append .0 to those without a dot/exponent.
    if {[string first % $e] < 0} {
    set out "" ; set i 0
    foreach m [regexp -all -indices -inline {[0-9]+(?:\.[0-9]+)?(?:[eE][-+]?[0-9]+)?} $e] {
        lassign $m a b
        append out [string range $e $i [expr {$a-1}]]
        set num [string range $e $a $b]
        if {![string match {*[.eE]*} $num]} { append num .0 }
        append out $num
        set i [expr {$b+1}]
    }
    append out [string range $e $i end]
    set e $out
    }
    # evaluate in a safe interp: no exec/open/file, even if brackets slipped in
    set ip [interp create -safe]
    set rc [catch {$ip eval [list expr $e]} res]
    interp delete $ip
    if {$rc} { error $res }
    # floating-point division by zero yields Inf/NaN -- treat as an error
    if {$res in {Inf -Inf NaN}} { error "divide by zero" }
    # trim a trailing .0 for whole results (14.0 -> 14)
    if {[string match *.0 $res]} { set res [string range $res 0 end-2] }
    return $res
}

# ---- widget ---------------------------------------------------------------
proc ::tkutils::tkucalc::widget {path args} {
    variable state
    array set o {-onresult "" -history 0}
    array set o $args
    set state($path,onresult) $o(-onresult)
    set state($path,text) ""
    set state($path,history) {}
    set state($path,showhist) $o(-history)

    ttk::frame $path
    ttk::entry $path.display -textvariable ::tkutils::tkucalc::state($path,text) \
        -justify right -font {TkDefaultFont 14}
    grid $path.display -row 0 -column 0 -columnspan 4 -sticky ew -padx 4 -pady 4

    # button layout: {row col text}. "C" clears, "<" backspaces, "=" evaluates.
    set keys {
        1 0 C   1 1 (   1 2 )   1 3 \u00f7
        2 0 7   2 1 8   2 2 9   2 3 \u00d7
        3 0 4   3 1 5   3 2 6   3 3 \u2212
        4 0 1   4 1 2   4 2 3   4 3 +
        5 0 0   5 1 .   5 2 <   5 3 =
    }
    foreach {r c t} $keys {
        set b $path.b${r}_${c}
        # -takefocus 0 so clicking a button does not steal keyboard focus from
        # the display; _press also refocuses the display afterwards.
        ttk::button $b -text $t -width 4 -takefocus 0 \
            -command [list ::tkutils::tkucalc::_press $path $t]
        grid $b -row $r -column $c -sticky nsew -padx 2 -pady 2
    }
    for {set c 0} {$c < 4} {incr c} { grid columnconfigure $path $c -weight 1 -uniform k }
    for {set r 1} {$r <= 5} {incr r} { grid rowconfigure $path $r -weight 1 -uniform k }

    if {$o(-history)} { _buildHistory $path }

    _bindKeys $path
    bind $path <Destroy> [list ::tkutils::tkucalc::_cleanup $path %W]
    return $path
}

# A history panel: a labelled frame with a listbox of "expr = result" lines,
# a scrollbar, and a Clear button. Double-click (or Return) a line to load its
# result back into the display.
proc ::tkutils::tkucalc::_buildHistory {path} {
    set h $path.hist
    ttk::labelframe $h -text "History"
    listbox $h.list -height 6 -activestyle none \
        -yscrollcommand [list $h.sb set]
    ttk::scrollbar $h.sb -orient vertical -command [list $h.list yview]
    ttk::button $h.clear -text "Clear" -takefocus 0 \
        -command [list ::tkutils::tkucalc::clearHistory $path]
    grid $h.list  -row 0 -column 0 -sticky nsew
    grid $h.sb    -row 0 -column 1 -sticky ns
    grid $h.clear -row 1 -column 0 -columnspan 2 -sticky ew -pady {2 0}
    grid columnconfigure $h 0 -weight 1
    grid rowconfigure $h 0 -weight 1
    grid $h -row 6 -column 0 -columnspan 4 -sticky nsew -padx 4 -pady {4 4}
    grid rowconfigure $path 6 -weight 1
    bind $h.list <Double-1>    [list ::tkutils::tkucalc::_histReuse $path]
    bind $h.list <Key-Return>  [list ::tkutils::tkucalc::_histReuse $path]
}

# Handle a button press.
proc ::tkutils::tkucalc::_press {path key} {
    variable state
    switch -- $key {
        C { set state($path,text) "" }
        < { set state($path,text) [string range $state($path,text) 0 end-1] }
        = { _equals $path }
        default { append state($path,text) $key }
    }
    # keep the keyboard on the display after any button click
    catch {focus $path.display}
}

proc ::tkutils::tkucalc::_equals {path} {
    variable state
    set expr $state($path,text)
    if {[catch {evaluate $expr} res]} {
        set state($path,text) "Error"
        return
    }
    # record in history (newest last) and, if shown, in the listbox
    lappend state($path,history) "$expr = $res"
    if {$state($path,showhist) && [winfo exists $path.hist.list]} {
        $path.hist.list insert end "$expr = $res"
        $path.hist.list see end
    }
    set state($path,text) $res
    if {$state($path,onresult) ne ""} {
        uplevel #0 [list {*}$state($path,onresult) $res]
    }
}

# Load the result of the selected history line back into the display.
proc ::tkutils::tkucalc::_histReuse {path} {
    variable state
    set sel [$path.hist.list curselection]
    if {$sel eq ""} return
    set line [$path.hist.list get [lindex $sel 0]]
    # "expr = result" -> take the result after the last " = "
    set eq [string last " = " $line]
    if {$eq >= 0} { set state($path,text) [string range $line [expr {$eq+3}] end] }
    catch {focus $path.display}
}

# The recorded history as a list of "expr = result" strings.
proc ::tkutils::tkucalc::getHistory {path} {
    variable state
    return $state($path,history)
}

# Clear the history (and the panel, if shown).
proc ::tkutils::tkucalc::clearHistory {path} {
    variable state
    set state($path,history) {}
    if {[winfo exists $path.hist.list]} { $path.hist.list delete 0 end }
}

# clear the display programmatically
proc ::tkutils::tkucalc::clear {path} {
    variable state
    set state($path,text) ""
}

# Keyboard: the display entry accepts digits/operators/parentheses natively;
# here we add the actions that are not plain text -- Enter evaluates, Escape
# clears -- on both the widget and the display so they work with focus anywhere.
proc ::tkutils::tkucalc::_bindKeys {path} {
    foreach ev {<Key-Return> <Key-KP_Enter>} {
        bind $path $ev         [list ::tkutils::tkucalc::_press $path =]
        bind $path.display $ev [list ::tkutils::tkucalc::_press $path =]
    }
    bind $path <Key-Escape>         [list ::tkutils::tkucalc::_press $path C]
    bind $path.display <Key-Escape> [list ::tkutils::tkucalc::_press $path C]
    focus $path.display
}

proc ::tkutils::tkucalc::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    array unset state $path,*
}

package provide tkutils::tkucalc 0.1
