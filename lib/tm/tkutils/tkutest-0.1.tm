# tkutils::tkutest -- drive a Tk user interface from a test, in-process
# Description: simulate typing, clicks, menus and answers to modal dialogs in tcltest
# Category: Tk · testing
#
# Test helpers that operate the real widgets of an application running in the
# same interpreter: keys and clicks are generated with `event generate`, so the
# widget bindings, validation and dialog code run as for a user. Modal dialogs
# (tkudialog, tk_messageBox-like dialogs, any toplevel that waits in vwait)
# are answered by a handler scheduled with `answer` BEFORE the action that
# opens them; the handler runs inside the dialog's own event loop.
#
#   wait script ?-timeout ms?               -> 1, or error TIMEOUT
#   waitWindow ?-title glob? ?-after list? ?-timeout ms? -> new toplevel path
#   toplevels                               -> mapped toplevels, oldest first
#   type w text                             -> key events per character
#   key w sequence                          -> one event, e.g. <Return> <Control-s>
#   clear w                                 -> select all + delete (entry, text)
#   click w ?-x x? ?-y y? ?-button n? ?-double 0|1?
#   select combo value                      -> set and <<ComboboxSelected>>
#   check w ?value?                         -> checkbutton to 0/1 (invoke if needed)
#   menuInvoke menu labelPath               -> invoke "File/Open…" in a menu tree
#   treeItem tree text ?-column c?          -> first item whose text/value matches
#   treeSelect tree text ?-column c?        -> select, focus and show that item
#   findButton top label                    -> ttk/tk button in top by -text or path tail
#   fill form fields                        -> type/select/check tkuform fields (names -> values)
#   answer ?-title glob? ?-fields dict? ?-button id? ?-script cmd? ?-timeout ms? -> token
#   answerFile ?-title glob? path           -> token: type path into a file dialog, Return
#   result token                            -> what the handler did; raises its error
#   pending                                 -> tokens not yet handled
#   visible w                               -> 1 if w lies completely inside its toplevel
#   guard ?-after ms?                       -> close modal dialogs nobody answers
#   unexpected                              -> {title text} of each closed one, then clears
#   unguard
#
# Without `guard` an unexpected modal dialog (an error message the test did
# not foresee) waits forever and the test hangs; with it the dialog is closed
# with Escape after -after ms (default 8000) and reported by `unexpected`.
#
# The names avoid Tk's own commands (button, menu), so the procs can be
# imported with `namespace import ::tkutils::tkutest::*`.
#
# Characters with a keysym in the active keyboard map are typed as KeyPress/
# KeyRelease; others (umlauts on a US map) are inserted at the insert cursor
# of the entry, the way an input method would. Errors: {TKUTILS TKUTEST <R>}.
# Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tkutils::tkuopts 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutest {
    namespace export wait waitWindow toplevels type key clear click select check \
        menuInvoke treeItem treeSelect findButton fill answer answerFile result pending \
        visible guard unguard unexpected
    variable state
    array set state {seq 0 seen {} time 100000}
    # characters typed with a named keysym
    variable keysyms {
        " " space "!" exclam "\"" quotedbl "#" numbersign "$" dollar "%" percent
        "&" ampersand "'" apostrophe "(" parenleft ")" parenright "*" asterisk
        "+" plus "," comma "-" minus "." period "/" slash ":" colon ";" semicolon
        "<" less "=" equal ">" greater "?" question "@" at "\[" bracketleft
        "\\" backslash "\]" bracketright "^" asciicircum "_" underscore
        "`" grave "\{" braceleft "|" bar "\}" braceright "~" asciitilde
    }
}

proc ::tkutils::tkutest::_error {kind msg} {
    return -code error -level 2 -errorcode [list TKUTILS TKUTEST $kind] $msg
}

proc ::tkutils::tkutest::wait {script args} {
    array set o {-timeout 5000}
    array set o [::tkutils::tkuopts::merge TKUTEST [array get o] $args]
    set ende [expr {[clock milliseconds] + $o(-timeout)}]
    while {1} {
        update
        if {[uplevel 1 [list expr $script]]} { return 1 }
        if {[clock milliseconds] > $ende} {
            _error TIMEOUT "not true after $o(-timeout) ms: $script"
        }
        after 10
    }
}

