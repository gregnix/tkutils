#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require Tk
package require tkutils::tkucalendar

# A clickable calendar. Click a day; the selection (ISO and formatted) is shown
# below. Use the arrows or Today to navigate.

wm title . "tkucalendar demo"
set ::picked "click a day"
::tkutils::tkucalendar::widget .cal -dateformat "%d.%m.%Y" \
    -command {apply {{iso} {
        set ::picked "selected: $iso   ([::tkutils::tkucalendar::getFormatted .cal])"
    }}}
ttk::label .info -textvariable ::picked -anchor w -foreground "#1565c0"

pack .cal -fill both -expand 1 -padx 6 -pady 6
pack .info -fill x -padx 6 -pady {0 6}
