# tkutils::tkufiletree -- a lazy file-system tree built on tkutils::tkutree.
#
# Shows a directory hierarchy under a root. Subdirectories are populated on
# demand when expanded (no full filesystem walk). Files can be filtered by glob
# patterns; activating a file (double-click or Return) fires -onactivate with
# its full path. Tcl/Tk 8.6+ and 9.x.
#
#   set t [tkutils::tkufiletree::widget .t \
#             -root $dir -filter {*.png *.jpg *.gif} \
#             -onactivate {apply {p {puts "open $p"}}}]
#   pack $t -fill both -expand 1
#
# Options (widget):
#   -root dir        starting directory (default: current directory)
#   -filter {pat..}  glob patterns; only matching files are shown (dirs always).
#                    Empty = all files. Matching is case-insensitive.
#   -files 0|1       show files at all (default 1; 0 = directories only)
#   -showhidden 0|1  include dot-entries (default 0)
#   -onactivate cmd  called with the full path when a FILE is activated
#   -onselect cmd    called with the full path on selection change
#   -height n        visible rows (default 16)
#
# Item ids are the normalized full paths. The raw treeview is reachable via
# tkutils::tkufiletree::treeview for extra bindings or styling.

package require Tcl 8.6-
package require Tk 8.6-
package require tkutils::tkutree

namespace eval ::tkutils {}
namespace eval ::tkutils::tkufiletree {
    namespace export widget setRoot refresh selectedPath treeview root reveal up
    variable state
}

proc ::tkutils::tkufiletree::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkufiletree::widget {path args} {
    variable state
    array set o {
        -root "" -filter {} -files 1 -showhidden 0
        -onactivate "" -onselect "" -height 16 -isolatekeys 0
    }
    array set o $args
    if {$o(-root) eq ""} { set o(-root) [pwd] }

    # tree shell (frame + treeview + scrollbar) via tkutree
    ::tkutils::tkutree::widget $path -height $o(-height) \
        -command [list ::tkutils::tkufiletree::_onselect $path]

    set state($path,filter) $o(-filter)
    set state($path,files)  $o(-files)
    set state($path,hidden) $o(-showhidden)
    set state($path,onact)  $o(-onactivate)
    set state($path,onsel)  $o(-onselect)

    set tv [::tkutils::tkutree::treeview $path]
    bind $tv <<TreeviewOpen>> [list ::tkutils::tkufiletree::_expand $path]
    bind $tv <Double-1>       [list ::tkutils::tkufiletree::_activate $path]
    bind $tv <Return>         [list ::tkutils::tkufiletree::_activate $path]
    bind $tv <BackSpace>      [list ::tkutils::tkufiletree::up $path]
    if {$o(-isolatekeys)} {
        # keep keyboard navigation local to the tree: drop the toplevel bindtag
        # so the host application's global key bindings do not also fire here.
        bindtags $tv [list $tv [winfo class $tv] all]
    }
    # append (do not clobber tkutree's own <Destroy> cleanup)
    bind $path <Destroy> +[list ::tkutils::tkufiletree::_cleanup $path %W]

    setRoot $path $o(-root)
    return $path
}

# (Re)load the tree under a new root directory.
proc ::tkutils::tkufiletree::setRoot {path dir} {
    variable state
    set dir [file normalize $dir]
    set state($path,root) $dir
    array unset state $path,pop,*
    ::tkutils::tkutree::clear $path
    set tv [::tkutils::tkutree::treeview $path]
    set rid [_insertDir $path "" $dir $dir]   ;# root labelled with full path
    _populate $path $rid $dir
    $tv item $rid -open 1
    return
}

# Re-read the current root from disk.
proc ::tkutils::tkufiletree::refresh {path} {
    variable state
    if {[info exists state($path,root)]} { setRoot $path $state($path,root) }
    return
}

# Move the root up to its parent directory and reveal the previous root, so the
# user sees where they came from. No-op at a filesystem root.
proc ::tkutils::tkufiletree::up {path} {
    variable state
    if {![info exists state($path,root)]} { return }
    set cur    $state($path,root)
    set parent [file dirname $cur]
    if {$parent eq $cur} { return }
    setRoot $path $parent
    reveal  $path $cur
    return
}

# Full path of the current selection, or "".
proc ::tkutils::tkufiletree::selectedPath {path} {
    return [lindex [::tkutils::tkutree::selection $path] 0]
}

# Raw ttk::treeview window.
proc ::tkutils::tkufiletree::treeview {path} {
    return [::tkutils::tkutree::treeview $path]
}

# Current root directory.
proc ::tkutils::tkufiletree::root {path} {
    variable state
    return [expr {[info exists state($path,root)] ? $state($path,root) : ""}]
}

