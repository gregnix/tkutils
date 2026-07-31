# tkutils::tkulauncher -- an application launcher widget (ttk).
#
# A cross-platform (Windows and Linux) launcher, in two shapes from one widget:
#
#   menu  -- a ttk::menubutton with nested cascades (a "Start" menu)
#   list  -- a vertical column of ttk::buttons (a launcher panel)
#
# Entries can start a program, open a URL, or open a file/folder. URLs and
# files/folders are opened with the OS default via tclutils::tuopen
# (xdg-open / open / cmd start), so nothing here is tied to a desktop
# environment -- unlike a raw exo-open/xfce launcher, this works the same on
# Windows and Linux.
#
# Entries come from a Tcl spec (-items) or a file (-file, .json or .ini), parsed
# through tclutils engines (tujson / tuini). Model (parsing, launching) lives in
# tclutils; this is just the View.
#
#   ::tkutils::tkulauncher::widget .l -mode menu -text Start -items $spec
#   ::tkutils::tkulauncher::widget .l -mode list -file menu.json
#
# Entry spec: a list of dicts, each with a "type":
#   {type app   label L cmd  {prog arg ...}}   run a program (background)
#   {type url   label L target URL}            open a URL (OS default)
#   {type open  label L target PATH}           open a file/folder (OS default)
#   {type separator}                            a divider
#   {type menu  label L items {...}}           a submenu (menu mode) or a
#                                               section header + its items (list)

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuopen

namespace eval ::tkutils {}
namespace eval ::tkutils::tkulauncher {
    namespace export widget load resolve reload editConfig openLocation \
        resolveSystem systemItems systemIds systemTitle available showCalendar showCalculator \
        saveEntries editEntries
    variable state
}

# Build a launcher at $path. Options:
#   -mode   menu|list           (default list)
#   -text   label               menubutton text in menu mode (default "Start")
#   -items  spec                entry spec (a Tcl list of dicts)
#   -file   path                load the spec from a .json or .ini file
#   -onlaunch script            optional; appended {kind argv} before launching,
#                               for logging/testing. Return a false value to
#                               suppress the actual launch.
proc ::tkutils::tkulauncher::widget {path args} {
    variable state
    array set o {-mode list -text Start -items {} -file "" -onlaunch "" \
                 -settings 0 -system 0 -scroll 0 -height 400 -tooltips 0 \
                 -columns 1 -editable 0}
    array set o $args

    set items $o(-items)
    if {$o(-file) ne ""} { set items [load $o(-file)] }

    set state($path,onlaunch) $o(-onlaunch)
    set state($path,mode)     $o(-mode)
    set state($path,file)     $o(-file)
    set state($path,settings) $o(-settings)
    set state($path,system)   $o(-system)
    set state($path,scroll)   $o(-scroll)
    set state($path,tooltips) $o(-tooltips)
    set state($path,columns)  $o(-columns)
    set state($path,editable) $o(-editable)
    set state($path,items)    $items

    if {$o(-mode) eq "menu"} {
        ttk::menubutton $path -text $o(-text)
        set m [menu $path.menu -tearoff 0]
        $path configure -menu $m
    } elseif {$o(-scroll)} {
        # a scrollable button column: buttons go into the scrolledframe's content
        package require tkutils::tkuscrolledframe
        ttk::frame $path
        ::tkutils::tkuscrolledframe::widget $path.sf -height $o(-height)
        pack $path.sf -fill both -expand 1
        set state($path,content) [::tkutils::tkuscrolledframe::content $path.sf]
        # forward the mouse wheel to the scrollable frame, over the whole button
        # subtree, so scrolling works with the pointer anywhere in the panel --
        # and -dynamic keeps it covered when reload rebuilds the buttons.
        if {![catch {package require tkutils::tkuwheel}]} {
            set sf [::tkutils::tkuscrolledframe::scrollableframe $path.sf]
            catch {::tkutils::tkuwheel::redirect $sf $sf -orient y -dynamic 1}
        }
    } else {
        ttk::frame $path
        set state($path,content) $path
    }
    _populate $path
    if {$o(-editable)} { _bindEdit $path }
    bind $path <Destroy> [list ::tkutils::tkulauncher::_cleanup $path %W]
    return $path
}

# When -editable, a right-click anywhere on the launcher offers "Edit..." which
# opens the form editor. This is the way to edit a launcher built from -items
# (which has no Settings group). Bound on the whole subtree via a bindtag so it
# works over buttons and menus too.
proc ::tkutils::tkulauncher::_bindEdit {path} {
    variable state
    set menu $path._editmenu
    if {![winfo exists $menu]} {
        menu $menu -tearoff 0
        $menu add command -label "Edit..." \
            -command [list ::tkutils::tkulauncher::editEntries $path]
    }
    set state($path,editmenu) $menu
    # right-click (Button-3) pops it up; on macOS Button-2 is also common
    foreach seq {<Button-3> <Button-2>} {
        bind $path $seq [list ::tkutils::tkulauncher::_editPopup $path %X %Y]
    }
    # for menu mode, also bind the menubutton's menu is native; the widget itself
    # already receives Button-3. For list mode, buttons sit inside; add a class
    # binding so a right-click on a child button still opens the editor.
    _bindEditChildren $path
}

proc ::tkutils::tkulauncher::_bindEditChildren {path} {
    foreach seq {<Button-3> <Button-2>} {
        foreach w [_descendants $path] {
            bind $w $seq [list ::tkutils::tkulauncher::_editPopup $path %X %Y]
        }
    }
}

proc ::tkutils::tkulauncher::_descendants {w} {
    set out {}
    foreach c [winfo children $w] {
        lappend out $c
        lappend out {*}[_descendants $c]
    }
    return $out
}

proc ::tkutils::tkulauncher::_editPopup {path X Y} {
    variable state
    if {[info exists state($path,editmenu)] && [winfo exists $state($path,editmenu)]} {
        tk_popup $state($path,editmenu) $X $Y
    }
}

# (Re)fill the widget from state. Called at build time and by reload. If
# -settings is on and a config file is in use, a Settings group is appended:
# edit the config, open its folder, and reload.
proc ::tkutils::tkulauncher::_populate {path} {
    variable state
    set items $state($path,items)
    # optional System group: environment-aware tools (terminal, task manager,
    # printers, autostart, ...) that resolve to the right command per platform.
    if {[info exists state($path,system)] && $state($path,system)} {
        set sys [systemItems]
        if {[llength $sys]} {
            lappend items [dict create type separator]
            lappend items [dict create type menu label "System" items $sys]
        }
    }
    if {$state($path,settings) && $state($path,file) ne ""} {
        lappend items [dict create type separator]
        lappend items [dict create type menu label "Settings" items [list \
            [dict create type _edit     label "Edit menu (text)..."] \
            [dict create type _editform label "Edit menu (form)..."] \
            [dict create type _location label "Open file location"] \
            [dict create type _reload   label "Reload"] \
        ]]
    }
    if {$state($path,mode) eq "menu"} {
        $path.menu delete 0 end
        # delete leftover cascade submenu widgets, else _fillMenu's names collide
        foreach c [winfo children $path.menu] { destroy $c }
        _fillMenu $path $path.menu $items
    } else {
        set content [expr {[info exists state($path,content)] ? $state($path,content) : $path}]
        foreach c [winfo children $content] { destroy $c }
        _fillList $path $content $items 0
    }
    # re-apply right-click editing to freshly created child buttons
    if {[info exists state($path,editable)] && $state($path,editable)} {
        _bindEditChildren $path
    }
}

# Label for an entry: explicit -label, or the system title for a system entry.
proc ::tkutils::tkulauncher::_label {entry} {
    if {[dict exists $entry label]} { return [dict get $entry label] }
    if {[dict get $entry type] eq "system" && [dict exists $entry id]} {
        return [systemTitle [dict get $entry id]]
    }
    if {[dict get $entry type] eq "calendar"} { return "Calendar" }
    if {[dict get $entry type] eq "calc"} { return "Calculator" }
    if {[dict get $entry type] eq "tcl" && [dict exists $entry target]} {
        return [file tail [dict get $entry target]]
    }
    return "?"
}

# The image for an entry's optional -icon: an existing Tk image name is used as
# is; otherwise it is loaded from a file (png/gif/...) and cached per path so it
# is created once. Returns an image name, or "" if there is no icon or it fails
# to load (a missing icon is not an error -- the entry just shows text).
proc ::tkutils::tkulauncher::_icon {path entry} {
    variable state
    if {![dict exists $entry icon]} { return "" }
    set spec [dict get $entry icon]
    if {$spec eq ""} { return "" }
    # an already-created image?
    if {[lsearch -exact [image names] $spec] >= 0} { return $spec }
    if {![info exists state($path,icons)]} { set state($path,icons) [dict create] }
    if {[dict exists $state($path,icons) $spec]} {
        return [dict get $state($path,icons) $spec]
    }
    if {[catch {image create photo -file $spec} img]} { return "" }
    dict set state($path,icons) $spec $img
    return $img
}

# Whether an entry can actually be launched right now. For an app entry this
# means the program is found on PATH (auto_execok); url/open/system entries go
# through the OS opener and are always considered available. Used to grey out
# app entries whose program is not installed.
proc ::tkutils::tkulauncher::available {entry} {
    if {[dict get $entry type] ne "app"} { return 1 }
    if {![dict exists $entry cmd]} { return 0 }
    _progAvailable [lindex [dict get $entry cmd] 0] $::tcl_platform(platform)
}

# Whether a program can be launched. On PATH -> yes. On Windows, PATH is not the
# whole story: apps register under "App Paths" and are launched via 'start', so a
# bare name (e.g. firefox) is assumed launchable; only an explicit path that does
# not exist is treated as unavailable.
proc ::tkutils::tkulauncher::_progAvailable {prog platform} {
    if {[auto_execok $prog] ne ""} { return 1 }
    if {$platform eq "windows"} {
        if {[string match {*[/\\]*} $prog]} { return [file exists $prog] }
        return 1
    }
    return 0
}

# The tooltip text for an entry: an explicit -tooltip wins; otherwise, when the
# launcher has -tooltips on, one is derived from what the entry would do (the
# program+args, the URL/target, or the resolved system command). Returns "" for
# no tooltip.
proc ::tkutils::tkulauncher::_tooltip {path entry} {
    variable state
    if {[dict exists $entry tooltip]} { return [dict get $entry tooltip] }
    if {![info exists state($path,tooltips)] || !$state($path,tooltips)} { return "" }
    if {[catch {resolve $entry} act]} { return "" }
    switch -- [dict get $act kind] {
        exec { return [dict get $act argv] }
        open { return [lindex [dict get $act argv] 0] }
    }
    return ""
}

