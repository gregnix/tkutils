# tkutils::tkufiledialog -- modal file / directory picker (provider-backed)
# Description: modal open/save/directory dialogs on top of tkufilelist
# Category: Tk · widgets
#
# Same look as the explorer stack (tkupath + tkufilelist), local provider by
# default, optional -provider for ZIP/remote. Returns a path (or list of paths
# with -multiple), or "" if cancelled. Not a full file manager -- a compact
# modal chooser.
#
# 0.3: columns (name, modified, type, size, extension) with a menu on the
# header, "Show hidden files" in the dialog, hidden files as the system
# defines them, several extensions per file type. On the left "Places":
# home and user folders, drives (Windows), bookmarks and recent folders.
# With -app NAME the dialog remembers, per application, its bookmarks, the
# recent folders, the last folder, the view and its size in the config
# directory of NAME (tclutils::tusettings: filedialog.ini and
# filedialog-dirs.txt). Without -app nothing is written.
#
#   set f [::tkutils::tkufiledialog::open -parent . -title "Open" \
#       -initialdir [pwd] -filetypes {{Text {.txt}} {All *}}]
#   set d [::tkutils::tkufiledialog::directory -parent . -initialdir /tmp]
#   set s [::tkutils::tkufiledialog::save -parent . -initialfile out.txt]

package require Tcl 8.6-
package require Tk 8.6-
package require tkutils::tkuopts 0.1
package require tkutils::tkufilelist 0.3
package require tkutils::tkupath 0.2
package require tclutils::tusettings 0.2
catch {package require msgcat}

