#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require Tk
# tkufilelist fills from a tclutils storage provider; make sure it is reachable.
if {[catch {package require tclutils::tuprovider}]} {
    tk_messageBox -icon error -title "tkufilelist demo" -message \
        "This demo needs tclutils::tuprovider on the tm path.\nAdd the tclutils lib/tm directory (TCLUTILS_TM or tcl::tm::path)."
    exit 1
}
package require tkutils::tkufilelist

wm title . "tkufilelist demo"
wm geometry . 620x460

set start [expr {$argc ? [lindex $argv 0] : [pwd]}]

ttk::label .info -text "Double-click a directory to enter it. Type in Filter to narrow files." -anchor w
set ::sel ""
ttk::label .sel -textvariable ::sel -anchor w -foreground "#1565c0"

# a simple filter box wired to setFilter
ttk::frame .f
ttk::label .f.l -text "Filter:"
ttk::entry .f.e
pack .f.l -side left -padx {0 4}
pack .f.e -side left -fill x -expand 1
bind .f.e <KeyRelease> {
    set g [string trim [.f.e get]]
    ::tkutils::tkufilelist::setFilter .list [expr {$g eq "" ? "" : "*$g*"}]
}

::tkutils::tkufilelist::widget .list -dir $start \
    -onselect   {apply {e {set ::sel "selected: [dict get $e name] ([dict get $e type])"}}} \
    -onactivate {apply {e {
        if {[dict get $e type] eq "dir"} {
            ::tkutils::tkufilelist::setDir .list [dict get $e path]
            .f.e delete 0 end
            ::tkutils::tkufilelist::setFilter .list ""
        }
    }}}

grid .info -sticky ew  -padx 8 -pady {8 0}
grid .f    -sticky ew  -padx 8 -pady 4
grid .list -sticky nsew -padx 8 -pady 4
grid .sel  -sticky ew  -padx 8 -pady {0 8}
grid columnconfigure . 0 -weight 1
grid rowconfigure . 2 -weight 1