proc ::tkutils::tkutest::toplevels {} {
    set out {}
    foreach w [wm stackorder .] { lappend out $w }
    # stackorder lists only mapped windows; add mapped ones it may miss
    foreach w [winfo children .] {
        if {[winfo exists $w] && [winfo toplevel $w] eq $w && [winfo ismapped $w] && $w ni $out} {
            lappend out $w
        }
    }
    # posted menus, combobox lists and tooltips (override-redirect) are no
    # windows a test answers
    lmap w $out {
        set o 0
        catch {set o [wm overrideredirect $w]}
        if {$o} continue
        set w
    }
}

# a toplevel that is not in -after (the windows that existed before)
proc ::tkutils::tkutest::waitWindow {args} {
    array set o {-title * -after {} -timeout 5000}
    array set o [::tkutils::tkuopts::merge TKUTEST [array get o] $args]
    set found ""
    set ende [expr {[clock milliseconds] + $o(-timeout)}]
    while {$found eq ""} {
        update
        foreach w [toplevels] {
            if {$w eq "." || $w in $o(-after)} continue
            if {[string match $o(-title) [wm title $w]]} { set found $w; break }
        }
        if {$found eq ""} {
            if {[clock milliseconds] > $ende} {
                _error TIMEOUT "no window titled \"$o(-title)\" after $o(-timeout) ms"
            }
            after 10
        }
    }
    return $found
}

proc ::tkutils::tkutest::_focus {w} {
    focus -force $w
    update
}

proc ::tkutils::tkutest::type {w text} {
    variable keysyms
    # find the keys first: the probe takes the focus, and a FocusIn binding
    # of the target (select all, as in Tk's file dialog) must not run again
    # in the middle of the text
    set plan {}
    foreach c [split $text ""] {
        if {[string is alnum $c] && [scan $c %c] < 128} {
            set ks $c
        } elseif {[dict exists $keysyms $c]} {
            set ks [dict get $keysyms $c]
        } else {
            set ks ""
        }
        lappend plan $c [expr {$ks ne "" && [_keyOk $ks $c] ? $ks : ""}]
    }
    _focus $w
    foreach {c ks} $plan {
        if {$ks ne ""} {
            event generate $w <KeyPress> -keysym $ks -when tail
            event generate $w <KeyRelease> -keysym $ks -when tail
        } else {
            # no key for it on this keyboard map: insert like an input method
            $w insert insert $c
            event generate $w <<Modified>> -when tail
        }
        update
    }
    return
}

# does the keysym produce the character on this display? (cached per keysym)
proc ::tkutils::tkutest::_keyOk {ks c} {
    variable state
    if {[info exists state(key,$ks)]} { return $state(key,$ks) }
    set probe .__tkutest_probe
    catch {destroy $probe}
    entry $probe
    place $probe -x -100 -y -100
    update
    focus -force $probe
    update
    event generate $probe <KeyPress> -keysym $ks -when tail
    event generate $probe <KeyRelease> -keysym $ks -when tail
    update
    set ok [expr {[$probe get] eq $c}]
    destroy $probe
    update
    set state(key,$ks) $ok
    return $ok
}

proc ::tkutils::tkutest::key {w sequence} {
    _focus $w
    event generate $w $sequence -when tail
    update
    return
}

proc ::tkutils::tkutest::clear {w} {
    switch -- [winfo class $w] {
        Text { $w delete 1.0 end }
        default { $w delete 0 end }
    }
    update
    return
}

proc ::tkutils::tkutest::click {w args} {
    array set o {-x "" -y "" -button 1 -double 0}
    array set o [::tkutils::tkuopts::merge TKUTEST [array get o] $args]
    wait {[winfo ismapped $w]} -timeout 2000
    set x [expr {$o(-x) eq "" ? [winfo width $w] / 2 : $o(-x)}]
    set y [expr {$o(-y) eq "" ? [winfo height $w] / 2 : $o(-y)}]
    set b $o(-button)
    event generate $w <Enter> -x $x -y $y -when tail
    event generate $w <Motion> -x $x -y $y -when tail
    # a double click is two clicks close in time; Tk counts them itself.
    # Separate clicks lie 2 s apart on a clock of our own (event times are
    # 32-bit), so two calls never merge into a double click.
    variable state
    set t [incr state(time) 2000]
    foreach n [expr {$o(-double) ? {0 1} : {0}}] {
        event generate $w <ButtonPress-$b> -x $x -y $y -time [expr {$t + 40 * $n}] -when tail
        event generate $w <ButtonRelease-$b> -x $x -y $y -time [expr {$t + 40 * $n + 10}] -when tail
    }
    update
    return
}

