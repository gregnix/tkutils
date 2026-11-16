# tkutils::tkufilelist -- a detail file list, filled from a storage provider.
# Description: a detail file list, filled from a storage provider
# Category: Tk · widgets
#
# The list counterpart to tkufiletree: where the tree shows the hierarchy, the
# list shows the contents of one directory in columns. Both read through the
# same provider interface, so the list works over local files, ZIP, WebDAV,
# ... unchanged.
#
# Built on tkutils::tkutablelist (which wraps the Tablelist megawidget).
#
#   tkufilelist::widget .fl -provider $p -dir /some/path \
#       -onactivate {apply {e { puts "open [dict get $e path]" }}}
#
# Options:
#   -provider P        a tuprovider object (default: a fresh local provider)
#   -dir D             directory to show (default "/")
#   -show S            both | files | dirs (default both)
#   -files B           old form of -show: 1 = both, 0 = dirs (0.2)
#   -columns L         columns to show, in this order, from
#                      name mtime type size ext (default {name mtime type size});
#                      name is always shown
#   -columnmenu B      right-click on the header: show/hide columns (default 1)
#   -showhidden B      show hidden entries (default 0)
#   -showsystem B      also show hidden Windows system files (default 0)
#   -hideextensions B  hide known extensions in the name (default 0)
#   -knownextensions L extensions (lower case, no dot) that count as known
#   -dirsfirst B       directories before files, also when sorted (default 1)
#   -timeformat F      clock format of the "Modified" column
#   -sizeunits N       1024 or 1000; default 1000 on macOS, else 1024
#   -filter G          one glob for file names ("" = all)
#   -filters L         several globs, a file matches any of them (0.3)
#   -onactivate S      script, appended the entry dict -- double-click/Return
#   -onselect  S       script, appended the entry dict -- selection change
#   -height N          visible rows (default 16)
#
# Hidden (0.3): an entry with the provider key "hidden" (the local provider
# sets it: Windows attribute, elsewhere the leading dot) is hidden when it is
# 1; without the key a leading dot decides. A Windows file that is hidden AND
# system ("protected system file", e.g. desktop.ini) needs -showsystem as
# well, as in the Explorer.
#
# Cells hold raw values, Tablelist formats them: size in bytes, mtime in epoch
# seconds (-1 for none), so a header click sorts by value, not by text. The
# entry dict of a row is a row attribute and travels with the row.

package require Tcl 8.6-
package require tkutils::tkuopts 0.1
package require Tk 8.6-
package require tkutils::tkutablelist
catch {package require msgcat}

namespace eval ::tkutils {}
namespace eval ::tkutils::tkufilelist {
    namespace export widget setDir dir refresh selectedEntry selectedEntries \
        setFilter setFilters columns setColumns view setView allColumns \
        setShowHidden setHideExtensions
    variable state
    # every column the list knows, in the default order of a new list
    variable allColumns {name mtime type size ext}
    variable defaultColumns {name mtime type size}
    variable knownExtensions {
        txt md csv tsv log ini cfg conf json xml html htm css js
        pdf doc docx odt rtf xls xlsx ods ppt pptx odp
        png jpg jpeg gif bmp tif tiff svg ico webp
        zip 7z rar tar gz tgz bz2 xz
        mp3 wav ogg flac mp4 avi mkv mov
        exe msi dll bat cmd ps1 sh
        tcl tm py c h db sqlite
    }
}

proc ::tkutils::tkufilelist::_ {s args} {
    if {[llength [info commands ::msgcat::mc]]} {
        return [::msgcat::mc $s {*}$args]
    }
    if {[llength $args]} { return [format $s {*}$args] }
    return $s
}

proc ::tkutils::tkufilelist::_platform {} {
    if {$::tcl_platform(platform) eq "windows"} { return windows }
    if {![catch {tk windowingsystem} ws] && $ws eq "aqua"} { return macos }
    return unix
}

proc ::tkutils::tkufilelist::_title {key} {
    switch -- $key {
        name  { return [_ Name] }
        mtime { return [_ Modified] }
        type  { return [_ Type] }
        size  { return [_ Size] }
        ext   { return [_ Extension] }
    }
    return $key
}

proc ::tkutils::tkufilelist::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUFILELIST $reason] $msg
}

# Check a column list: known keys, no duplicates, name added in front when
# missing.
proc ::tkutils::tkufilelist::_checkColumns {cols} {
    variable allColumns
    set out {}
    foreach c $cols {
        if {$c ni $allColumns} {
            _err COLUMN "unknown column \"$c\"\nKnown: $allColumns"
        }
        if {$c ni $out} { lappend out $c }
    }
    if {"name" ni $out} { set out [linsert $out 0 name] }
    return $out
}

