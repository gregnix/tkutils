# tkutils::tkhexedit -- small Tk hex viewer/editor
#
# Tk front-end built on top of the tclutils byte/hex engine
# (tubin, tuhexdump, common). tclutils is pure Tcl and pulls in no Tk, so
# console/CI use of tclutils stays Tk-free while tkutils provides the GUI.
#
# Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tubin 0.1
package require tclutils::tuhexdump 0.1
package require tclutils::common 0.1

namespace eval ::tkutils {}
namespace eval ::tkutils::tkhexedit {
    namespace export widget loadFile saveFile setData getData \
        gotoOffset findText findHex patchHex render
    variable state
}

# --- helpers ---------------------------------------------------------------

# Tcl-9-safe binary write (the engine offers a binary read via
# common::readBinaryFile but no whole-buffer writer). Never use -encoding
# binary; it is gone in Tcl 9.
proc ::tkutils::tkhexedit::_writeBinaryFile {filename data} {
    set chan [open $filename wb]
    try {
        fconfigure $chan -translation binary -encoding iso8859-1
        puts -nonewline $chan $data
    } finally {
        close $chan
    }
    return $filename
}

proc ::tkutils::tkhexedit::_parseOffset {value} {
    set v [string trim $value]
    if {[string match -nocase 0x* $v]} {
        if {![string is xdigit -strict [string range $v 2 end]]} {
            return -code error -errorcode {TKUTILS HEXEDIT OFFSET} \
                "offset must be a non-negative integer or 0xHEX value"
        }
        return [expr {$v}]
    }
    if {![string is integer -strict $v] || $v < 0} {
        return -code error -errorcode {TKUTILS HEXEDIT OFFSET} \
            "offset must be a non-negative integer or 0xHEX value"
    }
    return $v
}

proc ::tkutils::tkhexedit::_cleanup {path w} {
    variable state
    if {$w eq $path} {
        array unset state $path,*
    }
}

# --- widget ----------------------------------------------------------------

proc ::tkutils::tkhexedit::widget {path args} {
    variable state
    array set opts {
        -width 96
        -height 32
        -bytesperline 16
    }
    array set opts $args

    ttk::frame $path
    set state($path,data) ""
    set state($path,file) ""
    set state($path,bytesperline) $opts(-bytesperline)
    set state($path,lastfind) -1

    # release per-widget state when the widget is destroyed
    bind $path <Destroy> [list ::tkutils::tkhexedit::_cleanup $path %W]

    ttk::frame $path.toolbar
    ttk::button $path.toolbar.open -text Open -command [list ::tkutils::tkhexedit::_uiOpen $path]
    ttk::button $path.toolbar.save -text Save -command [list ::tkutils::tkhexedit::_uiSave $path]
    ttk::label $path.toolbar.lgoto -text "Offset:"
    ttk::entry $path.toolbar.goto -width 12
    ttk::button $path.toolbar.gbtn -text Goto -command [list ::tkutils::tkhexedit::_uiGoto $path]
    ttk::label $path.toolbar.lfind -text "Find:"
    ttk::entry $path.toolbar.find -width 24
    ttk::button $path.toolbar.ftext -text Text -command [list ::tkutils::tkhexedit::_uiFindText $path]
    ttk::button $path.toolbar.fhex -text Hex -command [list ::tkutils::tkhexedit::_uiFindHex $path]

    pack $path.toolbar.open $path.toolbar.save $path.toolbar.lgoto $path.toolbar.goto \
        $path.toolbar.gbtn $path.toolbar.lfind $path.toolbar.find $path.toolbar.ftext \
        $path.toolbar.fhex -side left -padx 2 -pady 2

    ttk::frame $path.main
    text $path.main.text -width $opts(-width) -height $opts(-height) \
        -wrap none -font TkFixedFont -undo 0
    ttk::scrollbar $path.main.ys -orient vertical -command [list $path.main.text yview]
    ttk::scrollbar $path.main.xs -orient horizontal -command [list $path.main.text xview]
    $path.main.text configure -yscrollcommand [list $path.main.ys set] \
        -xscrollcommand [list $path.main.xs set]
    grid $path.main.text $path.main.ys -sticky nsew
    grid $path.main.xs -sticky ew
    grid rowconfigure $path.main 0 -weight 1
    grid columnconfigure $path.main 0 -weight 1

    ttk::label $path.status -text "No file loaded" -anchor w

    pack $path.toolbar -side top -fill x
    pack $path.main -side top -fill both -expand 1
    pack $path.status -side bottom -fill x

    $path.main.text tag configure offset -foreground gray40
    $path.main.text tag configure hit -background yellow
    $path.main.text tag configure current -background lightblue

    return $path
}