proc ::tkutils::tkutest::select {combo value} {
    set vals [$combo cget -values]
    if {$value ni $vals} {
        _error VALUE "\"$value\" is not a choice of $combo (choices: [join $vals {, }])"
    }
    _focus $combo
    $combo current [lsearch -exact $vals $value]
    event generate $combo <<ComboboxSelected>> -when tail
    update
    return
}

proc ::tkutils::tkutest::check {w {value 1}} {
    set var [$w cget -variable]
    set on [expr {[catch {$w cget -onvalue} v] ? 1 : $v}]
    set cur [expr {[info exists ::$var] ? [set ::$var] : ""}]
    if {($cur eq $on) != ($value ? 1 : 0)} { click $w }
    return
}

# invoke an entry by its labels: "File/Open…"
proc ::tkutils::tkutest::menuInvoke {m path} {
    set labels [split $path /]
    foreach lab $labels {
        set idx ""
        set last [$m index end]
        if {$last ne "none"} {
            for {set i 0} {$i <= $last} {incr i} {
                if {[$m type $i] in {separator tearoff}} continue
                if {[$m entrycget $i -label] eq $lab} { set idx $i; break }
            }
        }
        if {$idx eq ""} { _error MENU "no entry \"$lab\" in $m" }
        if {[$m type $idx] eq "cascade"} {
            set m [$m entrycget $idx -menu]
        } else {
            $m invoke $idx
            update
            return
        }
    }
    _error MENU "\"$path\" ends in a cascade"
}

proc ::tkutils::tkutest::treeItem {tree text args} {
    array set o {-column ""}
    array set o [::tkutils::tkuopts::merge TKUTEST [array get o] $args]
    set todo [$tree children {}]
    while {[llength $todo]} {
        set todo [lassign $todo i]
        if {$o(-column) eq ""} {
            if {[$tree item $i -text] eq $text || $text in [$tree item $i -values]} { return $i }
        } elseif {[$tree set $i $o(-column)] eq $text} {
            return $i
        }
        lappend todo {*}[$tree children $i]
    }
    _error ITEM "no item \"$text\" in $tree"
}

proc ::tkutils::tkutest::treeSelect {tree text args} {
    set i [treeItem $tree $text {*}$args]
    $tree see $i
    $tree selection set $i
    $tree focus $i
    _focus $tree
    update
    return $i
}

# a button below top, found by its -text or by the tail of its path
proc ::tkutils::tkutest::findButton {top label} {
    set todo [list $top]
    while {[llength $todo]} {
        set todo [lassign $todo w]
        if {[winfo class $w] in {TButton Button}} {
            if {[$w cget -text] eq $label || [winfo name $w] eq $label} { return $w }
        }
        foreach c [winfo children $w] {
            if {[winfo toplevel $c] eq $top} { lappend todo $c }
        }
    }
    _error BUTTON "no button \"$label\" in $top"
}

# fill a tkuform: entries and text are cleared and typed, combos selected,
# checkbuttons set
proc ::tkutils::tkutest::fill {form fields} {
    package require tkutils::tkuform 0.1
    dict for {name value} $fields {
        set w [::tkutils::tkuform::widgetOf $form $name]
        switch -- [winfo class $w] {
            TCombobox {
                if {[$w cget -state] eq "readonly"} {
                    select $w $value
                } else {
                    clear $w
                    type $w $value
                }
            }
            TCheckbutton - Checkbutton { check $w $value }
            Text { clear $w; type $w $value }
            default { clear $w; type $w $value }
        }
    }
    return
}

# -- modal dialogs -----------------------------------------------------------------------

# Register a handler for the next new toplevel (matching -title). It fills
# -fields into the dialog's tkuform (if any), runs -script with the dialog
# path appended, then clicks -button (id or label; "" = do not click).
proc ::tkutils::tkutest::answer {args} {
    variable state
    array set o {-title * -fields {} -button ok -script {} -timeout 5000}
    array set o [::tkutils::tkuopts::merge TKUTEST [array get o] $args]
    set t [incr state(seq)]
    set state(job,$t) [array get o]
    set state(done,$t) 0
    set state(before,$t) [toplevels]
    set state(ende,$t) [expr {[clock milliseconds] + $o(-timeout)}]
    lappend state(queue) $t
    _schedule 10
    return $t
}

