#!/usr/bin/env tclsh
# Showcases tkulabeled together with tkukeynav + tkuvalidate -- the three new
# form-ergonomics modules ported from bert ideas, in tkutils proc style.
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _r [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_r] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c; break
    }
}
package require tkutils::tkulabeled
package require tkutils::tkukeynav
catch {package require tkutils::tkuvalidate}
wm title . "tkulabeled + keynav + validate"

set form [ttk::frame .form -padding 10]
pack $form -fill both -expand 1

::tkutils::tkulabeled::add $form.name  entry -label "Name:"  -labelwidth 8
::tkutils::tkulabeled::add $form.email entry -label "Email:" -labelwidth 8
::tkutils::tkulabeled::add $form.age   spin  -label "Age:"   -labelwidth 8 -from 0 -to 120
::tkutils::tkulabeled::add $form.lang  combo -label "Lang:"  -labelwidth 8 -values {Tcl Tk C Python}
::tkutils::tkulabeled::add $form.vip   check -label "VIP customer" -variable ::vip
::tkutils::tkulabeled::add $form.notes text  -label "Notes:" -height 4 -width 30
pack $form.name $form.email $form.age $form.lang $form.vip $form.notes -fill x -pady 3

pack [ttk::label .out -padding 10 -anchor w -text "Fill the form, press Return to walk fields."] -fill x

# Inline validation on the inner controls (if tkuvalidate is available).
if {[namespace exists ::tkutils::tkuvalidate]} {
    ::tkutils::tkuvalidate::attach [::tkutils::tkulabeled::control $form.email] email \
        -message "Enter a valid e-mail address"
    ::tkutils::tkuvalidate::attach [::tkutils::tkulabeled::control $form.age] integer \
        -message "Digits only" -allowempty 0
}

# Return walks the entry/spin/combo fields; last -> submit.
::tkutils::tkukeynav::form $form -onsubmit {
    set ok 1
    if {[namespace exists ::tkutils::tkuvalidate]} {
        set ok [::tkutils::tkuvalidate::allValid [list \
            [::tkutils::tkulabeled::control .form.email] [::tkutils::tkulabeled::control .form.age]]]
    }
    if {$ok} {
        .out configure -text "Saved: [::tkutils::tkulabeled::value .form.name] / [::tkutils::tkulabeled::value .form.email] / age [::tkutils::tkulabeled::value .form.age] / [::tkutils::tkulabeled::value .form.lang] / VIP=$::vip"
    } else {
        .out configure -text "Please fix the highlighted fields."
    }
}

focus -force [::tkutils::tkulabeled::control $form.name]
vwait forever