proc ::tkutils::tkufilelist::widget {path args} {
    variable state
    variable defaultColumns
    variable knownExtensions
    array set o [list \
        -provider "" -dir "" -show "" -files 1 -columns $defaultColumns \
        -columnmenu 1 -showhidden 0 -showsystem 0 -hideextensions 0 \
        -knownextensions $knownExtensions -dirsfirst 1 \
        -timeformat "%d.%m.%Y %H:%M" -sizeunits "" \
        -filter "" -filters {} -onactivate "" -onselect "" -height 16]
    array set o [::tkutils::tkuopts::merge TKUFILELIST [array get o] $args]
    if {$o(-show) eq ""} { set o(-show) [expr {$o(-files) ? "both" : "dirs"}] }
    if {$o(-show) ni {both files dirs}} {
        _err VALUE "bad -show \"$o(-show)\": must be both, files or dirs"
    }
    if {$o(-sizeunits) eq ""} {
        set o(-sizeunits) [expr {[_platform] eq "macos" ? 1000 : 1024}]
    }
    if {$o(-sizeunits) ni {1000 1024}} {
        _err VALUE "bad -sizeunits \"$o(-sizeunits)\": must be 1000 or 1024"
    }
    set cols [_checkColumns $o(-columns)]
    if {$o(-provider) eq ""} {
        package require tclutils::tuprovider
        set o(-provider) [::tclutils::tuprovider open local]
        set state($path,ownprov) 1
    } else {
        set state($path,ownprov) 0
    }
    if {$o(-dir) eq ""} { set o(-dir) "/" }
    set filters $o(-filters)
    if {![llength $filters] && $o(-filter) ne ""} { set filters [list $o(-filter)] }

    set state($path,prov)    $o(-provider)
    set state($path,dir)     $o(-dir)
    set state($path,show)    $o(-show)
    set state($path,hidden)  $o(-showhidden)
    set state($path,system)  $o(-showsystem)
    set state($path,hideext) $o(-hideextensions)
    set state($path,known)   [lmap e $o(-knownextensions) {string tolower [string trimleft $e .]}]
    set state($path,dirsfirst) $o(-dirsfirst)
    set state($path,timefmt) $o(-timeformat)
    set state($path,units)   $o(-sizeunits)
    set state($path,filters) $filters
    set state($path,onact)   $o(-onactivate)
    set state($path,onsel)   $o(-onselect)
    set state($path,sortcol) ""      ;# column key the user sorted by, "" = name order
    set state($path,sortorder) increasing

    # Every known column exists in the table, in the order: the shown ones
    # as given, then the others hidden. So a column can be switched on later
    # without rebuilding the table.
    variable allColumns
    set order $cols
    foreach c $allColumns { if {$c ni $order} { lappend order $c } }
    set spec {}
    foreach c $order {
        lappend spec [expr {$c eq "size" ? [list [_title $c] -align right] : [_title $c]}]
    }
    ::tkutils::tkutablelist::widget $path \
        -columns $spec \
        -selectcommand [list ::tkutils::tkufilelist::_onselect $path] \
        -doublecommand [list ::tkutils::tkufilelist::_onactivate $path]
    set tbl [::tkutils::tkutablelist::tableWidget $path]
    $tbl configure -height $o(-height)
    set i 0
    foreach c $order {
        $tbl columnconfigure $i -name $c -hide [expr {$c ni $cols}]
        switch -- $c {
            size  {
                $tbl columnconfigure $i -sortmode integer \
                    -formatcommand [list ::tkutils::tkufilelist::_fmtSize $path]
            }
            mtime {
                $tbl columnconfigure $i -sortmode integer \
                    -formatcommand [list ::tkutils::tkufilelist::_fmtTime $path]
            }
            default { $tbl columnconfigure $i -sortmode dictionary }
        }
        incr i
    }
    $tbl configure -labelcommand [list ::tkutils::tkufilelist::_sortClick $path] \
        -labelcommand2 {}
    if {$o(-columnmenu)} {
        bind [$tbl labeltag] <Button-3> [list ::tkutils::tkufilelist::_columnMenu $path %X %Y]
        if {[tk windowingsystem] eq "aqua"} {
            bind [$tbl labeltag] <Button-2> [list ::tkutils::tkufilelist::_columnMenu $path %X %Y]
            bind [$tbl labeltag] <Control-Button-1> [list ::tkutils::tkufilelist::_columnMenu $path %X %Y]
        }
    }
    bind $path <Destroy> [list ::tkutils::tkufilelist::_cleanup $path %W]

    _fill $path
    return $path
}

