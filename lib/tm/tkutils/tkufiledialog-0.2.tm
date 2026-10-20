# tkutils::tkufiledialog -- modal file / directory picker (provider-backed)
# Description: modal open/save/directory dialogs on top of tkufilelist
# Category: Tk · widgets
#
# First stand (0.1): same look as the explorer stack (tkupath + tkufilelist),
# local provider by default, optional -provider for ZIP/remote later. Returns
# a path (or list of paths with -multiple), or "" if cancelled. Not a full
# file manager -- a compact modal chooser.
#
#   set f [::tkutils::tkufiledialog::open -parent . -title "Open" \
#       -initialdir [pwd] -filetypes {{Text {.txt}} {All *}}]
#   set d [::tkutils::tkufiledialog::directory -parent . -initialdir /tmp]
#   set s [::tkutils::tkufiledialog::save -parent . -initialfile out.txt]

package require Tcl 8.6-
package require Tk 8.6-
package require tkutils::tkuopts 0.1
package require tkutils::tkufilelist 0.2
package require tkutils::tkupath 0.2
catch {package require msgcat}

namespace eval ::tkutils {}
namespace eval ::tkutils::tkufiledialog {
    namespace export open save directory
    variable state
    variable counter 0
    variable commonOpts {
        -parent "" -title "" -initialdir "" -provider ""
        -filetypes {} -multiple 0 -showhidden 0
    }
}

proc ::tkutils::tkufiledialog::_ {s} {
    if {[llength [info commands ::msgcat::mc]]} {
        return [::msgcat::mc $s]
    }
    return $s
}

proc ::tkutils::tkufiledialog::_opts {defaults args} {
    if {[llength $args] % 2} {
        return -code error -errorcode {TKUTILS TKUFILEDIALOG OPTION} \
            "missing value for option \"[lindex $args end]\""
    }
    set o $defaults
    foreach {k v} $args {
        if {![dict exists $defaults $k]} {
            return -code error -errorcode [list TKUTILS TKUFILEDIALOG OPTION $k] \
                "unknown option \"$k\"\nKnown: [join [dict keys $defaults] { }]"
        }
        dict set o $k $v
    }
    return $o
}

proc ::tkutils::tkufiledialog::_parent {p} {
    if {$p ne ""} {
        if {![winfo exists $p]} {
            return -code error -errorcode [list TKUTILS TKUFILEDIALOG PARENT $p] \
                "bad window path name \"$p\" given as -parent"
        }
        return [winfo toplevel $p]
    }
    set f [focus]
    if {$f ne "" && [winfo exists $f]} { return [winfo toplevel $f] }
    if {[winfo exists .]} { return . }
    return ""
}

proc ::tkutils::tkufiledialog::_newName {} {
    variable counter
    return ".tkufiledialog[incr counter]"
}

proc ::tkutils::tkufiledialog::_defaultDir {dir} {
    if {$dir ne "" && [file isdirectory $dir]} {
        return [file normalize $dir]
    }
    if {[info exists ::env(HOME)] && $::env(HOME) ne "" \
            && [file isdirectory $::env(HOME)]} {
        return [file normalize $::env(HOME)]
    }
    return [file normalize [pwd]]
}

# Map -filetypes {{Label {.ext .EXT}} {All *}} to combobox labels + globs.
proc ::tkutils::tkufiledialog::_parseTypes {filetypes} {
    set labels {}
    set globs {}
    foreach ft $filetypes {
        set lab [lindex $ft 0]
        set pats [lindex $ft 1]
        if {$pats eq "" || $pats eq "*"} {
            lappend labels $lab
            lappend globs ""
            continue
        }
        set glist {}
        foreach p $pats {
            if {$p eq "*"} {
                set glist {}
                break
            }
            if {![string match .* $p] && ![string match *.* $p]} {
                set p .$p
            }
            if {[string match .* $p]} {
                lappend glist *$p
            } else {
                lappend glist $p
            }
        }
        lappend labels $lab
        if {![llength $glist]} {
            lappend globs ""
        } else {
            # one glob for tkufilelist::setFilter (first pattern; multi-ext later)
            lappend globs [lindex $glist 0]
        }
    }
    if {![llength $labels]} {
        return [list [list [_ {All files}]] [list ""]]
    }
    return [list $labels $globs]
}

proc ::tkutils::tkufiledialog::_choose {win id} {
    variable state
    if {[info exists state($win,result)]} {
        set state($win,result) $id
    }
}

proc ::tkutils::tkufiledialog::_goto {win dir} {
    variable state
    if {$dir eq ""} return
    set prov $state($win,prov)
    if {[catch {$prov list $dir}]} return
    set state($win,dir) $dir
    ::tkutils::tkufilelist::setDir $state($win,list) $dir
    catch {::tkutils::tkupath::setPath $state($win,path) $dir}
    if {$state($win,mode) eq "save" && [winfo exists $win.name]} {
        # keep typed name
    } elseif {[winfo exists $win.name]} {
        $win.name delete 0 end
    }
}

