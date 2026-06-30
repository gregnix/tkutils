# tkutils::tkutablelist -- multi-column table (OPTIONAL: requires Tablelist)
# Description: multi-column table (OPTIONAL: requires Tablelist)
# Category: Tk · tablelist
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
namespace eval ::tkutils::tkutablelist {
    namespace export widget insert setRows rows clear size setColumns columns \
        loadCsv sortBy tableWidget cellText setCell getRow setRow deleteRow \
        selection selectedRows selectRows configureColumn fromNotes \
        configureRow configureCell insertChild expand collapse \
        toCsv saveCsv editEndCommand selectCommand doubleCommand \
        footerWidget footerSet footerSum
    variable state
}

proc ::tkutils::tkutablelist::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Parse a column spec into {tablelistColumnsSpec extras}. Each column entry is
# either a plain title (which may contain spaces) or a list
#   {title -align a -width w -sortmode m -editable b ...}
# detected by the second element starting with "-". -align/-width go into the
# base spec; the remaining options are applied later via columnconfigure.
proc ::tkutils::tkutablelist::_parseColumns {cols} {
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

proc ::tkutils::tkutablelist::_applyExtras {path extras} {
    set tbl $path.tbl
    foreach e $extras {
        lassign $e col opts
        $tbl columnconfigure $col {*}$opts
    }
}

# Make every column editable when the -editable flag is on.
proc ::tkutils::tkutablelist::_applyEditable {path} {
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
proc ::tkutils::tkutablelist::widget {path args} {
    variable state
    array set o {-columns {} -stretch all -titlecolumns 0 -sortable 1 \
        -editable 0 -selectmode extended -stripes "" -editendcommand "" \
        -selectcommand "" -doublecommand "" -footer 0}
    foreach {opt val} $args {
        if {![info exists o($opt)]} {
            return -code error -errorcode {TKUTILS TKUTABLELIST OPTION} \
                "unknown option '$opt'"
        }
    }
    array set o $args

    ttk::frame $path
    set state($path,editable) $o(-editable)
    set state($path,editend) $o(-editendcommand)
    set state($path,selectcmd) $o(-selectcommand)
    set state($path,doublecmd) $o(-doublecommand)
    bind $path <Destroy> [list ::tkutils::tkutablelist::_cleanup $path %W]

    lassign [_parseColumns $o(-columns)] spec extras
    set tbl $path.tbl
    tablelist::tablelist $tbl \
        -columns $spec \
        -stretch $o(-stretch) -titlecolumns $o(-titlecolumns) \
        -selectmode $o(-selectmode) \
        -editendcommand [list ::tkutils::tkutablelist::_editEnd $path] \
        -yscrollcommand [list $path.ys set] \
        -xscrollcommand [list ::tkutils::tkutablelist::_xscroll $path]
    if {$o(-stripes) ne ""} { $tbl configure -stripebackground $o(-stripes) }
    if {$o(-sortable)} {
        $tbl configure -labelcommand [list ::tkutils::tkutablelist::_sortClick $path]
    }
    # selection + double-click dispatchers (always bound; guarded on empty cmd)
    bind $tbl <<TablelistSelect>> [list ::tkutils::tkutablelist::_select $path]
    bind [$tbl bodytag] <Double-1> \
        [list ::tkutils::tkutablelist::_dblClick $path %W %x %y]
    _applyExtras $path $extras
    _applyEditable $path
    ttk::scrollbar $path.ys -orient vertical   -command [list $tbl yview]
    ttk::scrollbar $path.xs -orient horizontal -command [list $tbl xview]
    grid $tbl     $path.ys -sticky nsew
    grid $path.xs -sticky ew
    grid rowconfigure $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1
    set state($path,footer) $o(-footer)
    if {$o(-footer)} {
        set foot $path.foot
        tablelist::tablelist $foot -showlabels 0 -showseparators 0 \
            -selectmode none -exportselection 0 -height 1 \
            -titlecolumns $o(-titlecolumns) -stretch $o(-stretch)
        _footerSync $path
        $foot insert end [lrepeat [$tbl columncount] ""]
        $foot rowconfigure 0 -selectable 0
        # Footer zwischen Tabellenkoerper (Zeile 0) und H-Scrollbar (-> Zeile 2)
        grid $foot   -row 1 -column 0 -sticky ew
        grid configure $path.xs -row 2
        bind $tbl <<TablelistColumnResized>> +[list ::tkutils::tkutablelist::_footerSync $path]
        bind $tbl <<TablelistColumnMoved>>   +[list ::tkutils::tkutablelist::_footerSync $path]
        bind $tbl <Configure>                +[list ::tkutils::tkutablelist::_footerSync $path]
        after idle [list ::tkutils::tkutablelist::_footerSync $path]
    }
    return $path
}

# Horizontal-Scroll der Tabelle: Scrollbar aktualisieren UND -- falls vorhanden --
# den Footer auf dieselbe Position spiegeln. Ersetzt das blanke "$path.xs set",
# damit die Scrollbar weiter bedient wird (im Gegensatz zu scrollutil::scrollsync,
# das das alte xscrollcommand ueberschreibt).
proc ::tkutils::tkutablelist::_xscroll {path first last} {
    $path.xs set $first $last
    if {[winfo exists $path.foot]} { catch {$path.foot xview moveto $first} }
    return
}

# Footer-Spalten an die Haupttabelle angleichen: Anzahl, Breite, Ausrichtung,
# verdeckte Spalten. Wird initial und bei Resize/Spaltenverschiebung gerufen.
proc ::tkutils::tkutablelist::_footerSync {path} {
    if {![winfo exists $path.foot]} return
    set tbl $path.tbl; set foot $path.foot
    set n [$tbl columncount]
    while {[$foot columncount] < $n} { $foot insertcolumns end 1 "" }
    while {[$foot columncount] > $n} { $foot deletecolumns end end }
    for {set c 0} {$c < $n} {incr c} {
        $foot columnconfigure $c \
            -width [$tbl columncget $c -width] \
            -align [$tbl columncget $c -align] \
            -hide  [$tbl columncget $c -hide]
    }
    catch {$foot xview moveto [lindex [$tbl xview] 0]}
    return
}

# Footer-Tablelist (oder "" wenn kein Footer).
proc ::tkutils::tkutablelist::footerWidget {path} {
    if {[winfo exists $path.foot]} { return $path.foot }
    return ""
}

# Footer-Zellen setzen (eine Liste, ein Wert je Spalte).
proc ::tkutils::tkutablelist::footerSet {path values} {
    if {![winfo exists $path.foot]} return
    set foot $path.foot
    set n [$foot columncount]
    for {set c 0} {$c < $n} {incr c} {
        $foot cellconfigure 0,$c -text [lindex $values $c]
    }
    return
}

# Spaltensummen (deutsch via tunum) in den Footer, je Summe unter ihrer Spalte;
# optionales Label in -labelcolumn. -format wendet [format] auf die Summe an
# (englischer Punkt!) -- fuer deutsche Waehrung stattdessen footerSet nutzen.
proc ::tkutils::tkutablelist::footerSum {path args} {
    if {![winfo exists $path.foot]} return
    array set opt {-columns {} -label "" -labelcolumn 0 -format ""}
    array set opt $args
    set tbl $path.tbl
    set n [$tbl columncount]
    if {![llength $opt(-columns)]} { for {set c 0} {$c < $n} {incr c} { lappend opt(-columns) $c } }
    set out [lrepeat $n ""]
    if {$opt(-label) ne "" && $opt(-labelcolumn) >= 0 && $opt(-labelcolumn) < $n} {
        lset out $opt(-labelcolumn) $opt(-label)
    }
    foreach c $opt(-columns) {
        if {$c < 0 || $c >= $n} continue
        set vals {}
        for {set r 0} {$r < [$tbl size]} {incr r} { lappend vals [$tbl cellcget $r,$c -text] }
        set tot [_gsum $vals]
        if {$tot ne ""} {
            if {$opt(-format) ne ""} { set tot [format $opt(-format) $tot] }
            lset out $c $tot
        }
    }
    footerSet $path $out
    return
}

# Deutsch-tolerante Spaltensumme (tunum, sonst lokaler Parser). "" wenn nichts numerisch.
proc ::tkutils::tkutablelist::_gsum {vals} {
    if {![catch {package require tclutils::tunum}]} {
        return [::tclutils::tunum::sum $vals -default ""]
    }
    set acc 0.0; set any 0
    foreach v $vals {
        set t [string trim $v]
        if {$t eq ""} continue
        set t [string map {. {} , .} $t]
        if {[string is double -strict $t]} { set acc [expr {$acc + $t}]; set any 1 }
    }
    return [expr {$any ? $acc : ""}]
}

proc ::tkutils::tkutablelist::tableWidget {path} { return $path.tbl }

# --- rows ---

proc ::tkutils::tkutablelist::insert {path row} {
    $path.tbl insert end $row
    return [$path.tbl size]
}
proc ::tkutils::tkutablelist::setRows {path rows} {
    set tbl $path.tbl
    $tbl delete 0 end
    foreach r $rows { $tbl insert end $r }
    return [$tbl size]
}
proc ::tkutils::tkutablelist::rows {path} { return [$path.tbl get 0 end] }
proc ::tkutils::tkutablelist::clear {path} { $path.tbl delete 0 end; return }
proc ::tkutils::tkutablelist::size {path} { return [$path.tbl size] }

proc ::tkutils::tkutablelist::getRow {path index} { return [$path.tbl get $index] }
proc ::tkutils::tkutablelist::setRow {path index row} {
    $path.tbl rowconfigure $index -text $row
    return $row
}
proc ::tkutils::tkutablelist::deleteRow {path index} {
    $path.tbl delete $index
    return [$path.tbl size]
}

# --- cells ---

proc ::tkutils::tkutablelist::cellText {path row col} {
    return [$path.tbl cellcget $row,$col -text]
}
proc ::tkutils::tkutablelist::setCell {path row col value} {
    $path.tbl cellconfigure $row,$col -text $value
    return $value
}

# --- columns ---

proc ::tkutils::tkutablelist::setColumns {path titles} {
    lassign [_parseColumns $titles] spec extras
    $path.tbl configure -columns $spec
    _applyExtras $path $extras
    _applyEditable $path
    return $titles
}
proc ::tkutils::tkutablelist::columns {path} {
    set tbl $path.tbl
    set out {}
    for {set i 0} {$i < [$tbl columncount]} {incr i} {
        lappend out [$tbl columncget $i -title]
    }
    return $out
}
# Configure a column, e.g. -sortmode integer -align right -editable 1 -width N.
proc ::tkutils::tkutablelist::configureColumn {path col args} {
    $path.tbl columnconfigure $col {*}$args
    return $col
}

# Configure a row, e.g. -foreground gray -background ... -font ...
# row may be a row index, "end", or a full key (k0, k1, ... from insertChild).
proc ::tkutils::tkutablelist::configureRow {path row args} {
    $path.tbl rowconfigure $row {*}$args
    return $row
}

# Configure a single cell ("row,col"), e.g. -background yellow -foreground ...
proc ::tkutils::tkutablelist::configureCell {path cell args} {
    $path.tbl cellconfigure $cell {*}$args
    return $cell
}

# --- hierarchy (parent / child rows) ---

# Insert a child row under $parent ("root" or a full key) at $index (default end).
# Returns the full key of the new row (k0, k1, ...), needed to attach further
# children or to address the row in configureRow.
proc ::tkutils::tkutablelist::insertChild {path parent values {index end}} {
    return [$path.tbl insertchild $parent $index $values]
}

# Expand a row (by index or key); with no row, expand every row.
proc ::tkutils::tkutablelist::expand {path {row ""}} {
    if {$row eq ""} { $path.tbl expandall } else { $path.tbl expand $row }
    return
}

# Collapse a row (by index or key); with no row, collapse every row.
proc ::tkutils::tkutablelist::collapse {path {row ""}} {
    if {$row eq ""} { $path.tbl collapseall } else { $path.tbl collapse $row }
    return
}

# --- selection ---

proc ::tkutils::tkutablelist::selection {path} {
    return [$path.tbl curselection]
}
proc ::tkutils::tkutablelist::selectedRows {path} {
    set sel [$path.tbl curselection]
    if {$sel eq ""} { return {} }
    return [$path.tbl get $sel]
}
proc ::tkutils::tkutablelist::selectRows {path indices} {
    set tbl $path.tbl
    $tbl selection clear 0 end
    foreach i $indices { $tbl selection set $i }
    return $indices
}

# --- sorting ---

proc ::tkutils::tkutablelist::sortBy {path col {order -increasing}} {
    $path.tbl sortbycolumn $col $order
    return $col
}
proc ::tkutils::tkutablelist::_sortClick {path tbl col} {
    set order -increasing
    if {[$tbl sortcolumn] == $col && [$tbl sortorder] eq "increasing"} {
        set order -decreasing
    }
    $tbl sortbycolumn $col $order
}

# --- data sources ---

# Load CSV text via tucsv. With -header 1 (default) the first row becomes the
# column titles. Extra args (e.g. -delimiter) pass through to tucsv::parse.
proc ::tkutils::tkutablelist::loadCsv {path csv args} {
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

proc ::tkutils::tkutablelist::_notesOrder {store parent} {
    set acc {}
    foreach id [::tclutils::tunotes::children $store $parent] {
        lappend acc $id
        lappend acc {*}[_notesOrder $store $id]
    }
    return $acc
}

# Display a tclutils::tunotes store as a table (Title, Parent, Tags) in tree
# order. With -indent 1 (default) the title is indented by depth.
proc ::tkutils::tkutablelist::fromNotes {path store args} {
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
proc ::tkutils::tkutablelist::_editEnd {path tbl row col text} {
    variable state
    if {[info exists state($path,editend)] && $state($path,editend) ne ""} {
        return [uplevel #0 [list {*}$state($path,editend) $path $row $col $text]]
    }
    return $text
}

# Set (or clear with "") the edit-end command.
proc ::tkutils::tkutablelist::editEndCommand {path cmd} {
    variable state
    set state($path,editend) $cmd
    return $cmd
}

# Selection hook. Fires on <<TablelistSelect>> as: cmd path row
# where row is the first selected row index, or -1 if the selection is empty.
proc ::tkutils::tkutablelist::_select {path} {
    variable state
    if {![info exists state($path,selectcmd)] || $state($path,selectcmd) eq ""} return
    set sel [$path.tbl curselection]
    set row [expr {[llength $sel] ? [lindex $sel 0] : -1}]
    uplevel #0 [list {*}$state($path,selectcmd) $path $row]
}

# Double-click hook on a data row. Fires as: cmd path row (only when row >= 0).
# Body coordinates are converted with tablelist::convEventFields so the row is
# correct regardless of stripes/separators.
proc ::tkutils::tkutablelist::_dblClick {path w x y} {
    variable state
    if {![info exists state($path,doublecmd)] || $state($path,doublecmd) eq ""} return
    lassign [tablelist::convEventFields $w $x $y] tbl cx cy
    set row [$tbl containing $cy]
    if {$row >= 0} { uplevel #0 [list {*}$state($path,doublecmd) $path $row] }
}

# Get or set the selection command (no arg = read, one arg = set).
proc ::tkutils::tkutablelist::selectCommand {path args} {
    variable state
    if {[llength $args]} { set state($path,selectcmd) [lindex $args 0] }
    return $state($path,selectcmd)
}

# Get or set the double-click command (no arg = read, one arg = set).
proc ::tkutils::tkutablelist::doubleCommand {path args} {
    variable state
    if {[llength $args]} { set state($path,doublecmd) [lindex $args 0] }
    return $state($path,doublecmd)
}

# Return the table as CSV text via tucsv. With -header 1 (default) the column
# titles are written as the first row. Extra args pass to tucsv::text.
proc ::tkutils::tkutablelist::toCsv {path args} {
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
proc ::tkutils::tkutablelist::saveCsv {path file args} {
    set csv [toCsv $path {*}$args]
    set ch [open $file w]
    fconfigure $ch -translation lf
    puts -nonewline $ch $csv
    close $ch
    return $file
}

package provide tkutils::tkutablelist 0.2