proc ::tkutils::tkhexedit::setData {path data} {
    variable state
    set state($path,data) $data
    render $path
}

proc ::tkutils::tkhexedit::getData {path} {
    variable state
    return $state($path,data)
}

proc ::tkutils::tkhexedit::loadFile {path filename} {
    variable state
    set state($path,file) $filename
    set state($path,data) [::tclutils::common::readBinaryFile $filename]
    render $path
    $path.status configure -text "Loaded: $filename ([string length $state($path,data)] bytes)"
    return $filename
}

proc ::tkutils::tkhexedit::saveFile {path {filename ""}} {
    variable state
    if {$filename eq ""} {
        set filename $state($path,file)
    }
    if {$filename eq ""} {
        return -code error -errorcode {TKUTILS HEXEDIT NOFILE} "no filename specified"
    }
    _writeBinaryFile $filename $state($path,data)
    set state($path,file) $filename
    $path.status configure -text "Saved: $filename"
    return $filename
}

# Render the buffer as an offset/hex/ascii dump using the tclutils engine.
proc ::tkutils::tkhexedit::render {path {startOffset 0}} {
    variable state
    set text $path.main.text
    set data $state($path,data)
    set bpl $state($path,bytesperline)
    set size [string length $data]

    $text configure -state normal
    $text delete 1.0 end
    if {$size > 0} {
        foreach line [split [::tclutils::tuhexdump::data $data -width $bpl] \n] {
            set pos [$text index end]
            $text insert end "$line\n"
            # tag the 8-character offset column at the start of the line
            $text tag add offset $pos "$pos + 8 chars"
        }
    }
    $text configure -state disabled
    $path.status configure -text "Bytes: $size"
    if {$startOffset > 0} {
        gotoOffset $path $startOffset
    }
}

proc ::tkutils::tkhexedit::gotoOffset {path offset} {
    variable state
    set off [_parseOffset $offset]
    set bpl $state($path,bytesperline)
    set line [expr {$off / $bpl + 1}]
    set text $path.main.text
    $text tag remove current 1.0 end
    $text tag add current "$line.0" "$line.end"
    $text see "$line.0"
    $path.status configure -text [format "Offset: 0x%X (%d)" $off $off]
    return $off
}

proc ::tkutils::tkhexedit::findText {path pattern {start 0}} {
    variable state
    set data $state($path,data)
    set idx [string first $pattern $data $start]
    if {$idx >= 0} { gotoOffset $path $idx }
    return $idx
}

proc ::tkutils::tkhexedit::findHex {path hex {start 0}} {
    set pattern [::tclutils::tubin::hexToBytes $hex]
    return [findText $path $pattern $start]
}

proc ::tkutils::tkhexedit::patchHex {path offset hex} {
    variable state
    set off [_parseOffset $offset]
    set patch [::tclutils::tubin::hexToBytes $hex]
    set data $state($path,data)
    set len [string length $patch]
    if {$off < 0 || $off + $len > [string length $data]} {
        return -code error -errorcode {TKUTILS HEXEDIT RANGE} "patch range outside data"
    }
    set state($path,data) [string replace $data $off [expr {$off + $len - 1}] $patch]
    render $path $off
    return $len
}

# --- toolbar callbacks -----------------------------------------------------

proc ::tkutils::tkhexedit::_uiOpen {path} {
    set f [tk_getOpenFile]
    if {$f ne ""} {
        loadFile $path $f
    }
}

proc ::tkutils::tkhexedit::_uiSave {path} {
    variable state
    set f $state($path,file)
    if {$f eq ""} {
        set f [tk_getSaveFile]
    }
    if {$f ne ""} {
        saveFile $path $f
    }
}

proc ::tkutils::tkhexedit::_uiGoto {path} {
    set value [$path.toolbar.goto get]
    try {
        gotoOffset $path $value
    } on error {msg} {
        tk_messageBox -icon error -message $msg
    }
}

proc ::tkutils::tkhexedit::_uiFindText {path} {
    set value [$path.toolbar.find get]
    set idx [findText $path $value]
    if {$idx < 0} {
        $path.status configure -text "Text not found"
    }
}

proc ::tkutils::tkhexedit::_uiFindHex {path} {
    set value [$path.toolbar.find get]
    try {
        set idx [findHex $path $value]
        if {$idx < 0} { $path.status configure -text "Hex not found" }
    } on error {msg} {
        tk_messageBox -icon error -message $msg
    }
}

package provide tkutils::tkhexedit 0.1
