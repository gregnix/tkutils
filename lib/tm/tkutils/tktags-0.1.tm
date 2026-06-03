# tkutils::tktags -- tag editor: tags shown as removable chips plus an input.
#
# Tags render as chips (label + "x" remove button). An input row (a combobox
# when -suggestions are given, otherwise an entry) adds new tags on Return or
# via the "+" button. Duplicates and blanks are ignored. With -readonly the
# input row and remove buttons are omitted. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tktags {
    namespace export widget getTags setTags addTag removeTag clear
    variable state
}

proc ::tkutils::tktags::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Build the tag editor under $path.
# Options: -tags list, -suggestions list, -textvariable var (mirrors the tag
# list), -readonly bool, -command cmd (called with the tag list on change).
proc ::tkutils::tktags::widget {path args} {
    variable state
    array set opts {-tags {} -suggestions {} -textvariable "" -readonly 0 -command ""}
    array set opts $args

    ttk::frame $path
    set state($path,tags) {}
    set state($path,cmd) ""
    set state($path,var) $opts(-textvariable)
    set state($path,readonly) [expr {$opts(-readonly) ? 1 : 0}]
    bind $path <Destroy> [list ::tkutils::tktags::_cleanup $path %W]

    ttk::frame $path.c
    grid $path.c -sticky ew
    grid columnconfigure $path 0 -weight 1

    if {!$state($path,readonly)} {
        ttk::frame $path.in
        if {[llength $opts(-suggestions)] > 0} {
            ttk::combobox $path.in.e -values $opts(-suggestions) -width 18
        } else {
            ttk::entry $path.in.e -width 18
        }
        ttk::button $path.in.add -text "+" -width 2 \
            -command [list ::tkutils::tktags::_addFromEntry $path]
        grid $path.in.e $path.in.add -sticky ew -padx {0 2}
        grid columnconfigure $path.in 0 -weight 1
        grid $path.in -sticky ew -pady {4 0}
        bind $path.in.e <Return> [list ::tkutils::tktags::_addFromEntry $path]
    }

    # initial tags: explicit -tags, else seed from -textvariable
    set init $opts(-tags)
    if {$init eq "" && $opts(-textvariable) ne ""} {
        upvar #0 $opts(-textvariable) ev
        if {[info exists ev]} { set init $ev }
    }
    setTags $path $init
    set state($path,cmd) $opts(-command)
    return $path
}

# --- public API ----------------------------------------------------------

proc ::tkutils::tktags::getTags {path} {
    variable state
    return $state($path,tags)
}

proc ::tkutils::tktags::setTags {path tags} {
    variable state
    set clean {}
    foreach t $tags {
        set t [string trim $t]
        if {$t ne "" && $t ni $clean} { lappend clean $t }
    }
    set state($path,tags) $clean
    _render $path
    _notify $path
    return $clean
}

proc ::tkutils::tktags::addTag {path tag} {
    variable state
    set tag [string trim $tag]
    if {$tag eq "" || $tag in $state($path,tags)} { return $state($path,tags) }
    lappend state($path,tags) $tag
    _render $path
    _notify $path
    return $state($path,tags)
}

proc ::tkutils::tktags::removeTag {path tag} {
    variable state
    set i [lsearch -exact $state($path,tags) $tag]
    if {$i < 0} { return $state($path,tags) }
    set state($path,tags) [lreplace $state($path,tags) $i $i]
    _render $path
    _notify $path
    return $state($path,tags)
}

proc ::tkutils::tktags::clear {path} {
    return [setTags $path {}]
}

# --- internals -----------------------------------------------------------

proc ::tkutils::tktags::_addFromEntry {path} {
    set e $path.in.e
    addTag $path [$e get]
    $e delete 0 end
}

proc ::tkutils::tktags::_notify {path} {
    variable state
    if {$state($path,var) ne ""} {
        upvar #0 $state($path,var) ev
        set ev $state($path,tags)
    }
    if {$state($path,cmd) ne ""} {
        uplevel #0 [linsert $state($path,cmd) end $state($path,tags)]
    }
}

proc ::tkutils::tktags::_render {path} {
    variable state
    set c $path.c
    foreach ch [winfo children $c] { destroy $ch }
    set i 0
    foreach t $state($path,tags) {
        set chip $c.t$i
        ttk::frame $chip -relief solid -borderwidth 1 -padding {4 1}
        ttk::label $chip.l -text $t
        if {$state($path,readonly)} {
            grid $chip.l -sticky w
        } else {
            ttk::label $chip.x -text "\u00d7" -cursor hand2
            bind $chip.x <Button-1> [list ::tkutils::tktags::removeTag $path $t]
            grid $chip.l $chip.x -sticky w -padx {0 2}
        }
        grid $chip -row 0 -column $i -sticky w -padx 2
        incr i
    }
}

package provide tkutils::tktags 0.1