# Expand the chain down to $target (a path under the root) and select it. If the
# exact target is not a node (e.g. filtered out, or a chain link is missing),
# the deepest existing ancestor (its folder) is selected instead. Populates
# ancestor directories on the way and scrolls the result into view. Returns 1 if
# the exact target was selected, else 0. Never raises.
proc ::tkutils::tkufiletree::reveal {path target} {
    variable state
    if {![info exists state($path,root)]} { return 0 }
    set rootd  $state($path,root)
    set target [file normalize $target]
    set tv     [::tkutils::tkutree::treeview $path]
    if {![_isPop $path $rootd]} { _populate $path $rootd $rootd }
    if {$target ne $rootd} {
        set rp [file split $rootd]
        set tp [file split $target]
        if {[lrange $tp 0 [expr {[llength $rp] - 1}]] ne $rp} { return 0 }
        set parts [lrange $tp [llength $rp] end]
        set cur $rootd
        foreach part [lrange $parts 0 end-1] {
            set cur [file join $cur $part]
            if {![$tv exists $cur]} { break }
            if {![_isPop $path $cur]} { _populate $path $cur $cur }
            catch {$tv item $cur -open 1}
        }
    }
    # select the target, or fall back to the deepest existing ancestor
    set sel $target
    while {$sel ne "" && ![$tv exists $sel]} {
        set parent [file dirname $sel]
        if {$parent eq $sel} { set sel "" ; break }
        set sel $parent
    }
    if {$sel eq "" || ![$tv exists $sel]} { return 0 }
    catch {$tv selection set [list $sel]}
    catch {$tv see $sel}
    return [expr {$sel eq $target}]
}

# --- internals -------------------------------------------------------------

# True if directory node $id has been populated from disk.
proc ::tkutils::tkufiletree::_isPop {path id} {
    variable state
    return [expr {[info exists state($path,pop,$id)] && $state($path,pop,$id)}]
}

# Insert a directory node (id = full path) with a placeholder child so the
# expansion arrow is shown before the directory is populated.
proc ::tkutils::tkufiletree::_insertDir {path parent dir text} {
    set id [::tkutils::tkutree::insert $path $parent $text -id $dir]
    set tv [::tkutils::tkutree::treeview $path]
    $tv insert $id end -id "$dir\x00ph" -text ""
    return $id
}

# Replace a directory node's children with a fresh on-disk listing.
proc ::tkutils::tkufiletree::_populate {path id dir} {
    variable state
    set tv [::tkutils::tkutree::treeview $path]
    $tv delete [$tv children $id]
    foreach e [_scan $path $dir] {
        lassign $e type name full
        if {$type eq "dir"} {
            _insertDir $path $id $full $name
        } else {
            ::tkutils::tkutree::insert $path $id $name -id $full
        }
    }
    set state($path,pop,$id) 1
    return
}

# Directory listing as a sorted list of {type name fullpath}, directories first.
proc ::tkutils::tkufiletree::_scan {path dir} {
    variable state
    set all [glob -nocomplain -directory $dir -- *]
    if {$state($path,hidden)} {
        catch {lappend all {*}[glob -nocomplain -directory $dir -- .*]}
    }
    set dirs {}
    set files {}
    foreach f $all {
        set name [file tail $f]
        if {$name eq "." || $name eq ".."} { continue }
        if {!$state($path,hidden) && [string match ".*" $name]} { continue }
        if {[file isdirectory $f]} {
            lappend dirs [list dir $name $f]
        } elseif {$state($path,files) && [_matches $path $name]} {
            lappend files [list file $name $f]
        }
    }
    set dirs  [lsort -index 1 -dictionary $dirs]
    set files [lsort -index 1 -dictionary $files]
    return [concat $dirs $files]
}

# True if $name passes the configured glob filter (empty filter = all).
proc ::tkutils::tkufiletree::_matches {path name} {
    variable state
    set filt $state($path,filter)
    if {![llength $filt]} { return 1 }
    foreach pat $filt {
        if {[string match -nocase $pat $name]} { return 1 }
    }
    return 0
}

# <<TreeviewOpen>>: populate the opened directory if not done yet.
proc ::tkutils::tkufiletree::_expand {path} {
    variable state
    set tv [::tkutils::tkutree::treeview $path]
    set id [$tv focus]
    if {$id eq ""} { return }
    if {[info exists state($path,pop,$id)] && $state($path,pop,$id)} { return }
    if {[file isdirectory $id]} { _populate $path $id $id }
    return
}

# Double-click / Return: fire -onactivate for files; leave directories to the
# treeview's own open/close handling.
proc ::tkutils::tkufiletree::_activate {path} {
    variable state
    set id [lindex [::tkutils::tkutree::selection $path] 0]
    if {$id eq "" || [file isdirectory $id]} { return }
    if {$state($path,onact) ne ""} {
        uplevel #0 [linsert $state($path,onact) end $id]
    }
    return
}

# tkutree selection callback -> -onselect with the full path.
proc ::tkutils::tkufiletree::_onselect {path sel} {
    variable state
    set id [lindex $sel 0]
    if {$id eq "" || $state($path,onsel) eq ""} { return }
    uplevel #0 [linsert $state($path,onsel) end $id]
    return
}

package provide tkutils::tkufiletree 0.1