# ---- menu mode ------------------------------------------------------------
proc ::tkutils::tkulauncher::_fillMenu {path menu items} {
    set sub 0
    foreach e $items {
        set type [dict get $e type]
        switch -- $type {
            separator { $menu add separator }
            menu {
                set child [menu $menu.[incr sub] -tearoff 0]
                $menu add cascade -label [_label $e] -menu $child
                _fillMenu $path $child [dict get $e items]
            }
            default {
                set opts [list -label [_label $e] \
                    -command [list ::tkutils::tkulauncher::_activate $path $e]]
                set img [_icon $path $e]
                if {$img ne ""} { lappend opts -image $img -compound left }
                if {![available $e]} { lappend opts -state disabled }
                $menu add command {*}$opts
            }
        }
    }
}

# ---- list mode ------------------------------------------------------------
# Nested menus do not map to a flat button column, so a "menu" entry becomes a
# section header (a bold label) followed by its items, one level deep-flattened.
proc ::tkutils::tkulauncher::_fillList {path parent items depth} {
    variable state
    set cols [expr {[info exists state($path,columns)] ? $state($path,columns) : 1}]
    if {$cols <= 1} {
        _fillListPacked $path $parent $items
    } else {
        if {$depth == 0} { set state($path,grow) 0 ; set state($path,gcol) 0 }
        _fillListGrid $path $parent $items $cols
    }
}

# Build a launch button for an entry (label, icon, greying, tooltip).
proc ::tkutils::tkulauncher::_makeButton {path parent e} {
    set w $parent.i[incr ::tkutils::tkulauncher::_seq]
    ttk::button $w -text [_label $e] \
        -command [list ::tkutils::tkulauncher::_activate $path $e]
    set img [_icon $path $e]
    if {$img ne ""} { $w configure -image $img -compound left }
    if {![available $e]} { $w state disabled }
    set tip [_tooltip $path $e]
    if {$tip ne "" && ![catch {package require tkutils::tkuballoon}]} {
        catch {::tkutils::tkuballoon::add $w $tip}
    }
    return $w
}

# single-column: pack top (headers/separators span the width naturally)
proc ::tkutils::tkulauncher::_fillListPacked {path parent items} {
    foreach e $items {
        set w $parent.i[incr ::tkutils::tkulauncher::_seq]
        switch -- [dict get $e type] {
            separator {
                ttk::separator $w -orient horizontal
                pack $w -side top -fill x -padx 5 -pady 6
            }
            menu {
                ttk::label $w -text [_label $e] -anchor w -font TkHeadingFont
                pack $w -side top -fill x -padx 5 -pady {6 2}
                _fillListPacked $path $parent [dict get $e items]
            }
            default {
                set b [_makeButton $path $parent $e]
                pack $b -side top -fill x -padx 5 -pady 2
            }
        }
    }
}

# N-column: buttons flow left-to-right into a grid; headers and separators
# start a new row and span all columns.
proc ::tkutils::tkulauncher::_fillListGrid {path parent items cols} {
    variable state
    foreach e $items {
        set type [dict get $e type]
        switch -- $type {
            separator {
                _gridBreak $path
                set w $parent.i[incr ::tkutils::tkulauncher::_seq]
                ttk::separator $w -orient horizontal
                grid $w -row $state($path,grow) -column 0 -columnspan $cols \
                    -sticky ew -padx 5 -pady 6
                incr state($path,grow) ; set state($path,gcol) 0
            }
            menu {
                _gridBreak $path
                set w $parent.i[incr ::tkutils::tkulauncher::_seq]
                ttk::label $w -text [_label $e] -anchor w -font TkHeadingFont
                grid $w -row $state($path,grow) -column 0 -columnspan $cols \
                    -sticky ew -padx 5 -pady {6 2}
                incr state($path,grow) ; set state($path,gcol) 0
                _fillListGrid $path $parent [dict get $e items] $cols
            }
            default {
                set b [_makeButton $path $parent $e]
                grid $b -row $state($path,grow) -column $state($path,gcol) \
                    -sticky ew -padx 5 -pady 2
                incr state($path,gcol)
                if {$state($path,gcol) >= $cols} {
                    set state($path,gcol) 0 ; incr state($path,grow)
                }
            }
        }
    }
    for {set c 0} {$c < $cols} {incr c} {
        grid columnconfigure $parent $c -weight 1 -uniform lcol
    }
}

# start a fresh grid row if the current one is partly filled
proc ::tkutils::tkulauncher::_gridBreak {path} {
    variable state
    if {$state($path,gcol) > 0} { incr state($path,grow) ; set state($path,gcol) 0 }
}
namespace eval ::tkutils::tkulauncher { variable _seq 0 }

# ---- resolve + activate ---------------------------------------------------
# resolve turns an entry into an action WITHOUT performing it, so callers and
# tests can inspect what would run. Returns {kind K argv {...}} where kind is
# exec | open, or throws on a malformed entry. (open covers url and file/dir --
# both go through the OS default opener.)
# Tcl/Tk interpreters a "tcl" entry can be launched with. Each key maps to the
# executable name per platform. Override via setTclInterp if your names differ.
namespace eval ::tkutils::tkulauncher {
    variable tclInterp {
        wish9  {linux wish9.0   windows wish90.exe}
        wish8  {linux wish8.6   windows wish86t.exe}
        tclsh9 {linux tclsh9.0  windows tclsh90.exe}
        tclsh8 {linux tclsh8.6  windows tclsh86t.exe}
    }
}

# the interpreter keys, for the editor dropdown
proc ::tkutils::tkulauncher::tclInterpreters {} {
    variable tclInterp
    return [dict keys $tclInterp]
}

# override or add an interpreter mapping, e.g.
#   setTclInterp wish9 -linux /opt/tcl9/bin/wish9.0 -windows C:/Tcl/bin/wish90.exe
proc ::tkutils::tkulauncher::setTclInterp {key args} {
    variable tclInterp
    array set o {-linux "" -windows ""}
    array set o $args
    set cur [expr {[dict exists $tclInterp $key] ? [dict get $tclInterp $key] : {}}]
    if {$o(-linux)   ne ""} { dict set cur linux   $o(-linux) }
    if {$o(-windows) ne ""} { dict set cur windows $o(-windows) }
    dict set tclInterp $key $cur
}

# resolve an interpreter key to the executable for this platform
proc ::tkutils::tkulauncher::resolveTclInterp {key {platform ""}} {
    variable tclInterp
    if {$platform eq ""} { set platform $::tcl_platform(platform) }
    if {![dict exists $tclInterp $key]} { error "unknown interpreter: $key" }
    set m [dict get $tclInterp $key]
    set pk [expr {$platform eq "windows" ? "windows" : "linux"}]
    if {![dict exists $m $pk]} { error "interpreter '$key' has no $pk executable" }
    return [dict get $m $pk]
}

# Home directory and tilde expansion that work on both Tcl 8.6 and Tcl 9.
# Tcl 9 no longer expands ~ in file commands (file normalize ~ -> "/~"), so any
# path from a config that starts with ~ must be expanded explicitly.
proc ::tkutils::tkulauncher::homeDir {} {
    if {![catch {file home} h]} { return $h }          ;# Tcl 9
    if {[info exists ::env(HOME)]} { return $::env(HOME) }
    if {[info exists ::env(USERPROFILE)]} { return $::env(USERPROFILE) }  ;# Windows
    return [file normalize ~]                            ;# Tcl 8.6 fallback
}

proc ::tkutils::tkulauncher::expandTilde {path} {
    if {$path eq "~"} { return [homeDir] }
    if {[string match "~/*" $path]} {
        return [file join [homeDir] [string range $path 2 end]]
    }
    return $path
}

proc ::tkutils::tkulauncher::resolve {entry} {
    switch -- [dict get $entry type] {
        app - command {
            if {![dict exists $entry cmd]} { error "app entry has no cmd" }
            set act [dict create kind exec argv [dict get $entry cmd]]
            # optional working directory for the launched program
            if {[dict exists $entry dir] && [dict get $entry dir] ne ""} {
                dict set act dir [expandTilde [dict get $entry dir]]
            }
            # optional: run a CLI program inside a terminal window
            if {[dict exists $entry terminal] && [dict get $entry terminal]} {
                dict set act terminal 1
            }
            return $act
        }
        url {
            if {![dict exists $entry target]} { error "entry has no target" }
            return [dict create kind open argv [list [dict get $entry target]]]
        }
        open - file {
            if {![dict exists $entry target]} { error "entry has no target" }
            # expand a leading ~ (Tcl 9 no longer does this automatically)
            return [dict create kind open argv [list [expandTilde [dict get $entry target]]]]
        }
        system {
            if {![dict exists $entry id]} { error "system entry has no id" }
            return [resolveSystem [dict get $entry id]]
        }
        tcl {
            if {![dict exists $entry target]} { error "tcl entry has no target (script)" }
            set key [expr {[dict exists $entry interp] ? [dict get $entry interp] : "wish9"}]
            set exe [resolveTclInterp $key]
            set argv [linsert [expandTilde [dict get $entry target]] 0 $exe]
            # optional extra arguments to the script
            if {[dict exists $entry args] && [dict get $entry args] ne ""} {
                set argv [concat $argv [dict get $entry args]]
            }
            set act [dict create kind exec argv $argv]
            # optional TCLLIBPATH for the child (the essence of tcl8env/tcl9env);
            # set cross-platform in the child environment before exec
            if {[dict exists $entry tcllibpath] && [dict get $entry tcllibpath] ne ""} {
                set lp {}
                foreach d [dict get $entry tcllibpath] { lappend lp [expandTilde $d] }
                dict set act env [list TCLLIBPATH $lp]
            }
            if {[dict exists $entry dir] && [dict get $entry dir] ne ""} {
                dict set act dir [expandTilde [dict get $entry dir]]
            }
            # tclsh scripts are CLI: allow running inside a terminal window
            if {[dict exists $entry terminal] && [dict get $entry terminal]} {
                dict set act terminal 1
            }
            return $act
        }
        default { error "cannot launch entry of type [dict get $entry type]" }
    }
}

