# tkutils::tktablelist -- multi-column table (OPTIONAL: requires Tablelist)
#
# A wrapper around the Tablelist megawidget (from tklib): a rows/columns API,
# click-to-sort headers, optional frozen title columns, editable cells, row
# selection helpers, per-column configuration (sort mode, alignment), CSV
# loading via tclutils::tucsv, and display of a tclutils::tunotes store.
#
# OPTIONAL widget: NOT part of the tkutils umbrella. Require it directly once
# Tablelist is installed. Tcl/Tk 8.6+.

package require Tcl 8.6-
package require Tk 8.6-
if {[catch {package require tablelist_tile}]} {
    package require Tablelist
}

namespace eval ::tkutils {}
namespace eval ::tkutils::tktablelist {
    namespace export widget insert setRows rows clear size setColumns columns \
        loadCsv sortBy tableWidget cellText setCell getRow setRow deleteRow \
        selection selectedRows selectRows configureColumn fromNotes \
        toCsv saveCsv editEndCommand
    variable state
}

proc ::tkutils::tktablelist::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Parse a column spec into {tablelistColumnsSpec extras}. Each column entry is
# either a plain title (which may contain spaces) or a list
#   {title -align a -width w -sortmode m -editable b ...}
# detected by the second element starting with "-". -align/-width go into the
# base spec; the remaining options are applied later via columnconfigure.
proc ::tkutils::tktablelist::_parseColumns {cols} {
    set spec {}
    set extras {}
    set i 0
    foreach c $cols {
        if {[llength $c] >= 2 && [string match -* [lindex $c 1]]} {
            set title [lindex $c 0]
            set align left
            set width 0
            set opts {}
            foreach {k v} [lrange $c 1 end] {
                switch -- $k {
                    -align { set align $v }
                    -width { set width $v }
                    default { lappend opts $k $v }
                }
            }
        } else {
            set title $c
            set align left
            set width 0
            set opts {}
        }
        lappend spec $width $title $align
        if {[llength $opts]} { lappend extras [list $i $opts] }
        incr i
    }
    return [list $spec $extras]
}

proc ::tkutils::tktablelist::_applyExtras {path extras} {
    set tbl $path.tbl
    foreach e $extras {
        lassign $e col opts
        $tbl columnconfigure $col {*}$opts
    }
}

# Make every column editable when the -editable flag is on.
proc ::tkutils::tktablelist::_applyEditable {path} {
    variable state
    if {!$state($path,editable)} return
    set tbl $path.tbl
    for {set i 0} {$i < [$tbl columncount]} {incr i} {
        $tbl columnconfigure $i -editable 1
    }
}

# Build the table under $path. Options:
#   -columns {t1 t2 ...}   column titles
#   -stretch all|{i ...}   stretchable columns (default all)
#   -titlecolumns N        freeze the leftmost N columns (default 0)
#   -sortable 0|1          click headers to sort (default 1)
#   -editable 0|1          make all columns editable (default 0)
#   -selectmode M          browse|single|extended (default extended)
#   -stripes COLOR         stripe background for alternate rows ("" = none)
proc ::tkutils::tktablelist::widget {path args} {
    variable state
    array set o {-columns {} -stretch all -titlecolumns 0 -sortable 1 \
        -editable 0 -selectmode extended -stripes "" -editendcommand ""}
    array set o $args

    ttk::frame $path
    set state($path,editable) $o(-editable)
    set state($path,editend) $o(-editendcommand)
    bind $path <Destroy> [list ::tkutils::tktablelist::_cleanup $path %W]

    lassign [_parseColumns $o(-columns)] spec extras
    set tbl $path.tbl
    tablelist::tablelist $tbl \
        -columns $spec \
        -stretch $o(-stretch) -titlecolumns $o(-titlecolumns) \
        -selectmode $o(-selectmode) \
        -editendcommand [list ::tkutils::tktablelist::_editEnd $path] \
        -yscrollcommand [list $path.ys set] -xscrollcommand [list $path.xs set]
    if {$o(-stripes) ne ""} { $tbl configure -stripebackground $o(-stripes) }
    if {$o(-sortable)} {
        $tbl configure -labelcommand [list ::tkutils::tktablelist::_sortClick $path]
    }
    _applyExtras $path $extras
    _applyEditable $path
    ttk::scrollbar $path.ys -orient vertical   -command [list $tbl yview]
    ttk::scrollbar $path.xs -orient horizontal -command [list $tbl xview]
    grid $tbl     $path.ys -sticky nsew
    grid $path.xs -sticky ew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1
    return $path
}

proc ::tkutils::tktablelist::tableWidget {path} { return $path.tbl }

# --- rows ---

proc ::tkutils::tktablelist::insert {path row} {
    $path.tbl insert end $row
    return [$path.tbl size]
}
proc ::tkutils::tktablelist::setRows {path rows} {
    set tbl $path.tbl
    $tbl delete 0 end
    foreach r $rows { $tbl insert end $r }
    return [$tbl size]
}
proc ::tkutils::tktablelist::rows {path} { return [$path.tbl get 0 end] }
proc ::tkutils::tktablelist::clear {path} { $path.tbl delete 0 end; return }
proc ::tkutils::tktablelist::size {path} { return [$path.tbl size] }

proc ::tkutils::tktablelist::getRow {path index} { return [$path.tbl get $index] }
proc ::tkutils::tktablelist::setRow {path index row} {
    $path.tbl rowconfigure $index -text $row
    return $row
}
proc ::tkutils::tktablelist::deleteRow {path index} {
    $path.tbl delete $index
    return [$path.tbl size]
}