proc ::tkutils::tkufilelist::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    if {[info exists state($path,ownprov)] && $state($path,ownprov)} {
        catch {$state($path,prov) destroy}
    }
    array unset state $path,*
}

# Is the entry hidden from view with the current settings?
proc ::tkutils::tkufilelist::_isHidden {path e} {
    variable state
    if {[dict exists $e hidden]} {
        set hidden [dict get $e hidden]
    } else {
        set hidden [string match .* [dict get $e name]]
    }
    if {!$hidden} { return 0 }
    if {!$state($path,hidden)} { return 1 }
    set system [expr {[dict exists $e system] && [dict get $e system]}]
    return [expr {$system && !$state($path,system)}]
}

proc ::tkutils::tkufilelist::_ext {name} {
    set x [file extension $name]
    if {$x eq "" || $x eq $name} { return "" }   ;# ".profile" has no extension
    return [string tolower [string range $x 1 end]]
}

# The row cells for one entry, in the order of allColumns' keys (dict).
proc ::tkutils::tkufilelist::_cells {path e} {
    variable state
    set name [dict get $e name]
    set isdir [expr {[dict get $e type] eq "dir"}]
    set ext [expr {$isdir ? "" : [_ext $name]}]
    set shown $name
    if {!$isdir && $state($path,hideext) && $ext ne "" && $ext in $state($path,known)} {
        set shown [string range $name 0 end-[expr {[string length $ext] + 1}]]
    }
    set size [expr {[dict exists $e size] ? [dict get $e size] : ""}]
    if {$isdir || ![string is integer -strict $size]} { set size -1 }
    set mtime [expr {[dict exists $e mtime] ? [dict get $e mtime] : ""}]
    if {![string is integer -strict $mtime]} { set mtime -1 }
    if {$isdir} {
        set type [_ Folder]
    } elseif {$ext ne ""} {
        set type [_ "%s file" [string toupper $ext]]
    } else {
        set type [_ File]
    }
    return [dict create name $shown mtime $mtime type $type size $size ext $ext]
}

# Re-read the current directory through the provider and rebuild the rows.
proc ::tkutils::tkufilelist::_fill {path} {
    variable state
    set prov $state($path,prov)
    set tbl [::tkutils::tkutablelist::tableWidget $path]
    set keep [lmap e [selectedEntries $path] {dict get $e path}]
    ::tkutils::tkutablelist::clear $path

    set dirs {}
    set files {}
    foreach e [$prov list $state($path,dir)] {
        set name [dict get $e name]
        if {$name in {. ..}} continue
        if {[_isHidden $path $e]} continue
        if {[dict get $e type] eq "dir"} {
            if {$state($path,show) ne "files"} { lappend dirs [list $name $e] }
        } elseif {$state($path,show) ne "dirs"} {
            # the filters narrow files, never directories: navigation stays
            # possible while filtering
            if {[llength $state($path,filters)]} {
                set hit 0
                foreach g $state($path,filters) {
                    if {$g eq "" || [string match -nocase $g $name]} { set hit 1; break }
                }
                if {!$hit} continue
            }
            lappend files [list $name $e]
        }
    }
    set dirs  [lsort -index 0 -dictionary $dirs]
    set files [lsort -index 0 -dictionary $files]
    set entries [lmap p [concat $dirs $files] {lindex $p 1}]
    _insert $path $entries
    if {$state($path,sortcol) ne ""} { _resort $path }
    _reselect $path $keep
    return
}

# Insert entries in this order, entry dict as row attribute.
proc ::tkutils::tkufilelist::_insert {path entries} {
    set tbl [::tkutils::tkutablelist::tableWidget $path]
    set n [$tbl columncount]
    set rows {}
    foreach e $entries {
        set cells [_cells $path $e]
        set row {}
        for {set c 0} {$c < $n} {incr c} {
            lappend row [dict get $cells [$tbl columncget $c -name]]
        }
        lappend rows $row
    }
    set first [$tbl size]
    $tbl insertlist end $rows
    set i $first
    foreach e $entries {
        $tbl rowattrib $i entry $e
        incr i
    }
}