proc ::tkutils::tkulauncher::_activate {path entry} {
    variable state
    # built-in actions that act on this launcher, not on an external target
    switch -- [dict get $entry type] {
        _edit     { editConfig     $path ; return }
        _editform { editEntries    $path ; return }
        _location { openLocation   $path ; return }
        _reload   { reload         $path ; return }
        calendar  { showCalendar   $path ; return }
        calc      { showCalculator $path ; return }
    }
    if {[catch {resolve $entry} act]} {
        _error $path "Cannot launch '[_label $entry]':\n$act" ; return
    }
    # optional hook: {kind argv}; a false return suppresses the real launch
    if {$state($path,onlaunch) ne ""} {
        set go [uplevel #0 [list {*}$state($path,onlaunch) \
                    [dict get $act kind] [dict get $act argv]]]
        if {[string is boolean -strict $go] && !$go} return
    }
    if {[catch {_perform $act} e]} {
        _error $path "Could not launch '[_label $entry]':\n$e"
    }
}

# Wrap a command so it runs inside a terminal window (for CLI programs). On
# Windows: a new console via 'start ... cmd /k'. On unix: the desktop's terminal
# emulator (from the system catalogue) with -e (or -- for gnome-terminal). The
# unix working directory is handled by cd in _perform; on Windows /D is added.
proc ::tkutils::tkulauncher::_terminalCommand {argv dir platform desktop} {
    if {$platform eq "windows"} {
        set pre [list cmd.exe /c start ""]
        if {$dir ne ""} { lappend pre /D $dir }
        return [concat $pre [list cmd.exe /k] $argv]
    }
    set term [lindex [dict get \
        [resolveSystem terminal -platform unix -os Linux -desktop $desktop] argv] 0]
    if {$term eq "gnome-terminal"} {
        return [concat [list $term --] $argv]
    }
    return [concat [list $term -e] $argv]
}

# Build the exec argument list for an app launch. On Windows we go through
# 'start' so App Paths and file associations resolve (a program need not be on
# PATH) and /D sets the working directory; on unix the argv is used directly and
# the working directory is handled by cd in _perform.
proc ::tkutils::tkulauncher::_execCommand {argv dir platform} {
    if {$platform eq "windows"} {
        set pre [list cmd.exe /c start ""]
        if {$dir ne ""} { lappend pre /D $dir }
        return [concat $pre $argv]
    }
    return $argv
}

proc ::tkutils::tkulauncher::_perform {act} {
    switch -- [dict get $act kind] {
        exec {
            set argv [dict get $act argv]
            set dir  [expr {[dict exists $act dir] ? [dict get $act dir] : ""}]
            set inTerm [expr {[dict exists $act terminal] && [dict get $act terminal]}]
            set plat $::tcl_platform(platform)
            set desk [expr {[info exists ::env(XDG_CURRENT_DESKTOP)] ? $::env(XDG_CURRENT_DESKTOP) : ""}]
            # optional environment overrides (e.g. TCLLIBPATH for a tcl entry):
            # set them for the child, restore afterwards. exec inherits ::env.
            set envSaved {}
            set envHad {}
            if {[dict exists $act env]} {
                foreach {k v} [dict get $act env] {
                    if {[info exists ::env($k)]} {
                        lappend envSaved $k $::env($k) ; lappend envHad $k
                    } else {
                        lappend envSaved $k "" 
                    }
                    set ::env($k) $v
                }
            }
            set rc [catch {_performExec $argv $dir $inTerm $plat $desk} err]
            # restore environment
            foreach {k v} $envSaved {
                if {[lsearch -exact $envHad $k] >= 0} { set ::env($k) $v } else { unset -nocomplain ::env($k) }
            }
            if {$rc} { error $err }
        }
        open { ::tclutils::tuopen::launch [expandTilde [lindex [dict get $act argv] 0]] }
    }
}

# the actual exec, factored out so _perform can wrap it with env handling
proc ::tkutils::tkulauncher::_performExec {argv dir inTerm plat desk} {
            if {$inTerm} {
                # run inside a terminal window; _terminalCommand is platform-correct
                set full [_terminalCommand $argv $dir $plat $desk]
                if {$plat ne "windows" && $dir ne ""} {
                    set save [pwd]
                    if {[catch {cd [file normalize $dir]} e]} { error "cannot enter directory: $e" }
                    set rc [catch {exec {*}$full &} err] ; cd $save
                    if {$rc} { error $err }
                } else {
                    exec {*}$full &
                }
            } elseif {$plat eq "windows"} {
                # start handles App Paths, associations and (via /D) the cwd
                exec {*}[_execCommand $argv $dir windows] &
            } elseif {$dir ne ""} {
                # the child inherits the cwd at exec time: cd there and back
                set save [pwd]
                if {[catch {cd [file normalize $dir]} e]} {
                    error "cannot enter directory: $e"
                }
                set rc [catch {exec {*}$argv &} err]
                cd $save
                if {$rc} { error $err }
            } else {
                exec {*}$argv &
            }
}

proc ::tkutils::tkulauncher::_error {path msg} {
    if {[llength [info commands ::tkutils::tkudialog::showError]]} {
        ::tkutils::tkudialog::showError $msg
    } else {
        catch {tk_messageBox -icon error -message $msg}
    }
}

# ---- loading a spec from a file -------------------------------------------
# .json: an object {mode? items:[...]} or a bare array of entries.
# .ini : each [section] is a submenu; each key=value is an entry, the value's
#        first token picking the type (app:/url:/open:) else app by default.
proc ::tkutils::tkulauncher::load {file} {
    set ext [string tolower [file extension $file]]
    set ch [open $file r] ; fconfigure $ch -encoding utf-8
    set text [read $ch] ; close $ch
    switch -- $ext {
        .json { return [_loadJson $text] }
        .ini  { return [_loadIni  $text] }
        default { error "unsupported launcher file type: $ext (use .json or .ini)" }
    }
}

proc ::tkutils::tkulauncher::_loadJson {text} {
    package require tclutils::tujson
    set d [::tclutils::tujson::fromJson $text]
    # bare array -> the items; object -> its "items"
    if {[string index [string trimleft $text] 0] eq "\["} { return $d }
    if {[dict exists $d items]} { return [dict get $d items] }
    return {}
}

proc ::tkutils::tkulauncher::_loadIni {text} {
    package require tclutils::tuini
    set data [::tclutils::tuini::parse $text]
    set items {}
    foreach sec [::tclutils::tuini::sections $data] {
        if {$sec eq ""} continue
        set sub {}
        foreach k [::tclutils::tuini::keys $data $sec] {
            set v [::tclutils::tuini::get $data $sec $k]
            lappend sub [_iniEntry $k $v]
        }
        lappend items [dict create type menu label $sec items $sub]
    }
    return $items
}

# One "key = value" line -> an entry. A "type:" prefix on the value picks the
# type; otherwise it is a program to exec.
#   Firefox = app: firefox
#   Manual  = url: https://tcl.tk
#   Home    = open: /home/greg
proc ::tkutils::tkulauncher::_iniEntry {label value} {
    set value [string trim $value]
    if {[regexp {^(app|url|open|file|system)\s*:\s*(.*)$} $value -> t rest]} {
        set rest [string trim $rest]
        switch -- $t {
            app    { return [dict create type app    label $label cmd $rest] }
            system { return [dict create type system label $label id  $rest] }
            default { return [dict create type $t label $label target $rest] }
        }
    }
    return [dict create type app label $label cmd $value]
}

# ---- settings: edit the config, open its folder, reload -------------------
# Re-read the -file spec and rebuild the widget in place. No-op without a file.
proc ::tkutils::tkulauncher::reload {path} {
    variable state
    if {![info exists state($path,file)] || $state($path,file) eq ""} return
    if {[catch {load $state($path,file)} items]} {
        _error $path "Could not reload menu:\n$items" ; return
    }
    set state($path,items) $items
    _populate $path
}

# Open the config file in a text editor (EDITOR / notepad / open -e), via tuopen.
proc ::tkutils::tkulauncher::editConfig {path} {
    variable state
    set f [expr {[info exists state($path,file)] ? $state($path,file) : ""}]
    if {$f eq ""} { _error $path "No config file to edit (menu was built from a Tcl spec)." ; return }
    if {[catch {::tclutils::tuopen::edit $f} e]} {
        _error $path "Could not open editor:\n$e"
    }
}

# Open the folder containing the config file (or the cwd if built from a spec).
proc ::tkutils::tkulauncher::openLocation {path} {
    variable state
    set f [expr {[info exists state($path,file)] ? $state($path,file) : ""}]
    set target [expr {$f ne "" ? $f : [pwd]}]
    if {[catch {::tclutils::tuopen::openDir $target} e]} {
        _error $path "Could not open file location:\n$e"
    }
}

# ---- saving entries back to a file ----------------------------------------
# Save a flat list of entry dicts to a file, choosing the format by extension:
# .json (full fidelity) or .ini (flat, prefix form). Used by the form editor.
proc ::tkutils::tkulauncher::saveEntries {items file} {
    set ext [string tolower [file extension $file]]
    switch -- $ext {
        .json { set text [_entriesToJson $items] }
        .ini  { set text [_entriesToIni  $items] }
        default { error "unsupported launcher file type: $ext (use .json or .ini)" }
    }
    set ch [open $file w] ; fconfigure $ch -encoding utf-8
    puts $ch $text ; close $ch
    return $file
}

# entries -> a pretty JSON array, preserving every field
proc ::tkutils::tkulauncher::_entriesToJson {items} {
    package require tclutils::tujson
    set arr {}
    foreach e $items {
        set pairs {}
        dict for {k v} $e {
            if {$k eq "items"} {
                # nested submenu: recurse (build a typed array inline)
                set sub {}
                foreach se $v {
                    set sp {}
                    dict for {sk sv} $se { lappend sp $sk [::tclutils::tujson::str $sv] }
                    lappend sub [::tclutils::tujson::obj $sp]
                }
                lappend pairs $k [::tclutils::tujson::arr $sub]
            } else {
                lappend pairs $k [::tclutils::tujson::str $v]
            }
        }
        lappend arr [::tclutils::tujson::obj $pairs]
    }
    return [::tclutils::tujson::toJson [::tclutils::tujson::arr $arr] -indent 2]
}