# --- cells ---

proc ::tkutils::tktablelist::cellText {path row col} {
    return [$path.tbl cellcget $row,$col -text]
}
proc ::tkutils::tktablelist::setCell {path row col value} {
    $path.tbl cellconfigure $row,$col -text $value
    return $value
}

# --- columns ---

proc ::tkutils::tktablelist::setColumns {path titles} {
    lassign [_parseColumns $titles] spec extras
    $path.tbl configure -columns $spec
    _applyExtras $path $extras
    _applyEditable $path
    return $titles
}
proc ::tkutils::tktablelist::columns {path} {
    set tbl $path.tbl
    set out {}
    for {set i 0} {$i < [$tbl columncount]} {incr i} {
        lappend out [$tbl columncget $i -title]
    }
    return $out
}
# Configure a column, e.g. -sortmode integer -align right -editable 1 -width N.
proc ::tkutils::tktablelist::configureColumn {path col args} {
    $path.tbl columnconfigure $col {*}$args
    return $col
}

# --- selection ---

proc ::tkutils::tktablelist::selection {path} {
    return [$path.tbl curselection]
}
proc ::tkutils::tktablelist::selectedRows {path} {
    set sel [$path.tbl curselection]
    if {$sel eq ""} { return {} }
    return [$path.tbl get $sel]
}
proc ::tkutils::tktablelist::selectRows {path indices} {
    set tbl $path.tbl
    $tbl selection clear 0 end
    foreach i $indices { $tbl selection set $i }
    return $indices
}

# --- sorting ---

proc ::tkutils::tktablelist::sortBy {path col {order -increasing}} {
    $path.tbl sortbycolumn $col $order
    return $col
}
proc ::tkutils::tktablelist::_sortClick {path tbl col} {
    set order -increasing
    if {[$tbl sortcolumn] == $col && [$tbl sortorder] eq "increasing"} {
        set order -decreasing
    }
    $tbl sortbycolumn $col $order
}

# --- data sources ---

# Load CSV text via tucsv. With -header 1 (default) the first row becomes the
# column titles. Extra args (e.g. -delimiter) pass through to tucsv::parse.
proc ::tkutils::tktablelist::loadCsv {path csv args} {
    package require tclutils::tucsv 0.1
    set header 1
    if {[dict exists $args -header]} {
        set header [dict get $args -header]
        dict unset args -header
    }
    set parsed [::tclutils::tucsv::parse $csv {*}$args]
    if {$header && [llength $parsed]} {
        setColumns $path [lindex $parsed 0]
        set parsed [lrange $parsed 1 end]
    }
    return [setRows $path $parsed]
}

proc ::tkutils::tktablelist::_notesOrder {store parent} {
    set acc {}
    foreach id [::tclutils::tunotes::children $store $parent] {
        lappend acc $id
        lappend acc {*}[_notesOrder $store $id]
    }
    return $acc
}

# Display a tclutils::tunotes store as a table (Title, Parent, Tags) in tree
# order. With -indent 1 (default) the title is indented by depth.
proc ::tkutils::tktablelist::fromNotes {path store args} {
    package require tclutils::tunotes 0.1
    array set o {-indent 1}
    array set o $args
    setColumns $path {Title Parent Tags}
    set rows {}
    foreach id [_notesOrder $store ""] {
        set note [::tclutils::tunotes::get $store $id]
        set depth [expr {[llength [::tclutils::tunotes::path $store $id]] - 1}]
        set title [dict get $note title]
        if {$o(-indent)} { set title "[string repeat {    } $depth]$title" }
        set pid [dict get $note parent_id]
        if {$pid eq ""} {
            set parent "(root)"
        } else {
            set parent [dict get [::tclutils::tunotes::get $store $pid] title]
        }
        lappend rows [list $title $parent [join [dict get $note tags] " "]]
    }
    return [setRows $path $rows]
}

# Cell-edit end hook. If a user command is set, it is called as
#   cmd path row col text
# and its return value becomes the stored cell text (enables validation or
# transformation). Without a user command the text is stored unchanged.
proc ::tkutils::tktablelist::_editEnd {path tbl row col text} {
    variable state
    if {[info exists state($path,editend)] && $state($path,editend) ne ""} {
        return [uplevel #0 [list {*}$state($path,editend) $path $row $col $text]]
    }
    return $text
}

# Set (or clear with "") the edit-end command.
proc ::tkutils::tktablelist::editEndCommand {path cmd} {
    variable state
    set state($path,editend) $cmd
    return $cmd
}

# Return the table as CSV text via tucsv. With -header 1 (default) the column
# titles are written as the first row. Extra args pass to tucsv::text.
proc ::tkutils::tktablelist::toCsv {path args} {
    package require tclutils::tucsv 0.1
    set header 1
    if {[dict exists $args -header]} {
        set header [dict get $args -header]
        dict unset args -header
    }
    set data [rows $path]
    if {$header} { set data [linsert $data 0 [columns $path]] }
    return [::tclutils::tucsv::text $data {*}$args]
}

# Write the table to a CSV file. Options as for toCsv.
proc ::tkutils::tktablelist::saveCsv {path file args} {
    set csv [toCsv $path {*}$args]
    set ch [open $file w]
    fconfigure $ch -translation lf
    puts -nonewline $ch $csv
    close $ch
    return $file
}

package provide tkutils::tktablelist 0.1
