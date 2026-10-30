# tkutils::tkutlclip -- copy tablelist rows to the clipboard as TSV or CSV.
# Description: copy tablelist rows to the clipboard as TSV or CSV.
# Category: Tk · tablelist
# tablelist has no clipboard export; this provides the common "Ctrl+C copies the
# selection as spreadsheet-pasteable text" behaviour. Library-neutral.
#
# API:
#   tkutils::tkutlclip::copySelection tbl ?options?
#   tkutils::tkutlclip::copyAll       tbl ?options?
#   tkutils::tkutlclip::asText        tbl rows ?options?     ;# no clipboard
#   tkutils::tkutlclip::installBindings tbl ?options?        ;# bind <<Copy>>
#
# Options:
#   -format tsv|csv   output format (default tsv)
#   -header 0|1       prepend column titles (default 0)
#   -formatted 0|1    use displayed values (default 1) vs raw cell values
#   -columns visible|all   include hidden columns or not (default visible)
#   -separator CHAR   CSV field separator (default ",", e.g. ";" for Excel-de)
#
# Rows: copySelection takes the selected rows, copyAll the viewable rows
# (hidden rows and collapsed tree children are skipped).
#
# CSV goes through tclutils::tucsv 0.2, as tkutablelist::toCsv does, so both
# write the same line for the same row (up to tkutils 0.48.0 a built-in quoter
# took over when tucsv was missing). TSV replaces embedded tabs/newlines with
# spaces so the result stays paste-safe in spreadsheets.
#
# Tcl 8.6-, tclutils::tucsv 0.2
package require Tcl 8.6-
package require Tk
package require tclutils::tucsv 0.2
# tablelist_tile is the Tablelist variant of tkutils (as in tkutablelist).
# Tablelist forbids loading tablelist and tablelist_tile in one process; both
# provide the same ::tablelist:: commands, so an application that already has
# the classic one keeps it. Up to 2026-10-20 this module required the classic
# "tablelist", and tkutils followed by this module failed with
# "usingTile ... not supported".
if {[catch {package present tablelist}] && [catch {package present tablelist_tile}]} {
    package require tablelist_tile
}

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutlclip {
    namespace export copySelection copyAll asText installBindings
}

proc ::tkutils::tkutlclip::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLCLIP $reason] $msg
}

proc ::tkutils::tkutlclip::_opts {argsVar} {
    upvar 1 $argsVar args
    array set o {-format tsv -header 0 -formatted 1 -columns visible -separator ,}
    foreach {k v} $args {
        switch -- $k {
            -format    { set o(-format) $v }
            -header    { set o(-header) $v }
            -formatted { set o(-formatted) $v }
            -columns   { set o(-columns) $v }
            -separator { set o(-separator) $v }
            default    { _err OPTION "unknown option \"$k\"" }
        }
    }
    if {$o(-format) ni {tsv csv}} { _err FORMAT "format must be tsv or csv" }
    if {$o(-columns) ni {visible all}} { _err COLUMNS "columns must be visible or all" }
    if {[string length $o(-separator)] != 1} { _err SEPARATOR "separator must be one character" }
    return [array get o]
}

# Indices of the columns to include.
proc ::tkutils::tkutlclip::_cols {tbl mode} {
    set n [$tbl columncount]
    set cols {}
    for {set c 0} {$c < $n} {incr c} {
        if {$mode eq "all"} {
            lappend cols $c
        } else {
            set hide 0; catch {set hide [$tbl columncget $c -hide]}
            if {!$hide} { lappend cols $c }
        }
    }
    return $cols
}

# Build TSV/CSV text from a list of row indices.
proc ::tkutils::tkutlclip::asText {tbl rows args} {
    array set o [_opts args]
    set cols [_cols $tbl $o(-columns)]

    set lines {}
    if {$o(-header)} {
        set titles {}
        foreach c $cols {
            set t ""; catch {set t [$tbl columncget $c -title]}
            lappend titles $t
        }
        lappend lines [_joinRow $titles $o(-format) $o(-separator)]
    }
    foreach r $rows {
        if {$o(-formatted)} {
            set rowData [$tbl getformatted $r]
        } else {
            set rowData [$tbl get $r]
        }
        set cells {}
        foreach c $cols {
            set v ""
            if {[llength $rowData] > $c} { set v [lindex $rowData $c] }
            lappend cells $v
        }
        lappend lines [_joinRow $cells $o(-format) $o(-separator)]
    }
    return [join $lines \n]
}

proc ::tkutils::tkutlclip::_joinRow {cells format {sep ,}} {
    if {$format eq "csv"} {
        return [::tclutils::tucsv::joinLine $cells -delimiter $sep]
    }
    # tsv: strip tab/newline so paste stays aligned
    set out {}
    foreach v $cells {
        lappend out [string map [list \t " " \n " " \r ""] $v]
    }
    return [join $out \t]
}

# Copy the currently selected rows. Returns the number of rows copied.
proc ::tkutils::tkutlclip::copySelection {tbl args} {
    _opts args   ;# bad options are an error even with an empty selection
    set rows [$tbl curselection]
    if {[llength $rows] == 0} { return 0 }
    set text [asText $tbl $rows {*}$args]
    clipboard clear -displayof $tbl
    clipboard append -displayof $tbl $text
    return [llength $rows]
}

# Copy all viewable rows (no hidden rows, no collapsed children). Returns the
# number of rows copied.
proc ::tkutils::tkutlclip::copyAll {tbl args} {
    set rows [$tbl getfullkeys 0 end -viewable]
    set text [asText $tbl $rows {*}$args]
    clipboard clear -displayof $tbl
    clipboard append -displayof $tbl $text
    return [llength $rows]
}

# Bind <<Copy>> (Ctrl+C) on the tablelist body to copySelection. The binding
# sits on the body's binding tag and ends with "break": otherwise Tablelist's
# own <<Copy>> binding (class TablelistBody) runs afterwards and replaces the
# clipboard with its plain TSV.
proc ::tkutils::tkutlclip::installBindings {tbl args} {
    _opts args   ;# validate now, not on the first Ctrl+C
    bind [$tbl bodytag] <<Copy>> \
        "[list ::tkutils::tkutlclip::copySelection $tbl {*}$args]; break"
    return $tbl
}

package provide tkutils::tkutlclip 0.3