# entries -> INI text. INI is a flat "Section / key = prefix: value" form, so
# each top-level menu becomes a section and its children become prefixed lines;
# non-menu top-level entries go under a "Launcher" section.
proc ::tkutils::tkulauncher::_entriesToIni {items} {
    package require tclutils::tuini
    set data [dict create]
    set flat {}
    foreach e $items {
        if {[dict get $e type] eq "menu" && [dict exists $e items]} {
            set sec [dict get $e label]
            set kv [dict create]
            foreach se [dict get $e items] {
                lassign [_iniLine $se] k v
                if {$k ne ""} { dict set kv $k $v }
            }
            dict set data $sec $kv
        } else {
            lassign [_iniLine $e] k v
            if {$k ne ""} { dict set flat $k $v }
        }
    }
    if {[dict size $flat]} { dict set data "Launcher" $flat }
    return [::tclutils::tuini::toIni $data]
}

# one entry -> {label "prefix: value"} for INI, or {"" ""} if it cannot be
# expressed flatly (separators, calendar, calc, nested menus)
proc ::tkutils::tkulauncher::_iniLine {e} {
    set label [_label $e]
    switch -- [dict get $e type] {
        app    { return [list $label "app: [dict get $e cmd]"] }
        url    { return [list $label "url: [dict get $e target]"] }
        open   { return [list $label "open: [dict get $e target]"] }
        file   { return [list $label "file: [dict get $e target]"] }
        system { return [list $label "system: [dict get $e id]"] }
        default { return [list "" ""] }
    }
}


# Pop up a calendar window. Uses the tkutils tkucal widget when available
# (month view with previous/next/today); otherwise a small dependency-free
# month grid drawn from Tcl's clock. One shared window is reused.
proc ::tkutils::tkulauncher::showCalendar {path} {
    set top .tkulauncher_calendar
    if {[winfo exists $top]} { raise $top ; focus $top ; return }
    toplevel $top
    wm title $top "Calendar"
    # stay above the launcher window (a satellite of it)
    catch {wm transient $top [winfo toplevel $path]}
    # richest first: tkutical (needs the external tical engine, adds week
    # numbers and holidays), then the dependency-free clickable tkucalendar,
    # then the text tkucal, then the built-in fallback grid.
    if {![catch {package require tkutils::tkutical}]} {
        ::tkutils::tkutical::widget $top.cal -view month -weeknumbers 1 -holidays de
        pack $top.cal -fill both -expand 1
    } elseif {![catch {package require tkutils::tkucalendar}]} {
        ::tkutils::tkucalendar::widget $top.cal
        pack $top.cal -fill both -expand 1
    } elseif {![catch {package require tkutils::tkucal}]} {
        ::tkutils::tkucal::widget $top.cal
        pack $top.cal -fill both -expand 1
    } else {
        _fallbackCalendar $top.cal
        pack $top.cal -fill both -expand 1
    }
    raise $top
    bind $top <Escape> [list destroy $top]
}

# A minimal month calendar using only clock: a header with prev/next/today and
# a Monday-first grid of the current month. No selection, just a view.
proc ::tkutils::tkulauncher::_fallbackCalendar {w} {
    variable state
    ttk::frame $w
    set state($w,ref) [clock seconds]
    ttk::frame $w.nav
    ttk::button $w.nav.prev  -text "<" -width 3 -command [list ::tkutils::tkulauncher::_calNav $w -1]
    ttk::label  $w.nav.title -anchor center
    ttk::button $w.nav.today -text "Today" -command [list ::tkutils::tkulauncher::_calNav $w 0]
    ttk::button $w.nav.next  -text ">" -width 3 -command [list ::tkutils::tkulauncher::_calNav $w 1]
    grid $w.nav.prev $w.nav.title $w.nav.today $w.nav.next -sticky ew -padx 2 -pady 2
    grid columnconfigure $w.nav 1 -weight 1
    pack $w.nav -fill x
    ttk::frame $w.grid
    pack $w.grid -fill both -expand 1
    _calDraw $w
    return $w
}

proc ::tkutils::tkulauncher::_calNav {w dir} {
    variable state
    if {$dir == 0} {
        set state($w,ref) [clock seconds]
    } else {
        # move roughly one month; snap to the first to avoid day overflow
        scan [clock format $state($w,ref) -format %Y] %d y
        scan [clock format $state($w,ref) -format %m] %d m
        incr m $dir
        if {$m < 1}  { set m 12 ; incr y -1 }
        if {$m > 12} { set m 1  ; incr y 1 }
        set state($w,ref) [clock scan [format "%04d-%02d-01" $y $m] -format %Y-%m-%d]
    }
    _calDraw $w
}

proc ::tkutils::tkulauncher::_calDraw {w} {
    variable state
    set g $w.grid
    foreach c [winfo children $g] { destroy $c }
    scan [clock format $state($w,ref) -format %Y] %d y
    scan [clock format $state($w,ref) -format %m] %d m
    $w.nav.title configure -text [clock format $state($w,ref) -format "%B %Y"]
    set col 0
    foreach d {Mo Tu We Th Fr Sa Su} {
        ttk::label $g.h$col -text $d -anchor center -font TkHeadingFont
        grid $g.h$col -row 0 -column $col -sticky ew -padx 1 -pady 1
        incr col
    }
    # weekday of the first (Monday=0)
    set first [clock scan [format "%04d-%02d-01" $y $m] -format %Y-%m-%d]
    scan [clock format $first -format %u] %d wd   ;# 1=Mon..7=Sun
    set start [expr {$wd - 1}]
    # days in month: go to next month day 0
    set nm [expr {$m + 1}] ; set ny $y
    if {$nm > 12} { set nm 1 ; incr ny }
    set last [clock add [clock scan [format "%04d-%02d-01" $ny $nm] -format %Y-%m-%d] -1 day]
    scan [clock format $last -format %d] %d ndays
    set today [clock format [clock seconds] -format %Y-%m-%d]
    set row 1 ; set col $start
    for {set day 1} {$day <= $ndays} {incr day} {
        set iso [format "%04d-%02d-%02d" $y $m $day]
        set lbl [ttk::label $g.d$day -text $day -anchor center -width 3]
        if {$iso eq $today} { $lbl configure -font TkHeadingFont }
        grid $g.d$day -row $row -column $col -sticky ew -padx 1 -pady 1
        incr col
        if {$col > 6} { set col 0 ; incr row }
    }
    for {set c 0} {$c < 7} {incr c} { grid columnconfigure $g $c -weight 1 -uniform cal }
}

# ---- built-in calculator --------------------------------------------------
# Pop up a calculator window using the tkutils tkucalc widget (with history).
# One shared window is reused. If tkucalc is unavailable, report it.
proc ::tkutils::tkulauncher::showCalculator {path} {
    set top .tkulauncher_calculator
    if {[winfo exists $top]} { raise $top ; focus $top ; return }
    if {[catch {package require tkutils::tkucalc}]} {
        _error $path "The calculator widget (tkutils::tkucalc) is not available."
        return
    }
    toplevel $top
    wm title $top "Calculator"
    # stay above the launcher window (a satellite of it)
    catch {wm transient $top [winfo toplevel $path]}
    ::tkutils::tkucalc::widget $top.calc -history 1
    pack $top.calc -fill both -expand 1
    raise $top
    bind $top <Escape> [list destroy $top]
}

# ---- form-based entry editor ----------------------------------------------
# Open an editor for a launcher's entries: a list on the left, a tkuform on the
# right. New/Delete manage the list; Apply copies the form into the selected
# entry; Save writes the file (JSON or INI by extension) and reloads the
# launcher. Needs tkutils::tkuform. If the launcher has a -file, that is the
# save target; otherwise Save asks via the file argument to saveEntries.
proc ::tkutils::tkulauncher::editEntries {path} {
    variable state
    if {[catch {package require tkutils::tkuform}]} {
        _error $path "The form widget (tkutils::tkuform) is not available."
        return
    }
    set top .tkulauncher_editor
    if {[winfo exists $top]} { raise $top ; focus $top ; return }
    toplevel $top
    wm title $top "Edit launcher"
    catch {wm transient $top [winfo toplevel $path]}

    # working copy of the entries (flat top level)
    set state($top,items)  [_editItems $path]
    set state($top,target) [expr {[info exists state($path,file)] ? $state($path,file) : ""}]
    set state($top,owner)  $path

    ttk::frame $top.l
    listbox $top.l.list -height 12 -exportselection 0 \
        -yscrollcommand [list $top.l.sb set]
    ttk::scrollbar $top.l.sb -orient vertical -command [list $top.l.list yview]
    grid $top.l.list $top.l.sb -sticky nsew
    grid rowconfigure $top.l 0 -weight 1
    grid columnconfigure $top.l 0 -weight 1
    ttk::frame $top.l.btn
    ttk::button $top.l.btn.new -text "New"    -command [list ::tkutils::tkulauncher::_edNew $top]
    ttk::button $top.l.btn.del -text "Delete" -command [list ::tkutils::tkulauncher::_edDel $top]
    grid $top.l.btn.new $top.l.btn.del -sticky ew -padx 2
    grid $top.l.btn -sticky ew -pady {4 0}
    # suggestions: a catalogue to pick from, and a one-click default set
    ttk::frame $top.l.sug
    ttk::button $top.l.sug.cat   -text "Suggest..." -command [list ::tkutils::tkulauncher::_edSuggest  $top]
    ttk::button $top.l.sug.quick -text "Quick add"  -command [list ::tkutils::tkulauncher::_edQuickAdd $top]
    grid $top.l.sug.cat $top.l.sug.quick -sticky ew -padx 2
    grid columnconfigure $top.l.sug {0 1} -weight 1
    grid $top.l.sug -sticky ew -pady {2 0}
    # move the selected entry within its menu, or into another menu
    ttk::frame $top.l.mv
    ttk::button $top.l.mv.up   -text "Up"   -command [list ::tkutils::tkulauncher::_edMove $top -1]
    ttk::button $top.l.mv.down -text "Down" -command [list ::tkutils::tkulauncher::_edMove $top 1]
    ttk::button $top.l.mv.to   -text "Move to..." -command [list ::tkutils::tkulauncher::_edMoveTo $top]
    grid $top.l.mv.up $top.l.mv.down $top.l.mv.to -sticky ew -padx 2
    grid columnconfigure $top.l.mv {0 1 2} -weight 1
    grid $top.l.mv -sticky ew -pady {2 0}
    # pick which menu a new entry goes into
    ttk::frame $top.l.into
    ttk::label $top.l.into.l -text "New in:"
    ttk::combobox $top.l.into.menu -state readonly -width 18
    grid $top.l.into.l $top.l.into.menu -sticky ew -padx 2
    grid columnconfigure $top.l.into 1 -weight 1
    grid $top.l.into -sticky ew -pady {2 0}
    # keep a stable widget name for the combobox
    set state($top,menucb) $top.l.into.menu

    set spec [list \
        [list name type  label Type  type combo state readonly \
            values {app url open file system tcl separator menu calendar calc}] \
        {name label label Label} \
        {name cmd    label "Command (app)"} \
        {name target label "Target (url/open/file/tcl script)"} \
        [list name id label "System id" type combo state readonly \
            values [systemIds]] \
        [list name interp label "Interpreter (tcl)" type combo state readonly \
            values [concat {{}} [tclInterpreters]]] \
        {name tcllibpath label "TCLLIBPATH (tcl)"} \
        {name args   label "Args (tcl)"} \
        {name dir    label "Working dir"} \
        {name icon   label "Icon path"} \
        {name tooltip label Tooltip} \
        {name terminal label "Run in terminal" type check} \
    ]
    ::tkutils::tkuform::widget $top.form $spec -padding 8

    ttk::frame $top.act
    ttk::button $top.act.apply -text "Apply"          -command [list ::tkutils::tkulauncher::_edApply  $top]
    ttk::button $top.act.upd   -text "Update launcher" -command [list ::tkutils::tkulauncher::_edUpdate $top]
    ttk::button $top.act.save  -text "Save to file..." -command [list ::tkutils::tkulauncher::_edSave   $top]
    ttk::button $top.act.close -text "Close"          -command [list destroy $top]
    pack $top.act.close -side right -padx 2
    pack $top.act.save  -side right -padx 2
    pack $top.act.upd   -side right -padx 2
    pack $top.act.apply -side right -padx 2

    grid $top.l    -row 0 -column 0 -sticky nsew -padx 6 -pady 6
    grid $top.form -row 0 -column 1 -sticky nsew -padx 6 -pady 6
    grid $top.act  -row 1 -column 0 -columnspan 2 -sticky ew -padx 6 -pady {0 6}
    grid rowconfigure $top 0 -weight 1
    grid columnconfigure $top 1 -weight 1

    bind $top.l.list <<ListboxSelect>> [list ::tkutils::tkulauncher::_edSelect $top]
    _edRefill $top
    return $top
}