namespace eval ::tkutils {}
namespace eval ::tkutils::tkufiledialog {
    namespace export open save directory bookmarks setBookmarks
    variable state
    variable counter 0
    variable commonOpts {
        -parent "" -title "" -initialdir "" -provider ""
        -filetypes {} -multiple 0 -showhidden 0
        -columns {} -showsystem 0 -hideextensions 0 -timeformat ""
        -app "" -places 1
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
            lappend globs {}
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
        # 0.3: all patterns (tkufilelist::setFilters); 0.2 used only the first
        lappend globs $glist
    }
    if {![llength $labels]} {
        return [list [list [_ {All files}]] [list {}]]
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
    ::tkutils::tkufilelist::setFilters $state($win,list) [lindex $state($win,globs) $i]
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

# --- settings per application (-app) ---------------------------------------
#
# filedialog.ini in the config directory of the application:
#   [view]       columns showhidden hideextensions sortcolumn sortorder
#   [window]     width height lastdir
#   [bookmarks]  1 = {label path}, 2 = ...   (order as shown)
# filedialog-dirs.txt: the recent folders (tusettings recent list).

proc ::tkutils::tkufiledialog::_load {app} {
    if {$app eq ""} { return {} }
    if {[catch {::tclutils::tusettings::load $app -name filedialog} s]} {
        return {}   ;# an unreadable file must not stop the dialog
    }
    return $s
}

proc ::tkutils::tkufiledialog::_save {win} {
    variable state
    set app $state($win,app)
    if {$app eq ""} return
    set s $state($win,settings)
    dict set s view [::tkutils::tkufilelist::view $state($win,list)]
    if {[winfo exists $win]} {
        dict set s window width [winfo width $win]
        dict set s window height [winfo height $win]
    }
    dict unset s bookmarks
    dict set s bookmarks {}
    set i 0
    foreach b $state($win,bookmarks) {
        dict set s bookmarks [incr i] $b
    }
    catch {::tclutils::tusettings::save $app $s -name filedialog}
}

# bookmarks of the application, as list of {label path}
proc ::tkutils::tkufiledialog::bookmarks {app} {
    set s [_load $app]
    set out {}
    if {[dict exists $s bookmarks]} {
        foreach k [lsort -integer [lmap k [dict keys [dict get $s bookmarks]] \
                {expr {[string is integer -strict $k] ? $k : [continue]}}]] {
            set b [dict get $s bookmarks $k]
            if {[llength $b] == 2} { lappend out $b }
        }
    }
    return $out
}

# Replace the bookmarks of the application (list of {label path}).
proc ::tkutils::tkufiledialog::setBookmarks {app list} {
    if {$app eq ""} { return }
    set s [_load $app]
    dict set s bookmarks {}
    set i 0
    foreach b $list { dict set s bookmarks [incr i] [lrange $b 0 1] }
    ::tclutils::tusettings::save $app $s -name filedialog
    return
}

# --- places ------------------------------------------------------------------

# The user folders that exist: list of {label path}. On Linux the names come
# from ~/.config/user-dirs.dirs (XDG), so "Schreibtisch" is found too.
proc ::tkutils::tkufiledialog::_userDirs {} {
    set home ""
    foreach v {HOME USERPROFILE} {
        if {[info exists ::env($v)] && [file isdirectory $::env($v)]} {
            set home [file normalize $::env($v)]
            break
        }
    }
    if {$home eq ""} { return {} }
    set dirs [dict create Desktop Desktop Documents Documents Downloads Downloads]
    set xdg [file join $home .config user-dirs.dirs]
    if {[info exists ::env(XDG_CONFIG_HOME)] && $::env(XDG_CONFIG_HOME) ne ""} {
        set xdg [file join $::env(XDG_CONFIG_HOME) user-dirs.dirs]
    }
    if {$::tcl_platform(platform) eq "windows"} {
        # moved folders (OneDrive, another drive) are only in the registry
        dict for {label p} [_winShellFolders] { dict set dirs $label $p }
    }
    if {$::tcl_platform(platform) eq "unix" && [file readable $xdg]} {
        set fh [::open $xdg r]   ;# "open" here is the dialog
        fconfigure $fh -encoding utf-8
        set text [read $fh]
        close $fh
        foreach {key label} {DESKTOP Desktop DOCUMENTS Documents DOWNLOAD Downloads} {
            if {[regexp -line "^XDG_${key}_DIR=\"(\[^\"\]*)\"" $text -> p]} {
                set p [string map [list \$HOME $home] $p]
                dict set dirs $label [file normalize $p]
            }
        }
    }
    set out [list [list [_ Home] $home]]
    dict for {label p} $dirs {
        if {[file pathtype $p] eq "relative"} { set p [file join $home $p] }
        if {[file normalize $p] ne $home && [file isdirectory $p]} {
            lappend out [list [_ $label] [file normalize $p]]
        }
    }
    return $out
}

# %NAME% in a registry value (REG_EXPAND_SZ) from the environment; an
# unknown name stays as it is.
proc ::tkutils::tkufiledialog::_expandEnv {s} {
    set out ""
    while {[regexp -indices {%([^%]+)%} $s all name]} {
        set n [string range $s {*}$name]
        append out [string range $s 0 [lindex $all 0]-1]
        if {[info exists ::env($n)]} {
            append out $::env($n)
        } else {
            append out [string range $s {*}$all]
        }
        set s [string range $s [lindex $all 1]+1 end]
    }
    return $out$s
}

# Windows: where Desktop, Documents and Downloads really are, from
# "User Shell Folders" (read only). A folder moved to OneDrive or another
# drive is not under the profile; 0.3 of 2026-11-13 looked there only. dict
# label -> path; empty when the registry cannot be read.
proc ::tkutils::tkufiledialog::_winShellFolders {} {
    set out [dict create]
    if {$::tcl_platform(platform) ne "windows" || [catch {package require registry}]} {
        return $out
    }
    set key {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders}
    foreach {value label} {
        Desktop Desktop Personal Documents
        {{374DE290-123F-4565-9164-39C4925E467B}} Downloads
    } {
        if {![catch {registry get $key $value} p] && $p ne ""} {
            set p [file normalize [_expandEnv $p]]
            if {[file isdirectory $p]} { dict set out $label $p }
        }
    }
    return $out
}

# Drives (Windows) or the file system root. Tcl 9 lists its virtual file
# system //zipfs:/ among the volumes; that is no drive (found 2026-11-14).
proc ::tkutils::tkufiledialog::_volumes {} {
    if {$::tcl_platform(platform) eq "windows"} {
        set out {}
        foreach v [file volumes] {
            if {[string match //* $v]} continue
            lappend out [list [string trimright $v /] $v]
        }
        return $out
    }
    return [list [list [_ Computer] /]]
}

proc ::tkutils::tkufiledialog::_isLocal {prov} {
    if {[catch {info object class $prov} cls]} { return 0 }
    return [expr {$cls eq "::tclutils::tuprovider::Local"}]
}

proc ::tkutils::tkufiledialog::_fillPlaces {win} {
    variable state
    set t $win.places
    if {![winfo exists $t]} return
    $t delete [$t children {}]
    set state($win,placeMap) {}
    $t insert {} end -id places -text [_ Places] -open 1
    foreach p [concat [_userDirs] [_volumes]] {
        lassign $p label path
        set id [$t insert places end -text $label]
        dict set state($win,placeMap) $id [list place $path]
    }
    if {$state($win,app) ne ""} {
        $t insert {} end -id bookmarks -text [_ Bookmarks] -open 1
        set i 0
        foreach b $state($win,bookmarks) {
            lassign $b label path
            set id [$t insert bookmarks end -text $label]
            dict set state($win,placeMap) $id [list bookmark $path $i]
            if {![file isdirectory $path]} { $t item $id -tags missing }
            incr i
        }
        set recent [::tclutils::tusettings::recentList $state($win,app) -list filedialog-dirs]
        if {[llength $recent]} {
            $t insert {} end -id recent -text [_ Recent] -open 1
            foreach path $recent {
                set id [$t insert recent end -text [file tail $path]]
                if {[file tail $path] eq ""} { $t item $id -text $path }
                dict set state($win,placeMap) $id [list recent $path]
                if {![file isdirectory $path]} { $t item $id -tags missing }
            }
        }
    }
    $t tag configure missing -foreground gray50
}

proc ::tkutils::tkufiledialog::_placeSelected {win} {
    variable state
    set t $win.places
    set id [lindex [$t selection] 0]
    if {$id eq "" || ![dict exists $state($win,placeMap) $id]} return
    set path [lindex [dict get $state($win,placeMap) $id] 1]
    if {![file isdirectory $path]} { bell; return }
    _goto $win $path
}

proc ::tkutils::tkufiledialog::_addBookmark {win {path ""}} {
    variable state
    if {$state($win,app) eq ""} return
    if {$path eq ""} { set path $state($win,dir) }
    if {[_isLocal $state($win,prov)]} { set path [file normalize $path] }
    foreach b $state($win,bookmarks) {
        if {[_samePath [lindex $b 1] $path]} return
    }
    set label [file tail $path]
    if {$label eq ""} { set label $path }
    lappend state($win,bookmarks) [list $label $path]
    _save $win
    _fillPlaces $win
}

# Same folder? Normalized, and on Windows without regard to case:
# C:\Daten and c:/daten are one bookmark.
proc ::tkutils::tkufiledialog::_samePath {a b} {
    catch {set a [file normalize $a]}
    catch {set b [file normalize $b]}
    if {$::tcl_platform(platform) eq "windows"} { return [string equal -nocase $a $b] }
    return [string equal $a $b]
}

proc ::tkutils::tkufiledialog::_removeBookmark {win index} {
    variable state
    set state($win,bookmarks) [lreplace $state($win,bookmarks) $index $index]
    _save $win
    _fillPlaces $win
}

proc ::tkutils::tkufiledialog::_renameBookmark {win index label} {
    variable state
    set label [string trim $label]
    if {$label eq ""} return
    lset state($win,bookmarks) $index 0 $label
    _save $win
    _fillPlaces $win
}

proc ::tkutils::tkufiledialog::_placeMenu {win x y X Y} {
    variable state
    set t $win.places
    set id [$t identify item $x $y]
    if {$id eq "" || ![dict exists $state($win,placeMap) $id]} return
    lassign [dict get $state($win,placeMap) $id] kind path index
    if {$kind ne "bookmark"} return
    $t selection set $id
    set m $win.placemenu
    catch {destroy $m}
    menu $m -tearoff 0
    $m add command -label [_ Rename...] -command [list ::tkutils::tkufiledialog::_renameAsk $win $index]
    $m add command -label [_ Remove] -command [list ::tkutils::tkufiledialog::_removeBookmark $win $index]
    tk_popup $m $X $Y
}

proc ::tkutils::tkufiledialog::_renameAsk {win index} {
    variable state
    set d $win.rename
    catch {destroy $d}
    toplevel $d
    wm title $d [_ {Rename bookmark}]
    wm transient $d $win
    set state($win,renameText) [lindex $state($win,bookmarks) $index 0]
    ttk::entry $d.e -width 32 -textvariable ::tkutils::tkufiledialog::state($win,renameText)
    ttk::frame $d.b
    ttk::button $d.b.ok -text [_ OK] -command [list ::tkutils::tkufiledialog::_renameDone $win $index 1]
    ttk::button $d.b.cancel -text [_ Cancel] -command [list ::tkutils::tkufiledialog::_renameDone $win $index 0]
    pack $d.e -fill x -padx 8 -pady 8
    pack $d.b -fill x -padx 8 -pady {0 8}
    pack $d.b.cancel $d.b.ok -side right -padx 2
    bind $d.e <Return> [list ::tkutils::tkufiledialog::_renameDone $win $index 1]
    bind $d <Escape> [list ::tkutils::tkufiledialog::_renameDone $win $index 0]
    $d.e selection range 0 end
    focus $d.e
    catch {grab set $d}
}

proc ::tkutils::tkufiledialog::_renameDone {win index ok} {
    variable state
    catch {grab release $win.rename}
    if {$ok} { _renameBookmark $win $index $state($win,renameText) }
    catch {destroy $win.rename}
    catch {grab set $win}
}

proc ::tkutils::tkufiledialog::_toggleHidden {win} {
    variable state
    ::tkutils::tkufilelist::setShowHidden $state($win,list) $state($win,showhidden)
}

# Core modal dialog. mode = open|save|directory
proc ::tkutils::tkufiledialog::_run {mode args} {
    variable state
    variable commonOpts
    set defaults $commonOpts
    dict set defaults -initialfile ""
    dict set defaults -defaultextension ""
    array set o [_opts $defaults {*}$args]
    if {$o(-app) ne ""} { ::tclutils::tusettings::dir config $o(-app) }   ;# checks the name

    set settings [_load $o(-app)]
    set parent [_parent $o(-parent)]
    set initial $o(-initialdir)
    if {$initial eq "" && [dict exists $settings window lastdir]} {
        set initial [dict get $settings window lastdir]
    }
    set dir [_defaultDir $initial]
    set prov $o(-provider)
    if {$prov eq ""} {
        package require tclutils::tuprovider
        set prov [::tclutils::tuprovider open local]
        set ownProv 1
    } else {
        set ownProv 0
        if {$o(-initialdir) ne ""} { set dir $o(-initialdir) }
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
    wm minsize $win 480 320
    set state($win,result) ""
    set state($win,value) ""
    set state($win,mode) $mode
    set state($win,prov) $prov
    set state($win,ownProv) $ownProv
    set state($win,dir) $dir
    set state($win,multiple) [expr {$mode eq "open" && $o(-multiple)}]
    set state($win,defext) $o(-defaultextension)
    set state($win,app) $o(-app)
    set state($win,settings) $settings
    set state($win,bookmarks) [expr {$o(-app) eq "" ? {} : [bookmarks $o(-app)]}]
    set state($win,placeMap) {}

    ttk::frame $win.body -padding 8
    pack $win.body -fill both -expand 1

    ::tkutils::tkupath::widget $win.path -rootlabel / \
        -onnavigate [list ::tkutils::tkufiledialog::_goto $win]
    pack $win.path -in $win.body -side top -fill x -pady {0 6}
    set state($win,path) $win.path
    ::tkutils::tkupath::setPath $win.path $dir

    # the lower rows first, so the list takes the rest of the height
    ttk::frame $win.btns -padding {0 10 0 0}
    pack $win.btns -in $win.body -side bottom -fill x

    lassign [_parseTypes $o(-filetypes)] labels globs
    set state($win,globs) $globs
    if {$mode ne "directory" && [llength $labels]} {
        ttk::frame $win.trow -padding {0 4 0 0}
        pack $win.trow -in $win.body -side bottom -fill x
        ttk::label $win.trow.l -text [_ Type]
        ttk::combobox $win.type -state readonly -values $labels
        pack $win.trow.l -side left -padx {0 6}
        pack $win.type -in $win.trow -side left -fill x -expand 1
    }
    ttk::frame $win.row -padding {0 6 0 0}
    pack $win.row -in $win.body -side bottom -fill x
    if {[winfo exists $win.trow]} { pack $win.row -before $win.trow }

    ttk::panedwindow $win.pw -orient horizontal
    pack $win.pw -in $win.body -side top -fill both -expand 1
    set usePlaces [expr {$o(-places) && [_isLocal $prov]}]
    if {$usePlaces} {
        ttk::frame $win.pl
        ttk::treeview $win.places -show tree -selectmode browse -height 10
        $win.places column #0 -width 170
        pack $win.places -in $win.pl -side top -fill both -expand 1
        if {$o(-app) ne ""} {
            ttk::button $win.addmark -text [_ {+ Bookmark this folder}] \
                -command [list ::tkutils::tkufiledialog::_addBookmark $win]
            pack $win.addmark -in $win.pl -side bottom -fill x -pady {4 0}
        }
        $win.pw add $win.pl -weight 0
        bind $win.places <<TreeviewSelect>> [list ::tkutils::tkufiledialog::_placeSelected $win]
        bind $win.places <Button-3> [list ::tkutils::tkufiledialog::_placeMenu $win %x %y %X %Y]
        if {[tk windowingsystem] eq "aqua"} {
            bind $win.places <Button-2> [list ::tkutils::tkufiledialog::_placeMenu $win %x %y %X %Y]
        }
    }

    set listOpts [list -provider $prov -dir $dir \
        -show [expr {$mode eq "directory" ? "dirs" : "both"}] \
        -showhidden $o(-showhidden) -showsystem $o(-showsystem) \
        -hideextensions $o(-hideextensions) -height 14 \
        -onactivate [list ::tkutils::tkufiledialog::_onActivate $win] \
        -onselect [list ::tkutils::tkufiledialog::_onSelect $win]]
    if {[llength $o(-columns)]} { lappend listOpts -columns $o(-columns) }
    if {$o(-timeformat) ne ""} { lappend listOpts -timeformat $o(-timeformat) }
    ::tkutils::tkufilelist::widget $win.list {*}$listOpts
    # the saved view wins over the defaults, the caller's options over both
    if {[dict exists $settings view]} {
        set v [dict get $settings view]
        if {[llength $o(-columns)]} { dict unset v columns }
        if {"-showhidden" in $args} { dict unset v showhidden }
        if {"-hideextensions" in $args} { dict unset v hideextensions }
        ::tkutils::tkufilelist::setView $win.list $v
    }
    if {$state($win,multiple)} {
        catch {$win.list.tbl configure -selectmode extended}
    } else {
        catch {$win.list.tbl configure -selectmode browse}
    }
    $win.pw add $win.list -weight 1
    set state($win,list) $win.list
    set state($win,showhidden) [dict get [::tkutils::tkufilelist::view $win.list] showhidden]
    if {$usePlaces} { _fillPlaces $win }

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

    if {[winfo exists $win.type]} {
        $win.type current 0
        bind $win.type <<ComboboxSelected>> \
            [list ::tkutils::tkufiledialog::_onType $win]
        _onType $win
    }

    ttk::checkbutton $win.btns.hidden -text [_ {Show hidden files}] \
        -variable ::tkutils::tkufiledialog::state($win,showhidden) \
        -command [list ::tkutils::tkufiledialog::_toggleHidden $win]
    pack $win.btns.hidden -side left
    ttk::button $win.btns.cancel -text [_ Cancel] \
        -command [list ::tkutils::tkufiledialog::_choose $win cancel]
    ttk::button $win.btns.ok -text [_ OK] -default active \
        -command [list ::tkutils::tkufiledialog::_finishOk $win]
    pack $win.btns.cancel -side right -padx 4
    pack $win.btns.ok -side right
    bind $win <Escape> [list ::tkutils::tkufiledialog::_choose $win cancel]
    wm protocol $win WM_DELETE_WINDOW \
        [list ::tkutils::tkufiledialog::_choose $win cancel]

    # Size: saved, else requested (at least 640x400); placed over the parent
    update idletasks
    set w [winfo reqwidth $win]
    set h [winfo reqheight $win]
    if {$w < 640} { set w 640 }
    if {$h < 400} { set h 400 }
    if {[dict exists $settings window width] && [string is integer -strict [dict get $settings window width]]} {
        set w [expr {max(480, [dict get $settings window width])}]
    }
    if {[dict exists $settings window height] && [string is integer -strict [dict get $settings window height]]} {
        set h [expr {max(320, [dict get $settings window height])}]
    }
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
    if {$state($win,app) ne "" && [_isLocal $prov]} {
        if {$ok} {
            dict set state($win,settings) window lastdir $state($win,dir)
            catch {::tclutils::tusettings::recentAdd $state($win,app) $state($win,dir) \
                -list filedialog-dirs -max 10}
        }
        _save $win
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

package provide tkutils::tkufiledialog 0.3