proc ::tkutils::tkutest::pending {} {
    variable state
    expr {[info exists state(queue)] ? $state(queue) : {}}
}

# one poll timer at a time; none while a handler runs (its own key and
# click commands process events, and a second poll would time the running
# dialog out)
proc ::tkutils::tkutest::_schedule {ms} {
    variable state
    if {[info exists state(timer)]} { after cancel $state(timer) }
    set state(timer) [after $ms ::tkutils::tkutest::_poll]
}

proc ::tkutils::tkutest::_poll {} {
    variable state
    unset -nocomplain state(timer)
    if {[info exists state(handling)]} return
    if {![info exists state(queue)] || ![llength $state(queue)]} return
    set t [lindex $state(queue) 0]
    array set o $state(job,$t)
    _prune
    set w ""
    foreach x [toplevels] {
        if {$x eq "." || $x in $state(before,$t) || [_seen $x]} continue
        if {[string match $o(-title) [wm title $x]]} { set w $x; break }
    }
    if {$w eq ""} {
        if {[clock milliseconds] > $state(ende,$t)} {
            _finish $t 1 "no dialog titled \"$o(-title)\" after $o(-timeout) ms" {TKUTILS TKUTEST TIMEOUT}
            _schedule 10
        } else {
            _schedule 20
        }
        return
    }
    _markSeen $w
    set state(handling) $t
    # handle it outside this after callback, once the dialog has settled
    after 30 [list ::tkutils::tkutest::_handle $t $w]
}

# Handled dialogs are remembered by path AND X window id: tkudialog reuses
# names (.tkudialog3 again after the old one is gone) and Tk keeps its file
# dialog withdrawn for the next call; both are new dialogs then.
proc ::tkutils::tkutest::_markSeen {w} {
    variable state
    lappend state(seen) [list $w [winfo id $w] [winfo ismapped $w]]
}

proc ::tkutils::tkutest::_seen {w} {
    variable state
    foreach s $state(seen) {
        lassign $s p id
        if {$p eq $w && [winfo exists $w] && [winfo id $w] eq $id} { return 1 }
    }
    return 0
}

# forget dialogs that are gone or were withdrawn after being handled
proc ::tkutils::tkutest::_prune {} {
    variable state
    set state(seen) [lmap s $state(seen) {
        lassign $s p id
        expr {[winfo exists $p] && [winfo id $p] eq $id && [winfo ismapped $p] ? $s : [continue]}
    }]
}