# the entries to edit: the loaded file's items if any, else the -items spec
proc ::tkutils::tkulauncher::_editItems {path} {
    variable state
    if {[info exists state($path,items)]} { return $state($path,items) }
    return {}
}

# All places a new entry can go: the top level plus every submenu, as a list
# of {display path} pairs (path is the index list to that menu's items; the
# empty path means the top level).
proc ::tkutils::tkulauncher::_edMenus {top} {
    variable state
    set out [list [list "(top level)" {}]]
    _edMenusLevel $state($top,items) {} 0 out
    return $out
}

proc ::tkutils::tkulauncher::_edMenusLevel {items prefix depth outvar} {
    upvar 1 $outvar out
    set pad [string repeat "  " $depth]
    set i 0
    foreach e $items {
        if {[dict get $e type] eq "menu"} {
            set path [concat $prefix $i]
            lappend out [list "${pad}[_label $e]" $path]
            if {[dict exists $e items]} {
                _edMenusLevel [dict get $e items] $path [expr {$depth+1}] out
            }
        }
        incr i
    }
}

# Rebuild the listbox from the working items, showing submenu children indented
# beneath their menu. state($top,rows) maps each visible line to a path (a list
# of indices) into the nested items, so selection can reach nested entries.
proc ::tkutils::tkulauncher::_edRefill {top} {
    variable state
    $top.l.list delete 0 end
    set state($top,rows) {}
    _edRefillLevel $top $state($top,items) {} 0
    _edSyncMenus $top
}

# refresh the "New in:" combobox choices, keeping the current pick if possible
proc ::tkutils::tkulauncher::_edSyncMenus {top} {
    variable state
    if {![info exists state($top,menucb)] || ![winfo exists $state($top,menucb)]} return
    set cb $state($top,menucb)
    set menus [_edMenus $top]
    set state($top,menus) $menus
    set labels {}
    foreach m $menus { lappend labels [lindex $m 0] }
    set keep [$cb get]
    $cb configure -values $labels
    if {$keep ni $labels} { $cb set [lindex $labels 0] }
}

proc ::tkutils::tkulauncher::_edRefillLevel {top items prefix depth} {
    variable state
    set pad [string repeat "    " $depth]
    set i 0
    foreach e $items {
        set path [concat $prefix $i]
        set type [dict get $e type]
        if {$type eq "separator"} {
            $top.l.list insert end "${pad}--------  (separator)"
        } else {
            $top.l.list insert end "${pad}[_label $e]  ($type)"
        }
        lappend state($top,rows) $path
        if {$type eq "menu" && [dict exists $e items]} {
            _edRefillLevel $top [dict get $e items] $path [expr {$depth+1}]
        }
        incr i
    }
}

# get/set an entry at a path (list of indices) inside the nested items
proc ::tkutils::tkulauncher::_edGet {top path} {
    variable state
    set items $state($top,items)
    set e {}
    foreach idx $path {
        set e [lindex $items $idx]
        if {[dict exists $e items]} { set items [dict get $e items] }
    }
    return $e
}

proc ::tkutils::tkulauncher::_edSet {top path entry} {
    variable state
    set state($top,items) [_edSetIn $state($top,items) $path $entry]
}

# recursive replace of the entry at $path within $items
proc ::tkutils::tkulauncher::_edSetIn {items path entry} {
    set idx [lindex $path 0]
    if {[llength $path] == 1} {
        return [lreplace $items $idx $idx $entry]
    }
    set e [lindex $items $idx]
    set sub [_edSetIn [dict get $e items] [lrange $path 1 end] $entry]
    dict set e items $sub
    return [lreplace $items $idx $idx $e]
}

# recursive delete of the entry at $path
proc ::tkutils::tkulauncher::_edDelIn {items path} {
    set idx [lindex $path 0]
    if {[llength $path] == 1} {
        return [lreplace $items $idx $idx]
    }
    set e [lindex $items $idx]
    set sub [_edDelIn [dict get $e items] [lrange $path 1 end]]
    dict set e items $sub
    return [lreplace $items $idx $idx $e]
}

proc ::tkutils::tkulauncher::_edSelect {top} {
    variable state
    set sel [$top.l.list curselection]
    if {$sel eq ""} return
    set path [lindex $state($top,rows) [lindex $sel 0]]
    set e [_edGet $top $path]
    # clear the form, then fill known fields
    set blank {type "" label "" cmd "" target "" id "" interp "" tcllibpath "" args "" dir "" icon "" tooltip "" terminal 0}
    ::tkutils::tkuform::setValues $top.form $blank
    ::tkutils::tkuform::setValues $top.form $e
}

# ---------------------------------------------------------------------------
# Suggestion catalogue: ready-made entries grouped by category, so someone who
# is not sure what to put in a menu can just pick from a list. See suggestions,
# _edSuggest (a checklist dialog) and _edQuickAdd (insert a sensible default).
# ---------------------------------------------------------------------------
namespace eval ::tkutils::tkulauncher {
    variable suggestCat {
        "System tools" {
            {type system id terminal}
            {type system id filemanager}
            {type system id settings}
            {type system id taskmanager}
            {type system id systeminfo}
            {type system id screenshot}
            {type system id lock}
        }
        "Power" {
            {type system id logout}
            {type system id suspend}
            {type system id restart}
            {type system id shutdown}
        }
        "Internet" {
            {type url label "Tcl/Tk Manual" target "https://www.tcl.tk/man/tcl9.0/"}
            {type url label "Tcl Wiki"      target "https://wiki.tcl-lang.org/"}
            {type url label "GitHub"        target "https://github.com/"}
            {type url label "Stack Overflow" target "https://stackoverflow.com/"}
        }
        "Tcl scripts" {
            {type tcl label "Run script (wish 9)"   target "~/script.tcl" interp wish9}
            {type tcl label "Run script (wish 8.6)" target "~/script.tcl" interp wish8}
            {type tcl label "Run tests (tclsh 9)"   target "~/test/all.tcl" interp tclsh9 terminal 1}
            {type tcl label "Run tests (tclsh 8.6)" target "~/test/all.tcl" interp tclsh8 terminal 1}
        }
        "Basics" {
            {type calc}
            {type calendar}
            {type open label "Home" target "~"}
            {type separator}
        }
    }
}

# the suggestion catalogue as {category {entry ...} ...}
proc ::tkutils::tkulauncher::suggestions {} {
    variable suggestCat
    return $suggestCat
}

# a small, sensible default set for "quick add"
proc ::tkutils::tkulauncher::quickAddSet {} {
    return {
        {type system id terminal}
        {type system id filemanager}
        {type separator}
        {type calc}
        {type calendar}
        {type open label "Home" target "~"}
    }
}

# insert an entry into the menu currently chosen in the "New in:" combobox;
# returns the path of the inserted entry
proc ::tkutils::tkulauncher::_edInsertEntry {top entry} {
    variable state
    set path {}
    if {[info exists state($top,menucb)] && [winfo exists $state($top,menucb)]} {
        set pick [$state($top,menucb) get]
        foreach m $state($top,menus) {
            if {[lindex $m 0] eq $pick} { set path [lindex $m 1] ; break }
        }
    }
    if {$path eq {}} {
        lappend state($top,items) $entry
        return [list [expr {[llength $state($top,items)]-1}]]
    }
    set menu [_edGet $top $path]
    set kids [expr {[dict exists $menu items] ? [dict get $menu items] : {}}]
    lappend kids $entry
    dict set menu items $kids
    _edSet $top $path $menu
    return [concat $path [expr {[llength $kids]-1}]]
}

# insert a sensible default set into the chosen menu
proc ::tkutils::tkulauncher::_edQuickAdd {top} {
    variable state
    set last {}
    foreach e [quickAddSet] { set last [_edInsertEntry $top $e] }
    _edRefill $top
    _edSyncMenus $top
    # select the last inserted row
    set row 0
    foreach pth $state($top,rows) {
        if {$pth eq $last} { $top.l.list selection clear 0 end ; $top.l.list selection set $row ; break }
        incr row
    }
    _edSelect $top
}