proc ::tkutils::tkufiledialog::_onActivate {win entry} {
    if {$entry eq ""} return
    if {[dict get $entry type] eq "dir"} {
        _goto $win [dict get $entry path]
        return
    }
    if {$::tkutils::tkufiledialog::state($win,mode) eq "directory"} {
        return
    }
    if {[winfo exists $win.name]} {
        $win.name delete 0 end
        $win.name insert 0 [dict get $entry name]
    }
    # Through _finishOk, like OK and <Return>: it sets state(value). A bare
    # "_choose ok" closed the dialog with an empty result -- a double-click
    # on a file returned "" (found 2026-10-20 while checking the book).
    _finishOk $win
}

proc ::tkutils::tkufiledialog::_onSelect {win entry} {
    variable state
    if {$entry eq "" || ![winfo exists $win.name]} return
    if {$state($win,mode) eq "directory"} {
        if {[dict get $entry type] eq "dir"} {
            $win.name delete 0 end
            $win.name insert 0 [dict get $entry name]
        }
        return
    }
    if {[dict get $entry type] eq "file"} {
        $win.name delete 0 end
        $win.name insert 0 [dict get $entry name]
    }
}

proc ::tkutils::tkufiledialog::_onType {win} {
    variable state
    if {![winfo exists $win.type]} return
    set i [$win.type current]
    if {$i < 0} return
    set glob [lindex $state($win,globs) $i]
    ::tkutils::tkufilelist::setFilter $state($win,list) $glob
}

proc ::tkutils::tkufiledialog::_join {dir name} {
    if {$name eq ""} { return $dir }
    if {[file pathtype $name] ne "relative"} { return [file normalize $name] }
    return [file normalize [file join $dir $name]]
}

proc ::tkutils::tkufiledialog::_collect {win} {
    variable state
    set mode $state($win,mode)
    set dir $state($win,dir)
    set lst $state($win,list)

    if {$mode eq "directory"} {
        set e [::tkutils::tkufilelist::selectedEntry $lst]
        if {$e ne "" && [dict get $e type] eq "dir"} {
            return [dict get $e path]
        }
        return $dir
    }

    if {$state($win,multiple) && $mode eq "open"} {
        set paths {}
        foreach e [::tkutils::tkufilelist::selectedEntries $lst] {
            if {[dict get $e type] eq "file"} {
                lappend paths [dict get $e path]
            }
        }
        if {[llength $paths]} { return $paths }
        set name ""
        if {[winfo exists $win.name]} {
            set name [string trim [$win.name get]]
        }
        if {$name ne ""} {
            return [list [_join $dir $name]]
        }
        return {}
    }

    set name ""
    if {[winfo exists $win.name]} {
        set name [string trim [$win.name get]]
    }
    if {$name eq ""} {
        set e [::tkutils::tkufilelist::selectedEntry $lst]
        if {$e ne "" && [dict get $e type] eq "file"} {
            return [dict get $e path]
        }
        return ""
    }
    set path [_join $dir $name]
    if {$mode eq "save" && $state($win,defext) ne "" \
            && [file extension $path] eq ""} {
        set path "$path$state($win,defext)"
    }
    return $path
}

proc ::tkutils::tkufiledialog::_finishOk {win} {
    variable state
    set path [_collect $win]
    if {$path eq "" || $path eq {}} {
        return
    }
    set state($win,value) $path
    _choose $win ok
}