proc ::tkutils::tkutest::_handle {t w} {
    variable state
    array set o $state(job,$t)
    set rc [catch {
        update
        set r [dict create window $w title [wm title $w]]
        if {[dict size $o(-fields)]} {
            if {![winfo exists $w.form]} { _error FORM "$w has no form" }
            fill $w.form $o(-fields)
        }
        if {$o(-script) ne ""} { dict set r script [uplevel #0 [list {*}$o(-script) $w]] }
        if {$o(-button) ne ""} {
            set b [_dialogButton $w $o(-button)]
            dict set r button [$b cget -text]
            click $b
        }
        set r
    } msg opts]
    unset -nocomplain state(handling)
    _finish $t $rc $msg [expr {$rc ? [dict get $opts -errorcode] : ""}]
    _schedule 10
}

# button by dialog id (tkudialog: choose $win id), by label or path tail
proc ::tkutils::tkutest::_dialogButton {w id} {
    set todo [list $w]
    while {[llength $todo]} {
        set todo [lassign $todo x]
        if {[winfo class $x] in {TButton Button}} {
            set cmd [$x cget -command]
            if {[lindex $cmd end] eq $id && [string match *choose* [lindex $cmd 0]]} { return $x }
        }
        lappend todo {*}[winfo children $x]
    }
    findButton $w $id
}

proc ::tkutils::tkutest::_finish {t rc msg code} {
    variable state
    set state(queue) [lrange $state(queue) 1 end]
    set state(done,$t) 1
    set state(rc,$t) $rc
    set state(msg,$t) $msg
    set state(code,$t) $code
}

# what the handler did (window title button script); raises its error, or
# TIMEOUT if it has not run yet
proc ::tkutils::tkutest::result {t args} {
    variable state
    array set o {-timeout 2000}
    array set o [::tkutils::tkuopts::merge TKUTEST [array get o] $args]
    if {![info exists state(done,$t)]} { _error TOKEN "unknown token $t" }
    if {!$state(done,$t)} {
        catch {wait {$::tkutils::tkutest::state(done,$t)} -timeout $o(-timeout)}
    }
    if {!$state(done,$t)} { _error TIMEOUT "handler $t has not run" }
    if {$state(rc,$t)} {
        return -code error -errorcode $state(code,$t) $state(msg,$t)
    }
    return $state(msg,$t)
}

proc ::tkutils::tkutest::answerFile {args} {
    if {![llength $args]} { _error USAGE "answerFile ?-title glob? path" }
    set path [lindex $args end]
    array set o {-title * -timeout 5000}
    array set o [::tkutils::tkuopts::merge TKUTEST [array get o] [lrange $args 0 end-1]]
    answer -title $o(-title) -timeout $o(-timeout) -button "" \
        -script [list ::tkutils::tkutest::_typeFile $path]
}

# the file name entry of the dialog: clear, type the path, Return (Tk's file
# dialogs take Return as OK). Tk's own dialog names it .ent; it also has a
# hidden entry inside the icon list, so otherwise the widest entry wins.
proc ::tkutils::tkutest::_typeFile {path w} {
    set best ""
    set todo [list $w]
    while {[llength $todo]} {
        set todo [lassign $todo x]
        if {[winfo class $x] in {Entry TEntry} && [winfo ismapped $x]} {
            if {[winfo name $x] eq "ent"} { set best $x; break }
            if {$best eq "" || [winfo width $x] > [winfo width $best]} { set best $x }
        }
        lappend todo {*}[winfo children $x]
    }
    if {$best eq ""} { _error FORM "$w has no entry for the file name" }
    clear $best
    type $best $path
    key $best <Return>
    return $path
}

proc ::tkutils::tkutest::guard {args} {
    variable state
    array set o {-after 8000}
    array set o [::tkutils::tkuopts::merge TKUTEST [array get o] $args]
    set state(guard) $o(-after)
    if {![info exists state(unexpected)]} { set state(unexpected) {} }
    after 200 ::tkutils::tkutest::_guardTick
    return
}

proc ::tkutils::tkutest::unguard {} {
    variable state
    unset -nocomplain state(guard)
    after cancel ::tkutils::tkutest::_guardTick
    return
}

proc ::tkutils::tkutest::unexpected {} {
    variable state
    set r [expr {[info exists state(unexpected)] ? $state(unexpected) : {}}]
    set state(unexpected) {}
    return $r
}

proc ::tkutils::tkutest::_guardTick {} {
    variable state
    if {![info exists state(guard)]} return
    set g [grab current]
    if {$g ne "" && [winfo exists $g]} {
        set top [winfo toplevel $g]
        _prune
        set handled [expr {[_seen $top] && [llength [pending]]}]
        # combobox lists and menus (override-redirect) belong to the test's
        # own input and are no dialogs
        set popup 0
        catch {set popup [wm overrideredirect $top]}
        if {$top ne "." && !$handled && !$popup} {
            set now [clock milliseconds]
            if {![info exists state(since,$top)]} { set state(since,$top) $now }
            if {$now - $state(since,$top) > $state(guard)} {
                set text ""
                catch {set text [::tkutils::tkudialog::getText $top]}
                lappend state(unexpected) [list [wm title $top] $text]
                _markSeen $top
                catch {event generate $top <Escape>}
                after 300 [list apply {{w} { if {[winfo exists $w]} { catch {destroy $w} } }} $top]
                unset state(since,$top)
            }
        }
    }
    after 200 ::tkutils::tkutest::_guardTick
}

proc ::tkutils::tkutest::visible {w} {
    update
    if {![winfo ismapped $w]} { return 0 }
    set top [winfo toplevel $w]
    set x [expr {[winfo rootx $w] - [winfo rootx $top]}]
    set y [expr {[winfo rooty $w] - [winfo rooty $top]}]
    expr {$x >= 0 && $y >= 0 && $x + [winfo width $w] <= [winfo width $top]
        && $y + [winfo height $w] <= [winfo height $top]}
}

package provide tkutils::tkutest 0.1