# open a checklist dialog of suggested entries grouped by category; the user
# ticks the ones they want and they are inserted into the chosen menu
proc ::tkutils::tkulauncher::_edSuggest {top} {
    variable state
    set dlg $top.suggest
    catch {destroy $dlg}
    toplevel $dlg
    wm title $dlg "Suggested entries"
    wm transient $dlg $top

    ttk::label $dlg.hint -text "Tick entries to add, then Insert. They go into the menu chosen in \"New in:\"."
    pack $dlg.hint -side top -anchor w -padx 8 -pady {8 2}

    ttk::frame $dlg.f
    set tv $dlg.f.tv
    ttk::treeview $tv -show tree -selectmode none -height 16 \
        -yscrollcommand [list $dlg.f.sb set]
    ttk::scrollbar $dlg.f.sb -orient vertical -command [list $tv yview]
    grid $tv $dlg.f.sb -sticky nsew
    grid rowconfigure $dlg.f 0 -weight 1
    grid columnconfigure $dlg.f 0 -weight 1
    pack $dlg.f -side top -fill both -expand 1 -padx 8

    # fill the tree; each leaf carries its entry; a leading [ ] / [x] shows state
    set state($top,sugItems) {}   ;# maps tree-id -> {checked entry}
    set cat 0
    foreach {category entries} [suggestions] {
        incr cat
        set pid "cat$cat"
        $tv insert {} end -id $pid -text $category -open 1
        set n 0
        foreach e $entries {
            incr n
            set id "$pid.n$n"
            $tv insert $pid end -id $id -text "\[ \]  [_label $e]"
            dict set state($top,sugItems) $id [list 0 $e]
        }
    }
    # click a leaf to toggle its checkbox
    bind $tv <Button-1> [list ::tkutils::tkulauncher::_edSuggestToggle $top $tv %x %y]

    ttk::frame $dlg.b
    ttk::button $dlg.b.all   -text "Select all"  -command [list ::tkutils::tkulauncher::_edSuggestAll $top $tv 1]
    ttk::button $dlg.b.none  -text "Clear"       -command [list ::tkutils::tkulauncher::_edSuggestAll $top $tv 0]
    ttk::button $dlg.b.ins   -text "Insert"      -command [list ::tkutils::tkulauncher::_edSuggestInsert $top $tv]
    ttk::button $dlg.b.close -text "Close"       -command [list destroy $dlg]
    pack $dlg.b.close $dlg.b.ins -side right -padx 2
    pack $dlg.b.all $dlg.b.none -side left -padx 2
    pack $dlg.b -side bottom -fill x -padx 6 -pady 6
}

proc ::tkutils::tkulauncher::_edSuggestToggle {top tv x y} {
    variable state
    set id [$tv identify item $x $y]
    if {$id eq "" || ![dict exists $state($top,sugItems) $id]} return
    lassign [dict get $state($top,sugItems) $id] on e
    set on [expr {!$on}]
    dict set state($top,sugItems) $id [list $on $e]
    set mark [expr {$on ? "\[x\]" : "\[ \]"}]
    $tv item $id -text "$mark  [_label $e]"
}

proc ::tkutils::tkulauncher::_edSuggestAll {top tv on} {
    variable state
    dict for {id v} $state($top,sugItems) {
        lassign $v _ e
        dict set state($top,sugItems) $id [list $on $e]
        set mark [expr {$on ? "\[x\]" : "\[ \]"}]
        $tv item $id -text "$mark  [_label $e]"
    }
}

proc ::tkutils::tkulauncher::_edSuggestInsert {top tv} {
    variable state
    set last {}
    set count 0
    dict for {id v} $state($top,sugItems) {
        lassign $v on e
        if {$on} { set last [_edInsertEntry $top $e] ; incr count }
    }
    if {$count == 0} return
    _edRefill $top
    _edSyncMenus $top
    catch {destroy $top.suggest}
    # select the last inserted entry
    set row 0
    foreach pth $state($top,rows) {
        if {$pth eq $last} { $top.l.list selection clear 0 end ; $top.l.list selection set $row ; break }
        incr row
    }
    _edSelect $top
}

proc ::tkutils::tkulauncher::_edNew {top} {
    variable state
    set entry [dict create type app label "New entry" cmd ""]
    set newpath [_edInsertEntry $top $entry]
    _edRefill $top
    # select the freshly added row
    set row 0
    foreach p $state($top,rows) {
        if {$p eq $newpath} { $top.l.list selection clear 0 end ; $top.l.list selection set $row ; break }
        incr row
    }
    _edSelect $top
}

proc ::tkutils::tkulauncher::_edDel {top} {
    variable state
    set sel [$top.l.list curselection]
    if {$sel eq ""} return
    set path [lindex $state($top,rows) [lindex $sel 0]]
    set state($top,items) [_edDelIn $state($top,items) $path]
    _edRefill $top
}

# copy the form into the selected entry, keeping only the fields that make
# sense for the chosen type (so changing the type does not leave stale fields)
proc ::tkutils::tkulauncher::_edApply {top} {
    variable state
    set sel [$top.l.list curselection]
    if {$sel eq ""} return
    set path [lindex $state($top,rows) [lindex $sel 0]]
    set old [_edGet $top $path]
    set vals [::tkutils::tkuform::values $top.form]
    set type [dict get $vals type]
    set e [dict create type $type]
    # label applies to everything except separators
    if {$type ne "separator" && [dict get $vals label] ne ""} {
        dict set e label [dict get $vals label]
    }
    # type-specific primary field
    switch -- $type {
        app     { _edPut e $vals cmd }
        url -
        open -
        file    { _edPut e $vals target }
        system  { _edPut e $vals id }
        tcl     {
            _edPut e $vals target
            # interpreter defaults to wish9 when left blank
            set ip [dict get $vals interp]
            dict set e interp [expr {$ip eq "" ? "wish9" : $ip}]
            _edPut e $vals tcllibpath
            _edPut e $vals args
        }
        menu    { if {[dict exists $old items]} { dict set e items [dict get $old items] } }
    }
    # optional fields that apply to launchable entries
    if {$type in {app url open file system tcl}} {
        foreach k {dir icon tooltip} { _edPut e $vals $k }
        if {[dict exists $vals terminal] && [dict get $vals terminal]} {
            dict set e terminal 1
        }
    }
    _edSet $top $path $e
    _edRefill $top
    # reselect the same row
    set row 0
    foreach p $state($top,rows) {
        if {$p eq $path} { $top.l.list selection set $row ; break }
        incr row
    }
}

# helper: copy a non-empty form field into the entry dict
proc ::tkutils::tkulauncher::_edPut {evar vals key} {
    upvar 1 $evar e
    if {[dict exists $vals $key] && [dict get $vals $key] ne ""} {
        dict set e $key [dict get $vals $key]
    }
}

# push the edited entries into the live launcher and rebuild it (no file)
proc ::tkutils::tkulauncher::_edUpdate {top} {
    variable state
    set owner $state($top,owner)
    set state($owner,items) $state($top,items)
    _populate $owner
}

# write the entries to a file (JSON or INI by extension); the launcher's file if
# it has one, otherwise ask. Also updates the live launcher.
# --- moving entries ---------------------------------------------------------
# delete an entry at a path and return {items removedEntry}
proc ::tkutils::tkulauncher::_edCut {items path} {
    if {[llength $path] == 1} {
        set i [lindex $path 0]
        set e [lindex $items $i]
        set items [lreplace $items $i $i]
        return [list $items $e]
    }
    set i [lindex $path 0]
    set e [lindex $items $i]
    lassign [_edCut [dict get $e items] [lrange $path 1 end]] sub cut
    dict set e items $sub
    lset items $i $e
    return [list $items $cut]
}

# insert an entry into the items at menuPath (empty = top level), at end
proc ::tkutils::tkulauncher::_edInsert {items menuPath entry} {
    if {[llength $menuPath] == 0} {
        lappend items $entry
        return $items
    }
    set i [lindex $menuPath 0]
    set e [lindex $items $i]
    set sub [expr {[dict exists $e items] ? [dict get $e items] : {}}]
    set sub [_edInsert $sub [lrange $menuPath 1 end] $entry]
    dict set e items $sub
    lset items $i $e
    return $items
}

# move the selected entry up (-1) or down (+1) within its own menu level
proc ::tkutils::tkulauncher::_edMove {top dir} {
    variable state
    set sel [$top.l.list curselection]
    if {$sel eq ""} return
    set path [lindex $state($top,rows) [lindex $sel 0]]
    if {$path eq ""} return
    set parent [lrange $path 0 end-1]
    set idx [lindex $path end]
    # siblings at this level
    if {[llength $parent] == 0} {
        set sibs $state($top,items)
    } else {
        set sibs [dict get [_edGet $top $parent] items]
    }
    set n [llength $sibs]
    set new [expr {$idx + $dir}]
    if {$new < 0 || $new >= $n} return   ;# already at the edge
    # swap idx and new
    set a [lindex $sibs $idx]
    set b [lindex $sibs $new]
    lset sibs $idx $b
    lset sibs $new $a
    if {[llength $parent] == 0} {
        set state($top,items) $sibs
    } else {
        set e [_edGet $top $parent]
        dict set e items $sibs
        _edSet $top $parent $e
    }
    _edRefill $top
    # keep the moved entry selected at its new position
    set target [concat $parent $new]
    set row [lsearch -exact $state($top,rows) $target]
    if {$row >= 0} { $top.l.list selection clear 0 end; $top.l.list selection set $row; _edSelect $top }
}