# Core modal dialog. mode = open|save|directory
proc ::tkutils::tkufiledialog::_run {mode args} {
    variable state
    variable commonOpts
    set defaults $commonOpts
    dict set defaults -initialfile ""
    dict set defaults -defaultextension ""
    array set o [_opts $defaults {*}$args]

    set parent [_parent $o(-parent)]
    set dir [_defaultDir $o(-initialdir)]
    set prov $o(-provider)
    if {$prov eq ""} {
        package require tclutils::tuprovider
        set prov [::tclutils::tuprovider open local]
        set ownProv 1
    } else {
        set ownProv 0
    }

    set title $o(-title)
    if {$title eq ""} {
        switch -- $mode {
            open      { set title [_ Open] }
            save      { set title [_ Save] }
            directory { set title [_ {Choose folder}] }
        }
    }

    set win [_newName]
    toplevel $win
    wm title $win $title
    if {$parent ne "" && $parent ne $win && [winfo viewable $parent]} {
        wm transient $win $parent
    }
    wm minsize $win 420 320
    set state($win,result) ""
    set state($win,value) ""
    set state($win,mode) $mode
    set state($win,prov) $prov
    set state($win,ownProv) $ownProv
    set state($win,dir) $dir
    set state($win,multiple) [expr {$mode eq "open" && $o(-multiple)}]
    set state($win,defext) $o(-defaultextension)

    ttk::frame $win.body -padding 8
    pack $win.body -fill both -expand 1

    ::tkutils::tkupath::widget $win.path -rootlabel / \
        -onnavigate [list ::tkutils::tkufiledialog::_goto $win]
    pack $win.path -in $win.body -side top -fill x -pady {0 6}
    set state($win,path) $win.path
    ::tkutils::tkupath::setPath $win.path $dir

    set showFiles [expr {$mode ne "directory"}]
    ::tkutils::tkufilelist::widget $win.list -provider $prov -dir $dir \
        -files $showFiles -showhidden $o(-showhidden) -height 14 \
        -onactivate [list ::tkutils::tkufiledialog::_onActivate $win] \
        -onselect [list ::tkutils::tkufiledialog::_onSelect $win]
    # extended vs browse
    if {$state($win,multiple)} {
        catch {$win.list.tbl configure -selectmode extended}
    } else {
        catch {$win.list.tbl configure -selectmode browse}
    }
    pack $win.list -in $win.body -side top -fill both -expand 1
    set state($win,list) $win.list

    ttk::frame $win.row -padding {0 6 0 0}
    pack $win.row -in $win.body -side top -fill x
    ttk::label $win.row.l -text [_ Name]
    ttk::entry $win.name
    pack $win.row.l -side left -padx {0 6}
    pack $win.name -in $win.row -side left -fill x -expand 1
    if {$mode eq "save" && $o(-initialfile) ne ""} {
        $win.name insert 0 $o(-initialfile)
    }
    if {$mode eq "directory"} {
        $win.row.l configure -text [_ Folder]
        $win.name insert 0 [file tail $dir]
        $win.name state readonly
    }
    bind $win.name <Return> [list ::tkutils::tkufiledialog::_finishOk $win]

    lassign [_parseTypes $o(-filetypes)] labels globs
    set state($win,globs) $globs
    if {$mode ne "directory" && [llength $labels]} {
        ttk::frame $win.trow -padding {0 4 0 0}
        pack $win.trow -in $win.body -side top -fill x
        ttk::label $win.trow.l -text [_ Type]
        ttk::combobox $win.type -state readonly -values $labels
        pack $win.trow.l -side left -padx {0 6}
        pack $win.type -in $win.trow -side left -fill x -expand 1
        $win.type current 0
        bind $win.type <<ComboboxSelected>> \
            [list ::tkutils::tkufiledialog::_onType $win]
        _onType $win
    }

    ttk::frame $win.btns -padding {0 10 0 0}
    pack $win.btns -in $win.body -side bottom -fill x
    ttk::button $win.btns.cancel -text [_ Cancel] \
        -command [list ::tkutils::tkufiledialog::_choose $win cancel]
    ttk::button $win.btns.ok -text [_ OK] -default active \
        -command [list ::tkutils::tkufiledialog::_finishOk $win]
    pack $win.btns.cancel -side right -padx 4
    pack $win.btns.ok -side right
    bind $win <Escape> [list ::tkutils::tkufiledialog::_choose $win cancel]
    wm protocol $win WM_DELETE_WINDOW \
        [list ::tkutils::tkufiledialog::_choose $win cancel]

    # Place roughly over parent
    update idletasks
    set w [winfo reqwidth $win]
    set h [winfo reqheight $win]
    if {$w < 480} { set w 480 }
    if {$h < 360} { set h 360 }
    if {$parent ne "" && [winfo exists $parent] && [winfo viewable $parent]} {
        set x [expr {[winfo rootx $parent] + ([winfo width $parent] - $w) / 2}]
        set y [expr {[winfo rooty $parent] + ([winfo height $parent] - $h) / 2}]
    } else {
        set x [expr {([winfo screenwidth $win] - $w) / 2}]
        set y [expr {([winfo screenheight $win] - $h) / 2}]
    }
    if {$x < 0} { set x 0 }
    if {$y < 0} { set y 0 }
    wm geometry $win ${w}x${h}+$x+$y

    set prevFocus [focus]
    set prevGrab ""
    catch {set prevGrab [grab current $win]}
    catch {grab set $win}
    if {$mode eq "save"} {
        focus $win.name
        $win.name selection range 0 end
    } else {
        focus $win.btns.ok
    }

    vwait ::tkutils::tkufiledialog::state($win,result)
    set ok [expr {[info exists state($win,result)] && $state($win,result) eq "ok"}]
    set value ""
    if {$ok && [info exists state($win,value)]} {
        set value $state($win,value)
    }
    catch {grab release $win}
    if {$prevGrab ne "" && [winfo exists $prevGrab]} {
        catch {grab set $prevGrab}
    }
    if {$prevFocus ne "" && [winfo exists $prevFocus]} {
        catch {focus $prevFocus}
    }
    if {$ownProv} { catch {$prov destroy} }
    array unset state $win,*
    catch {destroy $win}
    return $value
}

proc ::tkutils::tkufiledialog::open {args} {
    return [_run open {*}$args]
}

proc ::tkutils::tkufiledialog::save {args} {
    return [_run save {*}$args]
}

proc ::tkutils::tkufiledialog::directory {args} {
    return [_run directory {*}$args]
}

package provide tkutils::tkufiledialog 0.2
