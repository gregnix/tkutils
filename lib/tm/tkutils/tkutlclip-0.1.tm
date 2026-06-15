# tkutils::tkutlclip -- copy tablelist rows to the clipboard as TSV or CSV.
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
#
# CSV uses tclutils::tucsv when available (proper quoting); otherwise a built-in
# minimal quoter. TSV replaces embedded tabs/newlines with spaces so the result
# stays paste-safe in spreadsheets.
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
package require tablelist

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutlclip {
    namespace export copySelection copyAll asText installBindings
}

proc ::tkutils::tkutlclip::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUTLCLIP $reason] $msg
}

proc ::tkutils::tkutlclip::_opts {argsVar} {
    upvar 1 $argsVar args
    array set o {-format tsv -header 0 -formatted 1 -columns visible}
    foreach {k v} $args {
        switch -- $k {
            -format    { set o(-format) $v }
            -header    { set o(-header) $v }
            -formatted { set o(-formatted) $v }
            -columns   { set o(-columns) $v }
            default    { _err OPTION "unknown option \"$k\"" }
        }
    }
    if {$o(-format) ni {tsv csv}} { _err FORMAT "format must be tsv or csv" }
    if {$o(-columns) ni {visible all}} { _err COLUMNS "columns must be visible or all" }
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
        lappend lines [_joinRow $titles $o(-format)]
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
        lappend lines [_joinRow $cells $o(-format)]
    }
    return [join $lines \n]
}

proc ::tkutils::tkutlclip::_joinRow {cells format} {
    if {$format eq "csv"} {
        if {![catch {package require tclutils::tucsv}]} {
            return [::tclutils::tucsv::joinLine $cells]
        }
        return [_csvLine $cells]
    }
    # tsv: strip tab/newline so paste stays aligned
    set out {}
    foreach v $cells {
        lappend out [string map [list \t " " \n " " \r ""] $v]
    }
    return [join $out \t]
}

# Minimal CSV line quoter (RFC-4180 style) used when tucsv is absent.
proc ::tkutils::tkutlclip::_csvLine {cells} {
    set out {}
    foreach v $cells {
        if {[string match {*[",\n\r]*} $v]} {
            set v \"[string map [list \" \"\"] $v]\"
        }
        lappend out $v
    }
    return [join $out ,]
}

# Copy the currently selected rows. Returns the number of rows copied.
proc ::tkutils::tkutlclip::copySelection {tbl args} {
    set rows [$tbl curselection]
    if {[llength $rows] == 0} { return 0 }
    set text [asText $tbl $rows {*}$args]
    clipboard clear -displayof $tbl
    clipboard append -displayof $tbl $text
    return [llength $rows]
}

# Copy all rows. Returns the number of rows copied.
proc ::tkutils::tkutlclip::copyAll {tbl args} {
    set n [$tbl size]
    set rows {}
    for {set r 0} {$r < $n} {incr r} { lappend rows $r }
    set text [asText $tbl $rows {*}$args]
    clipboard clear -displayof $tbl
    clipboard append -displayof $tbl $text
    return $n
}

# Bind <<Copy>> (Ctrl+C) on the tablelist body to copySelection.
proc ::tkutils::tkutlclip::installBindings {tbl args} {
    set body [$tbl bodypath]
    bind $body <<Copy>> [list ::tkutils::tkutlclip::copySelection $tbl {*}$args]
    return $tbl
}

package provide tkutils::tkutlclip 0.1
