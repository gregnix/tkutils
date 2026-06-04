# Usage: tclsh demo-tkudavbrowser.tcl ?url user password?
# With no arguments it renders sample collections offline (no network).
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
package require tkutils::tkudavbrowser
package require tclutils::tudav

wm title . "tkudavbrowser demo"
set editable [expr {[llength $argv] >= 3}]
set b [::tkutils::tkudavbrowser::widget .b -editable $editable -oncollection {apply {{w info} {
    .status configure -text "[dict get $info kind]: [dict get $info displayname]  ([dict get $info href])"
}}}]
pack $b -fill both -expand 1 -padx 6 -pady 6
ttk::label .status -anchor w -text "Select a collection..."
pack .status -fill x -padx 8 -pady {0 6}

if {[llength $argv] >= 3} {
    lassign $argv url user pass
    set c [::tclutils::tudav::client $url -user $user -password $pass]
    ::tkutils::tkudavbrowser::setClient .b $c
    ::tkutils::tkudavbrowser::refresh .b
} else {
    ::tkutils::tkudavbrowser::setData .b {
        {href /u/personal/ displayname Personal kind calendar}
        {href /u/work/     displayname Work     kind calendar}
        {href /u/family/   displayname Family   kind addressbook}
    }
}
if {![info exists ::env(DEMO_NOLOOP)]} { vwait forever }
