# tkutils::tkusysinfo -- show operating system and hardware information.
# Description: view of tclutils::tusysinfo (OS, CPU, memory, model, disks, monitors) plus Tk's screen data
# Category: Tk · widgets
# A tree of the sections that tclutils::tusysinfo collects, with a "screen"
# section from Tk itself (size in pixels and mm, scaling, colour depth,
# windowing system). Buttons: Refresh, Copy (text report), Save (text or
# JSON). Tk only (ttk::treeview), no Tablelist.
#
# API:
#   tkutils::tkusysinfo::widget  path ?options?   -> path
#   tkutils::tkusysinfo::refresh path             -> info dict
#   tkutils::tkusysinfo::data    path             -> last info dict
#   tkutils::tkusysinfo::report  path ?-anonymize 0|1?   -> text report
#   tkutils::tkusysinfo::json    path             -> JSON
#   tkutils::tkusysinfo::save    path file ?-format text|json? ?-anonymize 0|1?
#   tkutils::tkusysinfo::screen  win              -> dict (Tk screen data)
#
# Options: -sections (tusysinfo sections, default all), -serials 0|1,
#          -timeout ms, -autoload 0|1 (collect at once, default 1),
#          -height rows (default 16), -buttons 0|1 (default 1).
#
# Tcl/Tk 8.6-
package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tusysinfo 0.1
package require tkutils::tkuopts 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkusysinfo {
    namespace export widget refresh data report json save screen
    variable state
    variable labels {
        platform Platform host Host
        os Operating\ system cpu CPU memory Memory machine Computer
        disks Disks displays Monitors screen Screen
        name Name id Id version Version build Build kernel Kernel arch Architecture
        model Model logical {Logical CPUs} cores Cores total Total
        vendor Vendor boardVendor {Board vendor} board Board bios BIOS
        biosDate {BIOS date} chip Chip memoryText {Memory (system)} serial Serial
        size Size type Type removable Removable mount {Mounted on}
        connector Connector manufacturer Manufacturer productCode {Product code}
        year Year week Week widthCm {Width (cm)} heightCm {Height (cm)}
        diagonal {Diagonal (in)} preferred {Preferred mode} valid {EDID checksum ok}
        serialText {Serial (text)} present Connected pixels Pixels millimeters Millimeters
        scaling {Tk scaling} dpi DPI depth {Colour depth} windowing {Windowing system}
    }
}

proc ::tkutils::tkusysinfo::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkusysinfo::widget {path args} {
    variable state
    array set o {-sections {} -serials 0 -timeout 10000 -autoload 1 -height 16 -buttons 1}
    array set o [::tkutils::tkuopts::merge TKUSYSINFO [array get o] $args]
    set state($path,opts) [array get o]
    set state($path,info) {}

    ttk::frame $path
    bind $path <Destroy> [list ::tkutils::tkusysinfo::_cleanup $path %W]
    if {$o(-buttons)} {
        ttk::frame $path.bar
        ttk::button $path.bar.refresh -text Refresh \
            -command [list ::tkutils::tkusysinfo::refresh $path]
        ttk::button $path.bar.copy -text Copy \
            -command [list ::tkutils::tkusysinfo::_copy $path]
        ttk::button $path.bar.save -text Save... \
            -command [list ::tkutils::tkusysinfo::_saveDialog $path]
        ttk::label $path.bar.status
        pack $path.bar.refresh $path.bar.copy $path.bar.save -side left -padx 2 -pady 2
        pack $path.bar.status -side left -padx 8
        grid $path.bar - -sticky ew
    }
    ttk::treeview $path.tv -columns {value} -show {tree headings} -height $o(-height)
    $path.tv heading #0 -text Item
    $path.tv heading value -text Value
    $path.tv column #0 -width 200 -anchor w
    $path.tv column value -width 380 -anchor w
    ttk::scrollbar $path.ys -orient vertical -command [list $path.tv yview]
    $path.tv configure -yscrollcommand [list $path.ys set]
    grid $path.tv $path.ys -sticky nsew
    grid rowconfigure $path [expr {$o(-buttons) ? 1 : 0}] -weight 1
    grid columnconfigure $path 0 -weight 1
    if {$o(-autoload)} { refresh $path }
    return $path
}

# Tk's view of the screen of a window.
proc ::tkutils::tkusysinfo::screen {win} {
    set wpx [winfo screenwidth $win]
    set hpx [winfo screenheight $win]
    set wmm [winfo screenmmwidth $win]
    set hmm [winfo screenmmheight $win]
    set dpi [expr {$wmm > 0 ? round($wpx * 25.4 / $wmm) : 0}]
    return [dict create pixels "${wpx}x$hpx" millimeters "${wmm}x$hmm" dpi $dpi \
        scaling [format %.3f [tk scaling -displayof $win]] \
        depth [winfo screendepth $win] windowing [tk windowingsystem]]
}