proc ::tkutils::tkufilelist::_reselect {path paths} {
    if {![llength $paths]} return
    set tbl [::tkutils::tkutablelist::tableWidget $path]
    for {set i 0} {$i < [$tbl size]} {incr i} {
        if {[dict get [$tbl rowattrib $i entry] path] in $paths} {
            $tbl selection set $i
        }
    }
}

# Sort by the user's column, then put directories first again (-dirsfirst).
# Tablelist's sortbycolumn keeps the arrow in the header; a sort over two
# columns would show a rank number next to it.
proc ::tkutils::tkufilelist::_resort {path} {
    variable state
    set tbl [::tkutils::tkutablelist::tableWidget $path]
    set col [$tbl columnindex $state($path,sortcol)]
    $tbl sortbycolumn $col -$state($path,sortorder)
    if {!$state($path,dirsfirst)} return
    set dirs {}
    set files {}
    set sorted 1
    set seenFile 0
    for {set i 0} {$i < [$tbl size]} {incr i} {
        set e [$tbl rowattrib $i entry]
        if {[dict get $e type] eq "dir"} {
            if {$seenFile} { set sorted 0 }
            lappend dirs [list [$tbl get $i] $e]
        } else {
            set seenFile 1
            lappend files [list [$tbl get $i] $e]
        }
    }
    if {$sorted} return
    set keep [lmap e [selectedEntries $path] {dict get $e path}]
    $tbl delete 0 end
    set all [concat $dirs $files]
    $tbl insertlist end [lmap p $all {lindex $p 0}]
    set i 0
    foreach p $all { $tbl rowattrib $i entry [lindex $p 1]; incr i }
    _reselect $path $keep
}

proc ::tkutils::tkufilelist::_sortClick {path tbl col} {
    variable state
    set key [$tbl columncget $col -name]
    if {$state($path,sortcol) eq $key && $state($path,sortorder) eq "increasing"} {
        set state($path,sortorder) decreasing
    } else {
        set state($path,sortorder) increasing
    }
    set state($path,sortcol) $key
    _resort $path
}

# --- formatting -----------------------------------------------------------

proc ::tkutils::tkufilelist::_fmtSize {path bytes} {
    variable state
    if {$bytes < 0} { return "" }
    return [_humanSize $bytes $state($path,units)]
}

proc ::tkutils::tkufilelist::_fmtTime {path secs} {
    variable state
    if {$secs < 0} { return "" }
    return [clock format $secs -format $state($path,timefmt)]
}

# Human-readable size; "" stays "". units 1024 (KB, Windows) or 1000 (kB,
# macOS).
proc ::tkutils::tkufilelist::_humanSize {bytes {units 1024}} {
    if {$bytes eq "" || ![string is integer -strict $bytes]} { return "" }
    set names [expr {$units == 1000 ? {B kB MB GB TB} : {B KB MB GB TB}}]
    set n $bytes ; set i 0
    while {$n >= $units && $i < [llength $names]-1} {
        set n [expr {$n / double($units)}] ; incr i
    }
    if {$i == 0} { return "$bytes B" }
    return [format "%.1f %s" $n [lindex $names $i]]
}

# --- columns and view -----------------------------------------------------

proc ::tkutils::tkufilelist::allColumns {} {
    variable allColumns
    return $allColumns
}

# The shown columns, in display order.
proc ::tkutils::tkufilelist::columns {path} {
    set tbl [::tkutils::tkutablelist::tableWidget $path]
    set out {}
    for {set i 0} {$i < [$tbl columncount]} {incr i} {
        if {![$tbl columncget $i -hide]} { lappend out [$tbl columncget $i -name] }
    }
    return $out
}

# Show exactly these columns, in this order (name is always shown).
proc ::tkutils::tkufilelist::setColumns {path cols} {
    set cols [_checkColumns $cols]
    set tbl [::tkutils::tkutablelist::tableWidget $path]
    set target 0
    foreach c $cols {
        set i [$tbl columnindex $c]
        if {$i != $target} { $tbl movecolumn $i $target }
        incr target
    }
    for {set i 0} {$i < [$tbl columncount]} {incr i} {
        $tbl columnconfigure $i -hide [expr {[$tbl columncget $i -name] ni $cols}]
    }
    return
}

proc ::tkutils::tkufilelist::_toggleColumn {path key} {
    set cols [columns $path]
    if {$key in $cols} {
        set cols [lsearch -all -inline -not -exact $cols $key]
    } else {
        lappend cols $key
    }
    setColumns $path $cols
}

