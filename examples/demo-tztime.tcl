#!/usr/bin/env wish
# ===========================================================================
# Demo / tool: timezone viewer -- shows the current time, date, UTC offset and
# abbreviation for many time zones, updating once a second. Filter the list by
# typing (e.g. "Europe", "Tokyo"). A reference helper for Tk programmers using
# clock / -timezone. Belongs to tkutils.
#
#   wish demo-tztime.tcl
#   tclsh demo-tztime.tcl --selftest
#   tclsh demo-tztime.tcl --shot out.png
# ===========================================================================

package require Tk
package require tablelist

wm title . "Timezone viewer"

# Collect zone names cross-platform: Tcl's own tzdata (Windows / standard
# installs), the system zoneinfo (Linux / macOS), else a curated fallback.
proc zoneList {} {
    set zones {}
    set dirs {}
    lappend dirs [file join [info library] tzdata]
    foreach p $::tcl_pkgPath { lappend dirs [file join $p tzdata] }
    lappend dirs /usr/share/zoneinfo
    foreach base $dirs {
        if {![file isdirectory $base]} continue
        foreach f [glob -nocomplain -directory $base -tails -type f */* */*/*] {
            if {[regexp {^[A-Z][A-Za-z_]+/[A-Za-z0-9_+/-]+$} $f]} { lappend zones $f }
        }
        if {[llength $zones]} break
    }
    if {![llength $zones]} {
        set zones {UTC Europe/Berlin Europe/London Europe/Paris Europe/Moscow
            America/New_York America/Chicago America/Denver America/Los_Angeles
            America/Sao_Paulo Asia/Tokyo Asia/Shanghai Asia/Kolkata Asia/Dubai
            Australia/Sydney Pacific/Auckland Africa/Cairo Africa/Johannesburg}
    }
    return [lsort -unique $zones]
}
set ::zones [zoneList]

frame .top
label .top.l -text "Filter:"
entry .top.e -textvariable ::filter -width 22
label .top.n -textvariable ::status
pack .top.l .top.e .top.n -side left -padx 3
grid .top -row 0 -column 0 -columnspan 2 -sticky ew -pady 3

tablelist::tablelist .t \
    -columns {28 "Zone" left  8 "Time" right  12 "Date" center \
              7 "UTC" right  6 "Abbr" left} \
    -stretch all -height 22 -stripebackground #f4f4f4 \
    -labelcommand tablelist::sortByColumn \
    -yscrollcommand {.vsb set} -xscrollcommand {.hsb set}
ttk::scrollbar .vsb -orient vertical   -command {.t yview}
ttk::scrollbar .hsb -orient horizontal -command {.t xview}
grid .t   -row 1 -column 0 -sticky nsew
grid .vsb -row 1 -column 1 -sticky ns
grid .hsb -row 2 -column 0 -sticky ew
grid rowconfigure . 1 -weight 1
grid columnconfigure . 0 -weight 1

proc fillZones {} {
    .t delete 0 end
    foreach z $::zones {
        if {$::filter eq "" || [string match -nocase *$::filter* $z]} {
            .t insert end [list $z "" "" "" ""]
        }
    }
    set ::status "[.t size] zones"
    tick
}
proc tick {} {
    catch {after cancel $::tickId}
    set t [clock seconds]
    for {set i 0} {$i < [.t size]} {incr i} {
        set z [lindex [.t get $i] 0]
        if {[catch {clock format $t -timezone :$z -format {%H:%M:%S}} hms]} continue
        .t cellconfigure $i,1 -text $hms
        .t cellconfigure $i,2 -text [clock format $t -timezone :$z -format {%Y-%m-%d}]
        .t cellconfigure $i,3 -text [clock format $t -timezone :$z -format {%z}]
        .t cellconfigure $i,4 -text [clock format $t -timezone :$z -format {%Z}]
    }
    set ::tickId [after 1000 tick]
}
trace add variable ::filter write {apply {{a b c} {fillZones}}}
set ::filter ""
fillZones

set mode [lindex $argv 0]
if {$mode eq "--selftest"} {
    update idletasks
    puts "zones total: [llength $::zones]"
    set ::filter "Europe/Berlin"; update idletasks
    puts "Europe/Berlin row: [.t get 0]"
    exit 0
} elseif {$mode eq "--shot"} {
    set ::filter "Europe"; update idletasks
    wm geometry . 640x560
    update idletasks; update; after 400; update
    catch {exec import -window root [lindex $argv 1]}
    exit 0
}
