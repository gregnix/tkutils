#!/usr/bin/env tclsh
# demo-tkutest.tcl -- a small form that fills itself: tkutest types into the
# fields, answers the confirmation dialog and shows the result.
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
package require Tk
package require tkutils::tkutest
package require tkutils::tkudialog
wm title . "tkutest demo"

ttk::frame .f -padding 10
pack .f -fill both -expand 1
ttk::label .f.ln -text Name:
ttk::entry .f.name -width 30
ttk::label .f.la -text Art:
ttk::combobox .f.art -state readonly -values {Angebot Rechnung Gutschrift}
ttk::button .f.ok -text Speichern -command speichern
ttk::label .f.out -foreground #060
grid .f.ln .f.name -sticky w -pady 3
grid .f.la .f.art -sticky w -pady 3
grid .f.ok - -sticky e -pady 6
grid .f.out - -sticky w

proc speichern {} {
    set a [::tkutils::tkudialog::show .frage -title Speichern -message "[.f.name get] als [.f.art get] speichern?" \
        -buttons {{yes Speichern} {no Abbrechen}} -default yes]
    .f.out configure -text [expr {$a eq "yes" ? "gespeichert" : "nicht gespeichert"}]
}

after 500 {
    namespace eval ::demo { namespace import ::tkutils::tkutest::* }
    ::demo::type .f.name "Quarz KG, Kai 2"
    ::demo::select .f.art Rechnung
    after 400 {
        ::demo::answer -title Speichern -button yes
        ::demo::click .f.ok
    }
}
vwait forever
