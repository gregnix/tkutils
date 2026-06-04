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
package require tkutils::tktodo
package require tclutils::tuical

wm title . "tktodo demo"
set w [::tkutils::tktodo::widget .t -onchange {apply {{p} {
    set open 0
    foreach c [::tkutils::tktodo::todos $p] {
        if {![string equal -nocase [::tclutils::tuical::property $c STATUS] COMPLETED]} { incr open }
    }
    .status configure -text "Open tasks: $open"
}}}]
pack $w -fill both -expand 1 -padx 6 -pady 6
ttk::label .status -anchor w
pack .status -fill x -padx 8 -pady {0 6}

set ics "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"
foreach {uid sum prio due st pct} {
    1 {Write release notes}    1 20260115T000000Z NEEDS-ACTION 0
    2 {Review pull request}    2 20260112T000000Z NEEDS-ACTION 50
    3 {Tag v0.49.0}            3 {}               COMPLETED 100
    4 {Update handover doc}    2 20260114T000000Z NEEDS-ACTION 0
} {
    append ics "BEGIN:VTODO\r\nUID:$uid\r\nSUMMARY:$sum\r\nPRIORITY:$prio\r\nSTATUS:$st\r\nPERCENT-COMPLETE:$pct\r\n"
    if {$due ne ""} { append ics "DUE:$due\r\n" }
    append ics "END:VTODO\r\n"
}
append ics "END:VCALENDAR\r\n"
::tkutils::tktodo::loadText .t $ics

if {![info exists ::env(DEMO_NOLOOP)]} { vwait forever }