# move the selected entry into a menu chosen from a dialog
proc ::tkutils::tkulauncher::_edMoveTo {top} {
    variable state
    set sel [$top.l.list curselection]
    if {$sel eq ""} return
    set path [lindex $state($top,rows) [lindex $sel 0]]
    if {$path eq ""} return
    set menus [_edMenus $top]   ;# {label menuPath} incl. "(top level)" {}
    # build a chooser dialog
    set dlg $top.moveto
    catch {destroy $dlg}
    toplevel $dlg
    wm title $dlg "Move to menu"
    wm transient $dlg $top
    ttk::label $dlg.l -text "Move the selected entry into:"
    ttk::combobox $dlg.cb -state readonly -width 30
    set labels {}
    foreach m $menus { lappend labels [lindex $m 0] }
    $dlg.cb configure -values $labels
    $dlg.cb set [lindex $labels 0]
    ttk::frame $dlg.b
    ttk::button $dlg.b.ok -text "Move" -command [list ::tkutils::tkulauncher::_edMoveToDo $top $dlg]
    ttk::button $dlg.b.cancel -text "Cancel" -command [list destroy $dlg]
    pack $dlg.b.cancel $dlg.b.ok -side right -padx 2
    pack $dlg.l -side top -anchor w -padx 8 -pady {8 2}
    pack $dlg.cb -side top -fill x -padx 8
    pack $dlg.b -side bottom -fill x -padx 6 -pady 6
    set state($top,moveMenus) $menus
}

proc ::tkutils::tkulauncher::_edMoveToDo {top dlg} {
    variable state
    set sel [$top.l.list curselection]
    if {$sel eq ""} { destroy $dlg; return }
    set path [lindex $state($top,rows) [lindex $sel 0]]
    set choice [$dlg.cb current]
    set menus $state($top,moveMenus)
    set dest [lindex [lindex $menus $choice] 1]   ;# target menu path ({} = top)
    # don't move a menu into itself or its own descendants
    if {[_edIsPrefix $path $dest]} {
        _error $top "Cannot move a menu into itself."
        return
    }
    # cut the entry, then insert into destination. Cutting can shift the dest
    # path if dest is after the cut point at the same level -- recompute by
    # cutting first and adjusting the destination if needed.
    lassign [_edCut $state($top,items) $path] items cut
    # if dest shares the parent level and its index is after the removed index,
    # decrement that index
    set dest [_edAdjustAfterCut $dest $path]
    set items [_edInsert $items $dest $cut]
    set state($top,items) $items
    _edRefill $top
    destroy $dlg
}

# is `pref` a prefix of `path` (i.e. path is pref or inside it)?
proc ::tkutils::tkulauncher::_edIsPrefix {pref path} {
    if {[llength $pref] > [llength $path]} { return 0 }
    for {set i 0} {$i < [llength $pref]} {incr i} {
        if {[lindex $pref $i] ne [lindex $path $i]} { return 0 }
    }
    return 1
}

# adjust a destination menu path after cutting an entry at cutPath: if they are
# siblings at the same parent and dest index > cut index, dest shifts down by 1
proc ::tkutils::tkulauncher::_edAdjustAfterCut {dest cutPath} {
    if {[llength $dest] == 0 || [llength $cutPath] == 0} { return $dest }
    set dp [lrange $dest 0 end-1]
    set cp [lrange $cutPath 0 end-1]
    if {$dp eq $cp} {
        set di [lindex $dest end]
        set ci [lindex $cutPath end]
        if {$di > $ci} { lset dest end [expr {$di-1}] }
    }
    return $dest
}

proc ::tkutils::tkulauncher::_edSave {top} {
    variable state
    _edUpdate $top
    set file $state($top,target)
    if {$file eq ""} {
        set file [tk_getSaveFile -parent $top \
            -filetypes {{JSON .json} {INI .ini}} -defaultextension .json]
        if {$file eq ""} return
        set state($top,target) $file
    }
    if {[catch {saveEntries $state($top,items) $file} err]} {
        _error $state($top,owner) "Could not save: $err"
    }
}

proc ::tkutils::tkulauncher::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    # free any images this launcher loaded from files
    if {[info exists state($path,icons)]} {
        dict for {spec img} $state($path,icons) { catch {image delete $img} }
    }
    array unset state $path,*
}

# ---- system tools: environment-aware entries ------------------------------
# A "system" entry names a well-known tool by id (terminal, cmd, powershell,
# filemanager, taskmanager, settings, printers, autostart, display), and the
# right command for the running platform / desktop is chosen automatically.
# This is what lets one menu offer "Task Manager" or "Printers" and have it do
# the right thing on Windows 11, XFCE, GNOME or KDE.