proc ::tkutils::tkusysinfo::refresh {path} {
    variable state
    set o $state($path,opts)
    set args [list -serials [dict get $o -serials] -timeout [dict get $o -timeout]]
    if {[llength [dict get $o -sections]]} { lappend args -sections [dict get $o -sections] }
    if {[winfo exists $path.bar.status]} {
        $path.bar.status configure -text "collecting..."
        update idletasks
    }
    set cursor [$path cget -cursor]
    $path configure -cursor watch
    try {
        set info [::tclutils::tusysinfo::collect {*}$args]
    } finally {
        if {[winfo exists $path]} { $path configure -cursor $cursor }
    }
    if {![winfo exists $path]} { return $info }
    dict set info screen [screen $path]
    set state($path,info) $info
    _fill $path
    if {[winfo exists $path.bar.status]} { $path.bar.status configure -text "" }
    return $info
}

proc ::tkutils::tkusysinfo::data {path} {
    variable state
    return $state($path,info)
}

proc ::tkutils::tkusysinfo::_label {key} {
    variable labels
    if {[dict exists $labels $key]} { return [dict get $labels $key] }
    return $key
}

proc ::tkutils::tkusysinfo::_value {key v} {
    if {$key in {total size} && [string is double -strict $v] && $v > 0} {
        # memory in binary units, disks in decimal units (as on the label)
        set units [expr {$key eq "total" ? {GiB 1073741824 MiB 1048576}
                                         : {TB 1e12 GB 1e9 MB 1e6}}]
        foreach {u f} $units {
            if {$v >= $f} { return "[format %.1f [expr {double($v) / $f}]] $u" }
        }
    }
    if {$key in {present removable valid}} {
        return [expr {$v eq "1" ? "yes" : $v eq "0" ? "no" : $v}]
    }
    if {$key eq "preferred" && $v ne ""} {
        set s "[dict get $v width]x[dict get $v height]"
        if {[dict get $v refresh] > 0} { append s " @ [dict get $v refresh] Hz" }
        return $s
    }
    return $v
}

proc ::tkutils::tkusysinfo::_fill {path} {
    variable state
    set tv $path.tv
    $tv delete [$tv children {}]
    set info $state($path,info)
    foreach k {platform host} {
        if {[dict exists $info $k] && [dict get $info $k] ne ""} {
            $tv insert {} end -text [_label $k] -values [list [dict get $info $k]]
        }
    }
    foreach sec {os cpu memory machine screen} {
        if {![dict exists $info $sec]} continue
        set node [$tv insert {} end -text [_label $sec] -open 1]
        foreach {k v} [dict get $info $sec] {
            if {$v eq "" || ($v eq "0" && $k ni {removable valid})} continue
            $tv insert $node end -text [_label $k] -values [list [_value $k $v]]
        }
    }
    foreach sec {disks displays} {
        if {![dict exists $info $sec]} continue
        set items [dict get $info $sec]
        set node [$tv insert {} end -text "[_label $sec] ([llength $items])" -open 1]
        foreach item $items {
            set title [expr {$sec eq "disks"
                ? [string trim "[dict get $item name] [dict get $item model]"]
                : [string trim "[dict get $item connector] [dict get $item vendor] [dict get $item name]"]}]
            if {[dict exists $item present] && [dict get $item present] eq "0"} {
                append title " (not connected)"
            }
            set sub [$tv insert $node end -text $title -open 0]
            foreach {k v} $item {
                if {$v eq ""} continue
                $tv insert $sub end -text [_label $k] -values [list [_value $k $v]]
            }
        }
    }
}

# Text report: tusysinfo's report plus the screen section.
proc ::tkutils::tkusysinfo::report {path args} {
    variable state
    array set o {-anonymize 0}
    array set o [::tkutils::tkuopts::merge TKUSYSINFO [array get o] $args]
    set info $state($path,info)
    set r [::tclutils::tusysinfo::report $info -anonymize $o(-anonymize)]
    if {[dict exists $info screen]} {
        append r \n\n "--- Screen (Tk) ---"
        foreach {k v} [dict get $info screen] { append r \n "[_label $k]: $v" }
    }
    return $r
}

proc ::tkutils::tkusysinfo::json {path} {
    variable state
    return [::tclutils::tusysinfo::toJson $state($path,info)]
}

proc ::tkutils::tkusysinfo::save {path file args} {
    array set o {-format text -anonymize 0}
    array set o [::tkutils::tkuopts::merge TKUSYSINFO [array get o] $args]
    switch -- $o(-format) {
        text    { set data [report $path -anonymize $o(-anonymize)] }
        json    { set data [json $path] }
        default {
            return -code error -errorcode {TKUTILS TKUSYSINFO FORMAT} \
                "bad format \"$o(-format)\": must be text or json"
        }
    }
    set fh [open $file w]
    try {
        fconfigure $fh -encoding utf-8
        puts $fh $data
    } finally {
        close $fh
    }
    return $file
}

proc ::tkutils::tkusysinfo::_copy {path} {
    clipboard clear -displayof $path
    clipboard append -displayof $path [report $path]
    if {[winfo exists $path.bar.status]} { $path.bar.status configure -text "copied" }
}

proc ::tkutils::tkusysinfo::_saveDialog {path} {
    set f [tk_getSaveFile -parent $path -initialfile sysinfo.txt \
        -filetypes {{Text .txt} {JSON .json}}]
    if {$f eq ""} return
    set fmt [expr {[string tolower [file extension $f]] eq ".json" ? "json" : "text"}]
    save $path $f -format $fmt
}

package provide tkutils::tkusysinfo 0.1