proc ::tkutils::tkufilelist::_columnMenu {path X Y} {
    variable state
    variable allColumns
    set m $path.colmenu
    catch {destroy $m}
    menu $m -tearoff 0
    set shown [columns $path]
    foreach c $allColumns {
        set state($path,menu,$c) [expr {$c in $shown}]
        $m add checkbutton -label [_title $c] \
            -variable ::tkutils::tkufilelist::state($path,menu,$c) \
            -command [list ::tkutils::tkufilelist::_toggleColumn $path $c] \
            -state [expr {$c eq "name" ? "disabled" : "normal"}]
    }
    tk_popup $m $X $Y
}

# The view as a dict: columns showhidden hideextensions sortcolumn sortorder.
# For saving and restoring the user's choice (tkufiledialog -app).
proc ::tkutils::tkufilelist::view {path} {
    variable state
    return [dict create columns [columns $path] showhidden $state($path,hidden) \
        hideextensions $state($path,hideext) \
        sortcolumn $state($path,sortcol) sortorder $state($path,sortorder)]
}

# Apply a view dict (keys as from view; missing keys are left alone) and
# refill. An unknown column in a saved view is dropped, not an error.
proc ::tkutils::tkufilelist::setView {path view} {
    variable state
    variable allColumns
    if {[dict exists $view columns]} {
        set cols [lmap c [dict get $view columns] {expr {$c in $allColumns ? $c : [continue]}}]
        if {[llength $cols]} { setColumns $path $cols }
    }
    foreach {k s} {showhidden hidden hideextensions hideext} {
        if {[dict exists $view $k] && [string is boolean -strict [dict get $view $k]]} {
            set state($path,$s) [expr {[dict get $view $k] ? 1 : 0}]
        }
    }
    if {[dict exists $view sortcolumn]} {
        set c [dict get $view sortcolumn]
        set state($path,sortcol) [expr {$c in $allColumns ? $c : ""}]
    }
    if {[dict exists $view sortorder] && [dict get $view sortorder] in {increasing decreasing}} {
        set state($path,sortorder) [dict get $view sortorder]
    }
    _fill $path
}

# Switch hidden entries or extensions on or off and refill (0.3).
proc ::tkutils::tkufilelist::setShowHidden {path flag} {
    variable state
    set state($path,hidden) [expr {$flag ? 1 : 0}]
    _fill $path
}
proc ::tkutils::tkufilelist::setHideExtensions {path flag} {
    variable state
    set state($path,hideext) [expr {$flag ? 1 : 0}]
    _fill $path
}

# --- directory and filter -------------------------------------------------

proc ::tkutils::tkufilelist::setDir {path dir} {
    variable state
    set state($path,dir) $dir
    _fill $path
    return
}

proc ::tkutils::tkufilelist::refresh {path} { _fill $path }

# One glob, case-insensitive; "" shows all files.
proc ::tkutils::tkufilelist::setFilter {path glob} {
    variable state
    set state($path,filters) [expr {$glob eq "" ? {} : [list $glob]}]
    _fill $path
}

# Several globs; a file shows when it matches any of them; {} shows all (0.3).
proc ::tkutils::tkufilelist::setFilters {path globs} {
    variable state
    set state($path,filters) $globs
    _fill $path
}

proc ::tkutils::tkufilelist::dir {path} {
    variable state
    return $state($path,dir)
}

# --- selection and callbacks ----------------------------------------------

proc ::tkutils::tkufilelist::selectedEntry {path} {
    set sel [::tkutils::tkutablelist::selection $path]
    if {![llength $sel]} { return "" }
    return [_entryAt $path [lindex $sel 0]]
}

proc ::tkutils::tkufilelist::selectedEntries {path} {
    set out {}
    foreach idx [::tkutils::tkutablelist::selection $path] {
        set e [_entryAt $path $idx]
        if {$e ne ""} { lappend out $e }
    }
    return $out
}

proc ::tkutils::tkufilelist::_entryAt {path idx} {
    if {[catch {[::tkutils::tkutablelist::tableWidget $path] rowattrib $idx entry} e]} {
        return ""
    }
    return $e
}

proc ::tkutils::tkufilelist::_onselect {path args} {
    variable state
    if {$state($path,onsel) eq ""} return
    set e [selectedEntry $path]
    if {$e ne ""} { uplevel #0 [linsert $state($path,onsel) end $e] }
}

proc ::tkutils::tkufilelist::_onactivate {path args} {
    variable state
    if {$state($path,onact) eq ""} return
    set e [selectedEntry $path]
    if {$e ne ""} { uplevel #0 [linsert $state($path,onact) end $e] }
}

package provide tkutils::tkufilelist 0.3