namespace eval ::tkutils::tkulauncher {
    # id -> human title (used when an entry gives no label)
    variable sysTitle {
        terminal "Terminal"  cmd "Command Prompt"  powershell "PowerShell"
        filemanager "File Manager"  taskmanager "Task Manager"
        settings "System Settings"  printers "Printers"
        autostart "Autostart"  display "Display Settings"
        network "Network Settings"  sound "Sound Settings"  bluetooth "Bluetooth"
        power "Power Settings"  keyboard "Keyboard"  mouse "Mouse"
        appearance "Appearance"  datetime "Date & Time"  users "Users & Accounts"
        about "About"  calculator "Calculator"  editor "Text Editor"
        screenshot "Screenshot"  lock "Lock Screen"  diskmanager "Disk Management"
        controlpanel "Control Panel"  devicemanager "Device Manager"
        services "Services"  software "Software"
        printjobs "Print Jobs"  systeminfo "System Information"
        logout "Log Out"  restart "Restart"  shutdown "Shut Down"
        suspend "Suspend"  brightness "Brightness"  wifi "Wi-Fi"
        updates "Updates"  firewall "Firewall"  fonts "Fonts"
        notifications "Notifications"  colorpicker "Color Picker"
        magnifier "Magnifier"  onscreenkeyboard "On-Screen Keyboard"
        clipboard "Clipboard"  environment "Environment Variables"
    }
    # id -> { platkey -> {kind exec|open argv {...}} }. platkey is one of
    # windows macos xfce gnome kde linux; a unix desktop falls back to linux.
    variable sysCat {
        terminal {
            windows {kind exec argv {cmd.exe /c start "" wt.exe}}
            macos   {kind exec argv {open -a Terminal}}
            xfce    {kind exec argv {xfce4-terminal}}
            gnome   {kind exec argv {gnome-terminal}}
            kde     {kind exec argv {konsole}}
            linux   {kind exec argv {x-terminal-emulator}}
        }
        cmd {
            windows {kind exec argv {cmd.exe /c start "" cmd.exe}}
        }
        powershell {
            windows {kind exec argv {cmd.exe /c start "" powershell.exe}}
            linux   {kind exec argv {pwsh}}
        }
        filemanager {
            windows {kind exec argv {explorer.exe}}
            macos   {kind exec argv {open .}}
            xfce    {kind exec argv {thunar}}
            gnome   {kind exec argv {nautilus}}
            kde     {kind exec argv {dolphin}}
            linux   {kind open argv .}
        }
        taskmanager {
            windows {kind exec argv {taskmgr.exe}}
            macos   {kind exec argv {open -a {Activity Monitor}}}
            xfce    {kind exec argv {xfce4-taskmanager}}
            gnome   {kind exec argv {gnome-system-monitor}}
            kde     {kind exec argv {plasma-systemmonitor}}
        }
        settings {
            windows {kind open argv ms-settings:}
            macos   {kind exec argv {open -a {System Settings}}}
            xfce    {kind exec argv {xfce4-settings-manager}}
            gnome   {kind exec argv {gnome-control-center}}
            kde     {kind exec argv {systemsettings}}
        }
        printers {
            windows {kind open argv ms-settings:printers}
            macos   {kind open argv {x-apple.systempreferences:com.apple.preference.printfax}}
            xfce    {kind exec argv {system-config-printer}}
            gnome   {kind exec argv {gnome-control-center printers}}
            kde     {kind exec argv {systemsettings kcm_printer_manager}}
            linux   {kind exec argv {system-config-printer}}
        }
        autostart {
            windows {kind exec argv {explorer.exe shell:startup}}
            macos   {kind open argv {x-apple.systempreferences:com.apple.preferences.users}}
            xfce    {kind exec argv {xfce4-session-settings}}
            gnome   {kind open argv {~/.config/autostart}}
            kde     {kind exec argv {systemsettings kcm_autostart}}
            linux   {kind open argv {~/.config/autostart}}
        }
        display {
            windows {kind open argv ms-settings:display}
            xfce    {kind exec argv {xfce4-display-settings}}
            gnome   {kind exec argv {gnome-control-center display}}
            kde     {kind exec argv {systemsettings kcm_kscreen}}
        }
        network {
            windows {kind open argv ms-settings:network-status}
            xfce    {kind exec argv {nm-connection-editor}}
            gnome   {kind exec argv {gnome-control-center network}}
            kde     {kind exec argv {systemsettings kcm_networkmanagement}}
            linux   {kind exec argv {nm-connection-editor}}
        }
        sound {
            windows {kind open argv ms-settings:sound}
            macos   {kind open argv {x-apple.systempreferences:com.apple.preference.sound}}
            xfce    {kind exec argv {pavucontrol}}
            gnome   {kind exec argv {gnome-control-center sound}}
            kde     {kind exec argv {systemsettings kcm_pulseaudio}}
            linux   {kind exec argv {pavucontrol}}
        }
        bluetooth {
            windows {kind open argv ms-settings:bluetooth}
            xfce    {kind exec argv {blueman-manager}}
            gnome   {kind exec argv {gnome-control-center bluetooth}}
            kde     {kind exec argv {systemsettings kcm_bluetooth}}
            linux   {kind exec argv {blueman-manager}}
        }
        power {
            windows {kind open argv ms-settings:powersleep}
            xfce    {kind exec argv {xfce4-power-manager-settings}}
            gnome   {kind exec argv {gnome-control-center power}}
            kde     {kind exec argv {systemsettings kcm_powerdevilprofilesconfig}}
        }
        keyboard {
            windows {kind open argv ms-settings:keyboard}
            xfce    {kind exec argv {xfce4-keyboard-settings}}
            gnome   {kind exec argv {gnome-control-center keyboard}}
            kde     {kind exec argv {systemsettings kcm_keyboard}}
        }
        mouse {
            windows {kind open argv ms-settings:mousetouchpad}
            xfce    {kind exec argv {xfce4-mouse-settings}}
            gnome   {kind exec argv {gnome-control-center mouse}}
            kde     {kind exec argv {systemsettings kcm_mouse}}
        }
        appearance {
            windows {kind open argv ms-settings:personalization}
            macos   {kind open argv {x-apple.systempreferences:com.apple.preference.desktopscreeneffect}}
            xfce    {kind exec argv {xfce4-appearance-settings}}
            gnome   {kind exec argv {gnome-control-center background}}
            kde     {kind exec argv {systemsettings kcm_lookandfeel}}
        }
        datetime {
            windows {kind open argv ms-settings:dateandtime}
            gnome   {kind exec argv {gnome-control-center datetime}}
            kde     {kind exec argv {systemsettings kcm_clock}}
        }
        users {
            windows {kind open argv ms-settings:otherusers}
            gnome   {kind exec argv {gnome-control-center user-accounts}}
            kde     {kind exec argv {systemsettings kcm_users}}
        }
        about {
            windows {kind open argv ms-settings:about}
            gnome   {kind exec argv {gnome-control-center info-overview}}
            kde     {kind exec argv {systemsettings kcm_about-distro}}
        }
        calculator {
            windows {kind exec argv {cmd.exe /c start "" calc.exe}}
            macos   {kind exec argv {open -a Calculator}}
            xfce    {kind exec argv {galculator}}
            gnome   {kind exec argv {gnome-calculator}}
            kde     {kind exec argv {kcalc}}
            linux   {kind exec argv {xcalc}}
        }
        editor {
            windows {kind exec argv {notepad.exe}}
            macos   {kind exec argv {open -e}}
            xfce    {kind exec argv {mousepad}}
            gnome   {kind exec argv {gedit}}
            kde     {kind exec argv {kate}}
        }
        screenshot {
            windows {kind exec argv {snippingtool.exe}}
            xfce    {kind exec argv {xfce4-screenshooter}}
            gnome   {kind exec argv {gnome-screenshot}}
            kde     {kind exec argv {spectacle}}
        }
        lock {
            windows {kind exec argv {rundll32.exe user32.dll,LockWorkStation}}
            xfce    {kind exec argv {xflock4}}
            linux   {kind exec argv {loginctl lock-session}}
        }
        diskmanager {
            windows {kind exec argv {cmd.exe /c start "" diskmgmt.msc}}
            gnome   {kind exec argv {gnome-disks}}
            kde     {kind exec argv {partitionmanager}}
            linux   {kind exec argv {gnome-disks}}
        }
        controlpanel {
            windows {kind exec argv {cmd.exe /c start "" control.exe}}
        }
        devicemanager {
            windows {kind exec argv {cmd.exe /c start "" devmgmt.msc}}
        }
        services {
            windows {kind exec argv {cmd.exe /c start "" services.msc}}
        }
        software {
            windows {kind open argv ms-windows-store:}
            gnome   {kind exec argv {gnome-software}}
            kde     {kind exec argv {plasma-discover}}
        }
        printjobs {
            windows {kind exec argv {cmd.exe /c start "" control printers}}
            macos   {kind open argv http://localhost:631/jobs/}
            gnome   {kind exec argv {gnome-control-center printers}}
            kde     {kind exec argv {systemsettings kcm_printer_manager}}
            xfce    {kind exec argv {system-config-printer}}
            linux   {kind open argv http://localhost:631/jobs/}
        }
        systeminfo {
            windows {kind exec argv {cmd.exe /c start "" msinfo32.exe}}
            macos   {kind exec argv {open -a {System Information}}}
            gnome   {kind exec argv {gnome-control-center info-overview}}
            kde     {kind exec argv {kinfocenter}}
            linux   {kind exec argv {hardinfo}}
        }
        logout {
            windows {kind exec argv {shutdown.exe /l}}
            macos   {kind exec argv {osascript -e {tell application "System Events" to log out}}}
            xfce    {kind exec argv {xfce4-session-logout --logout}}
            gnome   {kind exec argv {gnome-session-quit --logout}}
            kde     {kind exec argv {qdbus org.kde.Shutdown /Shutdown logout}}
        }
        restart {
            windows {kind exec argv {shutdown.exe /r /t 0}}
            macos   {kind exec argv {osascript -e {tell application "System Events" to restart}}}
            xfce    {kind exec argv {xfce4-session-logout --reboot}}
            gnome   {kind exec argv {gnome-session-quit --reboot}}
            kde     {kind exec argv {qdbus org.kde.Shutdown /Shutdown logoutAndReboot}}
            linux   {kind exec argv {systemctl reboot}}
        }
        shutdown {
            windows {kind exec argv {shutdown.exe /s /t 0}}
            macos   {kind exec argv {osascript -e {tell application "System Events" to shut down}}}
            xfce    {kind exec argv {xfce4-session-logout --halt}}
            gnome   {kind exec argv {gnome-session-quit --power-off}}
            kde     {kind exec argv {qdbus org.kde.Shutdown /Shutdown logoutAndShutdown}}
            linux   {kind exec argv {systemctl poweroff}}
        }
        suspend {
            windows {kind exec argv {rundll32.exe powrprof.dll,SetSuspendState 0,1,0}}
            macos   {kind exec argv {pmset sleepnow}}
            xfce    {kind exec argv {xfce4-session-logout --suspend}}
            gnome   {kind exec argv {systemctl suspend}}
            kde     {kind exec argv {qdbus org.kde.Solid.PowerManagement /org/freedesktop/PowerManagement Suspend}}
            linux   {kind exec argv {systemctl suspend}}
        }
        brightness {
            windows {kind open argv ms-settings:display}
            gnome   {kind exec argv {gnome-control-center display}}
            kde     {kind exec argv {systemsettings kcm_kscreen}}
        }
        wifi {
            windows {kind open argv ms-settings:network-wifi}
            macos   {kind open argv {x-apple.systempreferences:com.apple.wifi-settings-extension}}
            gnome   {kind exec argv {gnome-control-center wifi}}
            kde     {kind exec argv {systemsettings kcm_networkmanagement}}
            linux   {kind exec argv {nm-connection-editor}}
        }
        updates {
            windows {kind open argv ms-settings:windowsupdate}
            macos   {kind open argv {x-apple.systempreferences:com.apple.preferences.softwareupdate}}
            gnome   {kind exec argv {gnome-control-center info-overview}}
            kde     {kind exec argv {plasma-discover --mode update}}
        }
        firewall {
            windows {kind exec argv {cmd.exe /c start "" wf.msc}}
            gnome   {kind exec argv {gufw}}
            kde     {kind exec argv {systemsettings kcm_firewall}}
            linux   {kind exec argv {gufw}}
        }
        fonts {
            windows {kind open argv ms-settings:fonts}
            macos   {kind exec argv {open -a {Font Book}}}
            gnome   {kind exec argv {gnome-font-viewer}}
            kde     {kind exec argv {systemsettings kcm_fontinst}}
            linux   {kind exec argv {font-manager}}
        }
        notifications {
            windows {kind open argv ms-settings:notifications}
            macos   {kind open argv {x-apple.systempreferences:com.apple.preference.notifications}}
            gnome   {kind exec argv {gnome-control-center notifications}}
            kde     {kind exec argv {systemsettings kcm_notifications}}
        }
        colorpicker {
            windows {kind exec argv {powershell.exe -NoProfile -Command Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.ColorDialog]::new().ShowDialog()}}
            gnome   {kind exec argv {gcolor3}}
            kde     {kind exec argv {kcolorchooser}}
            linux   {kind exec argv {gcolor3}}
        }
        magnifier {
            windows {kind exec argv {magnify.exe}}
            macos   {kind open argv {x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Zoom}}
            gnome   {kind exec argv {gnome-control-center a11y}}
            kde     {kind exec argv {kmag}}
            linux   {kind exec argv {kmag}}
        }
        onscreenkeyboard {
            windows {kind exec argv {osk.exe}}
            macos   {kind exec argv {open -a KeyboardViewer}}
            gnome   {kind exec argv {onboard}}
            kde     {kind exec argv {onboard}}
            linux   {kind exec argv {onboard}}
        }
        clipboard {
            windows {kind open argv ms-settings:clipboard}
            kde     {kind exec argv {klipper}}
        }
        environment {
            windows {kind exec argv {rundll32.exe sysdm.cpl,EditEnvironmentVariables}}
        }
    }
}

proc ::tkutils::tkulauncher::systemTitle {id} {
    variable sysTitle
    if {[dict exists $sysTitle $id]} { return [dict get $sysTitle $id] }
    return $id
}

# Map platform/os/desktop to a catalogue key.
proc ::tkutils::tkulauncher::_platkey {plat os desktop} {
    if {$plat eq "windows"} { return windows }
    if {[string match -nocase *darwin* $os]} { return macos }
    set d [string tolower $desktop]
    if {[string match *xfce* $d]}    { return xfce }
    if {[string match *gnome* $d]}   { return gnome }
    if {[string match *kde* $d] || [string match *plasma* $d]} { return kde }
    return linux
}

# Resolve a system id to an action {kind exec|open argv {...}} for the platform.
# Options -platform / -os / -desktop override detection (for testing). Throws if
# the id is unknown or has no command on that platform.
proc ::tkutils::tkulauncher::resolveSystem {id args} {
    variable sysCat
    array set o [list -platform $::tcl_platform(platform) \
                      -os $::tcl_platform(os) \
                      -desktop [expr {[info exists ::env(XDG_CURRENT_DESKTOP)] ? $::env(XDG_CURRENT_DESKTOP) : ""}]]
    array set o $args
    if {![dict exists $sysCat $id]} { error "unknown system id: $id" }
    set byPlat [dict get $sysCat $id]
    set key [_platkey $o(-platform) $o(-os) $o(-desktop)]
    # desktop-specific -> fall back to generic linux for unix desktops
    if {[dict exists $byPlat $key]} {
        return [dict get $byPlat $key]
    }
    if {$key in {xfce gnome kde} && [dict exists $byPlat linux]} {
        return [dict get $byPlat linux]
    }
    error "system '$id' is not available on this platform ($key)"
}

# The system ids that resolve on the current platform, as a spec of entries.
# Pass -ids to choose a subset/order; default is a sensible common set.
proc ::tkutils::tkulauncher::systemItems {args} {
    variable sysCat
    array set o {-ids {terminal filemanager taskmanager settings printers
                       printjobs network sound bluetooth power display
                       autostart systeminfo}}
    array set o $args
    set out {}
    foreach id $o(-ids) {
        if {![catch {resolveSystem $id}]} {
            lappend out [dict create type system id $id label [systemTitle $id]]
        }
    }
    return $out
}

# All known system ids (sorted), for pickers such as the form editor.
proc ::tkutils::tkulauncher::systemIds {} {
    variable sysCat
    return [lsort [dict keys $sysCat]]
}

package provide tkutils::tkulauncher 0.1
