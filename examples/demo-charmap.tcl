#!/usr/bin/env wish
# ===========================================================================
# Demo / tool: charmap -- a codepage / Unicode character viewer. For a chosen
# range it lists each printable character together with its \uXXXX escape, the
# U+XXXX code point, decimal and hex. Useful to look up things like
# oe = \u00f6, ae = \u00e4, ue = \u00fc, sz = \u00df, euro = \u20ac.
# Characters are built from code points (format %c), never as source literals,
# so the file stays ASCII-clean. Belongs to tkutils.
#
#   wish demo-charmap.tcl
#   tclsh demo-charmap.tcl --selftest
#   tclsh demo-charmap.tcl --shot out.png
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]

package require Tk
package require tablelist
catch {package require tkutils::tkutlclip}

wm title . "charmap -- codepage / Unicode viewer"

# preset name -> list of {first last} code-point ranges
set ::presets [dict create \
    "ASCII (0x20-0x7E)"          {0x20 0x7E} \
    "Latin-1 (incl. oe ae ue ss)" {0xA0 0xFF} \
    "Basic Latin + Latin-1"       {0x20 0x7E 0xA0 0xFF} \
    "Currency (incl. euro)"       {0x20A0 0x20BF} \
    "Box drawing"                 {0x2500 0x257F} \
    "Arrows"                      {0x2190 0x21FF}]

frame .top
label .top.l -text "Range:"
ttk::combobox .top.cb -textvariable ::preset -state readonly -width 28 \
    -values [dict keys $::presets]
label .top.n -textvariable ::status
pack .top.l .top.cb .top.n -side left -padx 3
pack .top -fill x -pady 3

tablelist::tablelist .t \
    -columns {6 "Char" center  10 "\\u" left  10 "U+" left \
              7 "Dec" right  7 "Hex" right} \
    -stretch all -height 20 -stripebackground #f4f4f4 \
    -labelcommand tablelist::sortByColumn
.t columnconfigure 0 -font {Helvetica 16}
pack .t -fill both -expand 1
catch {::tkutils::tkutlclip::installBindings .t}

# A code point is shown if it is not a C0/C1 control or a known gap.
proc printable {cp} {
    if {$cp < 0x20} { return 0 }
    if {$cp >= 0x7F && $cp <= 0xA0} { return 0 }
    return 1
}

proc fillRanges {ranges} {
    .t delete 0 end
    set n 0
    foreach {first last} $ranges {
        set first [expr {$first}]
        set last  [expr {$last}]
        for {set cp $first} {$cp <= $last} {incr cp} {
            if {![printable $cp]} continue
            .t insert end [list \
                [format %c $cp] \
                [format {\u%04x} $cp] \
                [format {U+%04X} $cp] \
                $cp \
                [format %X $cp]]
            incr n
        }
    }
    set ::status "$n characters"
}

proc showPreset {} {
    fillRanges [dict get $::presets $::preset]
}
bind .top.cb <<ComboboxSelected>> showPreset

set ::preset "Basic Latin + Latin-1"
showPreset

set mode [lindex $argv 0]
if {$mode eq "--selftest"} {
    update idletasks
    # find the row for code point 0xF6 (oe) and report its \u + char
    for {set i 0} {$i < [.t size]} {incr i} {
        if {[lindex [.t get $i] 3] == 246} {
            puts "rows: [.t size]   cp246 row: [.t get $i]"
        }
    }
    set ::preset "Currency (incl. euro)"; showPreset
    puts "currency rows: [.t size]  first: [.t get 0]"
    exit 0
} elseif {$mode eq "--shot"} {
    wm geometry . 620x560
    update idletasks; update; after 400; update
    catch {exec import -window root [lindex $argv 1]}
    exit 0
}
