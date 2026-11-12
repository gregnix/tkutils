# tkutils::tkumdview -- Markdown viewer (headings outline + rendered preview)
# Description: Markdown viewer (headings outline + rendered preview)
# Category: Tk · widgets
#
# A Tk front-end on top of the tclutils Markdown engine (tumd). The document
# is parsed once by tumd::parse; the preview draws those blocks in a text
# widget, and the inline markup comes from tumd::inline, so the preview, the
# outline and toHtml always agree. The left pane is the heading outline;
# it follows the preview while scrolling, and selecting a heading scrolls
# the preview to it. Tcl/Tk 8.6+ and 9.x.
#
# Shown: headings, paragraphs, nested lists (start number, task items),
# block quotes, fenced and indented code, GitHub tables (tab stops measured
# per column), horizontal rules, footnotes, images (PNG/GIF, relative to the
# document), bold, italic, both, strikethrough, inline code, links.
# Links: #anchor jumps to the heading, a .md file opens in the viewer (with
# back and forward), anything else goes to -linkcommand or tclutils::tuopen.
# Toolbar: back, forward, search (all hits marked, Return / Shift+Return).
# Keys: Ctrl+F search, Alt+Left/Right back/forward, Ctrl+plus/minus/0 zoom.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tumd 0.3-
package require tkutils::tkuopts

namespace eval ::tkutils {}
namespace eval ::tkutils::tkumdview {
    namespace export widget loadFile setMarkdown getMarkdown headings toHtml \
        tocWidget textWidget currentFile follow back forward find findNext zoom
    variable state
    variable fontsReady 0
    # font name -> size at zoom 0
    variable fontBase {}
    variable zoomStep 0
    variable find
}

proc ::tkutils::tkumdview::_error {kind msg} {
    return -code error -level 2 -errorcode [list TKUTILS TKUMDVIEW $kind] $msg
}

proc ::tkutils::tkumdview::_cleanup {path w} {
    variable state
    variable find
    if {$w ne $path} return
    if {[info exists state($path,images)]} {
        foreach img $state($path,images) { catch {image delete $img} }
    }
    array unset state $path,*
    unset -nocomplain find($path)
}

# ---- fonts and zoom ---------------------------------------------------------

# Named fonts for the preview, derived once from the Tk text fonts; their
# sizes follow zoom (one step = one point, all viewers).
proc ::tkutils::tkumdview::_ensureFonts {} {
    variable fontsReady
    variable fontBase
    if {$fontsReady} { return }
    set text [font configure TkTextFont]
    set base [dict get $text -size]
    if {$base == 0} { set base 10 }
    set sign [expr {$base < 0 ? -1 : 1}]
    set b [expr {abs($base)}]
    set mono [font configure TkFixedFont]
    set mb [dict get $mono -size]
    if {$mb == 0} { set mb $base }
    foreach {name opts size} [list \
            mdvBase       $text                          $b \
            mdvBold       [concat $text -weight bold]    $b \
            mdvItalic     [concat $text -slant italic]   $b \
            mdvBoldItalic [concat $text -weight bold -slant italic] $b \
            mdvSmall      $text                          [expr {max(6, $b - 2)}] \
            mdvMono       $mono                          [expr {abs($mb)}] \
            mdvH1         [concat $text -weight bold]    [expr {$b + 9}] \
            mdvH2         [concat $text -weight bold]    [expr {$b + 6}] \
            mdvH3         [concat $text -weight bold]    [expr {$b + 3}]] {
        catch {font create $name {*}$opts}
        dict set fontBase $name [list $size $sign]
    }
    set fontsReady 1
    _applyZoom
}

proc ::tkutils::tkumdview::_applyZoom {} {
    variable fontBase
    variable zoomStep
    dict for {name sz} $fontBase {
        lassign $sz size sign
        catch {font configure $name -size [expr {$sign * max(4, $size + $zoomStep)}]}
    }
}

# zoom path ?delta|reset?: change the font size of all viewers by DELTA
# points (reset: back to normal). Returns the current step.
proc ::tkutils::tkumdview::zoom {path {delta ""}} {
    variable zoomStep
    variable state
    if {$delta eq ""} { return $zoomStep }
    if {$delta eq "reset"} {
        set zoomStep 0
    } elseif {[string is integer -strict $delta]} {
        set zoomStep [expr {max(-4, min(16, $zoomStep + $delta))}]
    } else {
        _error VALUE "zoom needs an integer or reset, not \"$delta\""
    }
    _applyZoom
    # tab stops of tables are measured in pixels: draw again
    foreach k [array names state *,md] {
        set p [string range $k 0 end-3]
        if {![winfo exists $p.pw.r.t]} continue
        set y [lindex [$p.pw.r.t yview] 0]
        _render $p
        _find $p
        update idletasks
        $p.pw.r.t yview moveto $y
    }
    return $zoomStep
}

# ---- widget -------------------------------------------------------------------

# Build the viewer under $path.
#   -width N -height N   size of the preview in characters and lines
#   -toolbar bool        back, forward and search above the panes (default 1)
#   -findlabel text      label of the search field (default "Find:")
#   -linkcommand cmd     called with the target of a link that is no anchor
#                        and no Markdown file (URL or full path); default:
#                        tclutils::tuopen::launch if available
proc ::tkutils::tkumdview::widget {path args} {
    variable state
    variable find
    set o [::tkutils::tkuopts::merge TKUMDVIEW \
        {-width 72 -height 26 -toolbar 1 -findlabel Find: -linkcommand {}} $args]
    _ensureFonts

    ttk::frame $path
    array set state [list $path,md "" $path,file "" $path,dir "" \
        $path,refs {} $path,notes {} \
        $path,marks {} $path,outline {} $path,anchors {} $path,links {} \
        $path,images {} $path,tables 0 $path,hist {} $path,hpos -1 \
        $path,found {} $path,fpos -1 $path,syncing 0 \
        $path,linkcommand [dict get $o -linkcommand]]
    set find($path) ""
    bind $path <Destroy> [list ::tkutils::tkumdview::_cleanup $path %W]

    set row 0
    if {[dict get $o -toolbar]} {
        set b [ttk::frame $path.bar]
        ttk::button $b.back -text "\u25c0" -width 3 -state disabled \
            -command [list ::tkutils::tkumdview::back $path]
        ttk::button $b.fwd -text "\u25b6" -width 3 -state disabled \
            -command [list ::tkutils::tkumdview::forward $path]
        ttk::label $b.fl -text [dict get $o -findlabel]
        ttk::entry $b.find -width 24 -textvariable ::tkutils::tkumdview::find($path)
        ttk::button $b.prev -text "\u25b2" -width 3 \
            -command [list ::tkutils::tkumdview::findNext $path -backwards]
        ttk::button $b.next -text "\u25bc" -width 3 \
            -command [list ::tkutils::tkumdview::findNext $path]
        ttk::label $b.hits -width 9
        pack $b.back $b.fwd -side left -padx {0 2}
        pack $b.hits $b.next $b.prev $b.find $b.fl -side right -padx {2 0}
        grid $b -row 0 -sticky ew -pady {0 2}
        bind $b.find <Return> [list ::tkutils::tkumdview::findNext $path]
        bind $b.find <Shift-Return> [list ::tkutils::tkumdview::findNext $path -backwards]
        bind $b.find <Escape> [list set ::tkutils::tkumdview::find($path) ""]
        bind $b.find <KeyRelease> [list ::tkutils::tkumdview::_findLater $path]
        incr row
    }

    ttk::panedwindow $path.pw -orient horizontal

    # left: heading outline
    ttk::frame $path.pw.l
    ttk::treeview $path.pw.l.toc -show tree -selectmode browse
    ttk::scrollbar $path.pw.l.ys -orient vertical -command [list $path.pw.l.toc yview]
    $path.pw.l.toc configure -yscrollcommand [list $path.pw.l.ys set]
    grid $path.pw.l.toc $path.pw.l.ys -sticky nsew
    grid rowconfigure    $path.pw.l 0 -weight 1
    grid columnconfigure $path.pw.l 0 -weight 1

    # right: rendered preview (read-only)
    ttk::frame $path.pw.r
    set t $path.pw.r.t
    text $t -width [dict get $o -width] -height [dict get $o -height] -wrap word \
        -state disabled -padx 8 -pady 6 -font mdvBase
    ttk::scrollbar $path.pw.r.ys -orient vertical -command [list $t yview]
    ttk::scrollbar $path.pw.r.xs -orient horizontal -command [list $t xview]
    $t configure -yscrollcommand [list ::tkutils::tkumdview::_yscroll $path] \
        -xscrollcommand [list $path.pw.r.xs set]
    grid $t $path.pw.r.ys -sticky nsew
    grid $path.pw.r.xs -sticky ew
    grid rowconfigure    $path.pw.r 0 -weight 1
    grid columnconfigure $path.pw.r 0 -weight 1

    $path.pw add $path.pw.l -weight 1
    $path.pw add $path.pw.r -weight 3
    grid $path.pw -row $row -sticky nsew
    grid rowconfigure    $path $row -weight 1
    grid columnconfigure $path 0 -weight 1

    _configureTags $t
    set state($path,cursor) [$t cget -cursor]
    $t tag bind link <Enter> [list $t configure -cursor hand2]
    $t tag bind link <Leave> [list $t configure -cursor $state($path,cursor)]
    $t tag bind link <ButtonRelease-1> [list ::tkutils::tkumdview::_linkClick $path %x %y]
    bind $t <1> {+focus %W}
    foreach w [list $t $path.pw.l.toc] {
        bind $w <Control-f> [list ::tkutils::tkumdview::_focusFind $path]
        bind $w <Alt-Left>  [list ::tkutils::tkumdview::back $path]
        bind $w <Alt-Right> [list ::tkutils::tkumdview::forward $path]
        foreach k {<Control-plus> <Control-equal> <Control-KP_Add>} {
            bind $w $k [list ::tkutils::tkumdview::zoom $path 1]
        }
        foreach k {<Control-minus> <Control-KP_Subtract>} {
            bind $w $k [list ::tkutils::tkumdview::zoom $path -1]
        }
        bind $w <Control-0> [list ::tkutils::tkumdview::zoom $path reset]
    }
    bind $t <Control-MouseWheel> \
        [list ::tkutils::tkumdview::_wheelZoom $path %D]
    bind $t <Control-Button-4> "[list ::tkutils::tkumdview::zoom $path 1]; break"
    bind $t <Control-Button-5> "[list ::tkutils::tkumdview::zoom $path -1]; break"
    bind $path.pw.l.toc <<TreeviewSelect>> [list ::tkutils::tkumdview::_gotoHeading $path]
    return $path
}

proc ::tkutils::tkumdview::_wheelZoom {path d} {
    zoom $path [expr {$d > 0 ? 1 : -1}]
    return -code break
}

proc ::tkutils::tkumdview::_configureTags {t} {
    $t tag configure h1 -font mdvH1 -spacing1 10 -spacing3 6
    $t tag configure h2 -font mdvH2 -spacing1 8  -spacing3 4
    $t tag configure h3 -font mdvH3 -spacing1 6  -spacing3 3
    $t tag configure h4 -font mdvBold -spacing1 4 -spacing3 2
    $t tag configure h5 -font mdvBold -spacing1 4 -spacing3 2
    $t tag configure h6 -font mdvBold -spacing1 4 -spacing3 2
    $t tag configure strong -font mdvBold
    $t tag configure em     -font mdvItalic
    $t tag configure strongem -font mdvBoldItalic
    $t tag configure del    -overstrike 1
    $t tag configure code   -font mdvMono -background #f0f0f0
    $t tag configure pre    -font mdvMono -background #f4f4f4 \
        -lmargin1 16 -lmargin2 16 -spacing1 2 -spacing3 2
    $t tag configure quote  -lmargin1 16 -lmargin2 16 -foreground #555555
    $t tag configure li     -lmargin1 16 -lmargin2 28
    $t tag configure link   -foreground #1a5fb4 -underline 1
    $t tag configure sup    -font mdvSmall -offset 4
    $t tag configure imgalt -foreground #777777 -font mdvItalic
    $t tag configure para   -spacing3 6
    $t tag configure hr     -foreground #999999 -spacing1 4 -spacing3 6
    $t tag configure table  -wrap none -spacing1 1 -spacing3 1
    $t tag configure thead  -font mdvBold -background #e6e6e6
    $t tag configure trowalt -background #f5f5f5
    $t tag configure gap    -spacing3 8
    $t tag configure found  -background #fff1a8
    $t tag configure foundcur -background #ffb84d
}

proc ::tkutils::tkumdview::tocWidget  {path} { return $path.pw.l.toc }
proc ::tkutils::tkumdview::textWidget {path} { return $path.pw.r.t }
proc ::tkutils::tkumdview::getMarkdown {path} {
    variable state
    return $state($path,md)
}
# The file shown ("" for text given with setMarkdown).
proc ::tkutils::tkumdview::currentFile {path} {
    variable state
    return $state($path,file)
}

# Convenience pass-throughs to the engine for the current document.
proc ::tkutils::tkumdview::headings {path} {
    variable state
    return [::tclutils::tumd::headings $state($path,md)]
}
proc ::tkutils::tkumdview::toHtml {path args} {
    variable state
    return [::tclutils::tumd::toHtml $state($path,md) {*}$args]
}

# ---- documents and history ----------------------------------------------------

proc ::tkutils::tkumdview::_read {filename} {
    set ch [open $filename r]
    fconfigure $ch -encoding utf-8
    set md [read $ch]
    close $ch
    return $md
}

# Read $filename (utf-8) and render it; starts a new history.
proc ::tkutils::tkumdview::loadFile {path filename} {
    set filename [file normalize $filename]
    set md [_read $filename]
    _start $path [dict create file $filename md $md dir [file dirname $filename] y 0]
    return [string length $md]
}

# Set the document text and render it; starts a new history. Relative links
# and images are resolved against -dir (default: the current directory).
proc ::tkutils::tkumdview::setMarkdown {path md args} {
    set o [::tkutils::tkuopts::merge TKUMDVIEW {-dir ""} $args]
    set dir [dict get $o -dir]
    if {$dir eq ""} { set dir [pwd] }
    _start $path [dict create file "" md $md dir [file normalize $dir] y 0]
    return [string length $md]
}

proc ::tkutils::tkumdview::_start {path entry} {
    variable state
    set state($path,hist) [list $entry]
    set state($path,hpos) 0
    _show $path $entry
}

proc ::tkutils::tkumdview::_show {path entry} {
    variable state
    set state($path,md) [dict get $entry md]
    set state($path,file) [dict get $entry file]
    set state($path,dir) [dict get $entry dir]
    _render $path
    _buildToc $path
    _historyButtons $path
    _find $path
}

# Remember where the current entry is scrolled to.
proc ::tkutils::tkumdview::_saveY {path} {
    variable state
    set k $state($path,hpos)
    if {$k < 0} return
    set e [lindex $state($path,hist) $k]
    dict set e y [lindex [$path.pw.r.t yview] 0]
    lset state($path,hist) $k $e
}

proc ::tkutils::tkumdview::_visit {path entry} {
    variable state
    _saveY $path
    set k $state($path,hpos)
    set state($path,hist) [lrange $state($path,hist) 0 $k]
    lappend state($path,hist) $entry
    incr state($path,hpos)
    _show $path $entry
}

proc ::tkutils::tkumdview::_go {path delta} {
    variable state
    set k [expr {$state($path,hpos) + $delta}]
    if {$k < 0 || $k >= [llength $state($path,hist)]} { return 0 }
    _saveY $path
    set state($path,hpos) $k
    set e [lindex $state($path,hist) $k]
    _show $path $e
    update idletasks
    $path.pw.r.t yview moveto [dict get $e y]
    return 1
}

# Back and forward in the documents opened through links; 1 if moved.
proc ::tkutils::tkumdview::back    {path} { _go $path -1 }
proc ::tkutils::tkumdview::forward {path} { _go $path 1 }

proc ::tkutils::tkumdview::_historyButtons {path} {
    variable state
    if {![winfo exists $path.bar]} return
    set k $state($path,hpos)
    $path.bar.back configure -state [expr {$k > 0 ? "normal" : "disabled"}]
    $path.bar.fwd configure \
        -state [expr {$k < [llength $state($path,hist)] - 1 ? "normal" : "disabled"}]
}

# ---- links ----------------------------------------------------------------------

proc ::tkutils::tkumdview::_linkClick {path x y} {
    variable state
    set t $path.pw.r.t
    # a drag that selected text is no click
    if {[llength [$t tag ranges sel]]} return
    foreach tag [$t tag names @$x,$y] {
        if {[dict exists $state($path,links) $tag]} {
            follow $path [dict get $state($path,links) $tag]
            return
        }
    }
}

proc ::tkutils::tkumdview::_urlDecode {s} {
    if {[string first % $s] < 0} { return $s }
    set out ""
    foreach part [regexp -all -inline {%[0-9A-Fa-f]{2}|[^%]+|%} $s] {
        if {[string length $part] == 3 && [string index $part 0] eq "%"} {
            append out [binary format H2 [string range $part 1 2]]
        } else {
            append out [encoding convertto utf-8 $part]
        }
    }
    encoding convertfrom utf-8 $out
}

# Follow a link as a click does: "#id" scrolls to the anchor, a .md file
# (relative to the document) opens in the viewer, anything else goes to
# -linkcommand or tclutils::tuopen. Returns what was done: anchor, file,
# external, or "" if the target was not found.
proc ::tkutils::tkumdview::follow {path href} {
    variable state
    if {[string index $href 0] eq "#"} {
        return [expr {[_jump $path [string range $href 1 end]] ? "anchor" : ""}]
    }
    if {[regexp {^[A-Za-z][A-Za-z0-9+.-]*:} $href] && ![regexp {^[A-Za-z]:[/\\]} $href]
            && ![string match file:* $href]} {
        _external $path $href
        return external
    }
    set target [regsub {^file://} $href ""]
    set frag ""
    set p [string first # $target]
    if {$p >= 0} {
        set frag [string range $target [expr {$p + 1}] end]
        set target [string range $target 0 [expr {$p - 1}]]
    }
    set target [_urlDecode $target]
    if {$target eq ""} {
        return [expr {[_jump $path $frag] ? "anchor" : ""}]
    }
    set full [file normalize [file join $state($path,dir) $target]]
    if {[string tolower [file extension $full]] in {.md .markdown}} {
        if {![file readable $full]} {
            _error LINK "cannot open \"$full\""
        }
        _visit $path [dict create file $full md [_read $full] dir [file dirname $full] y 0]
        if {$frag ne ""} {
            update idletasks
            _jump $path $frag
        }
        return file
    }
    _external $path $full
    return external
}

proc ::tkutils::tkumdview::_external {path target} {
    variable state
    set cmd $state($path,linkcommand)
    if {[llength $cmd]} {
        uplevel #0 [list {*}$cmd $target]
        return
    }
    if {![catch {package require tclutils::tuopen}]} {
        catch {::tclutils::tuopen::launch $target}
    }
}

# Scroll so that the anchor ID (heading id, fn-N, fnref-N) is at the top.
proc ::tkutils::tkumdview::_jump {path id} {
    variable state
    if {![dict exists $state($path,anchors) $id]} { return 0 }
    set t $path.pw.r.t
    $t yview [dict get $state($path,anchors) $id]
    return 1
}

# ---- outline --------------------------------------------------------------------

proc ::tkutils::tkumdview::_buildToc {path} {
    variable state
    set toc $path.pw.l.toc
    $toc delete [$toc children {}]
    set state($path,marks) {}
    set state($path,outline) {}
    set idx 0
    # Parent stack keyed by heading level so deeper headings nest under shallower.
    array set parent {0 {}}
    foreach hd [::tclutils::tumd::headings $state($path,md)] {
        lassign $hd lvl text
        set item h$idx
        set up {}
        for {set l [expr {$lvl - 1}]} {$l >= 0} {incr l -1} {
            if {[info exists parent($l)]} { set up $parent($l); break }
        }
        $toc insert $up end -id $item -text [_plain $path $text] -open 1
        set parent($lvl) $item
        foreach k [array names parent] { if {$k > $lvl} { unset parent($k) } }
        dict set state($path,marks) $item mark$idx
        lappend state($path,outline) $item mark$idx
        incr idx
    }
}

# Heading text without its Markdown, for the outline.
proc ::tkutils::tkumdview::_plain {path text} {
    regsub -all {<[^>]*>} [_inlineHtml $path $text] "" s
    ::tclutils::tumd::unescape $s
}

proc ::tkutils::tkumdview::_gotoHeading {path} {
    variable state
    if {$state($path,syncing)} return
    set sel [$path.pw.l.toc selection]
    if {![dict exists $state($path,marks) $sel]} { return }
    set mark [dict get $state($path,marks) $sel]
    set t $path.pw.r.t
    if {$mark in [$t mark names]} { $t yview $mark }
    return
}

proc ::tkutils::tkumdview::_yscroll {path first last} {
    variable state
    $path.pw.r.ys set $first $last
    if {[info exists state($path,synctimer)]} { after cancel $state($path,synctimer) }
    set state($path,synctimer) [after idle [list ::tkutils::tkumdview::_syncToc $path]]
}

# Mark in the outline the heading the preview shows at its top.
proc ::tkutils::tkumdview::_syncToc {path} {
    variable state
    if {![winfo exists $path.pw.r.t]} return
    unset -nocomplain state($path,synctimer)
    set t $path.pw.r.t
    set toc $path.pw.l.toc
    set top [$t index @0,0]
    set cur ""
    foreach {item mark} $state($path,outline) {
        if {$mark ni [$t mark names]} continue
        if {[$t compare $mark <= "$top lineend"]} { set cur $item } else break
    }
    if {$cur eq "" || [$toc selection] eq $cur} return
    set state($path,syncing) 1
    $toc selection set $cur
    $toc see $cur
    after idle [list ::tkutils::tkumdview::_syncDone $path]
}

proc ::tkutils::tkumdview::_syncDone {path} {
    variable state
    if {[info exists state($path,syncing)]} { set state($path,syncing) 0 }
}

# ---- search ---------------------------------------------------------------------

proc ::tkutils::tkumdview::_focusFind {path} {
    if {[winfo exists $path.bar.find]} {
        focus $path.bar.find
        $path.bar.find selection range 0 end
    }
    return -code break
}

proc ::tkutils::tkumdview::_findLater {path} {
    variable state
    variable find
    if {[info exists state($path,findlast)] && $state($path,findlast) eq $find($path)} return
    if {[info exists state($path,findtimer)]} { after cancel $state($path,findtimer) }
    set state($path,findtimer) [after 150 [list ::tkutils::tkumdview::_find $path]]
}

proc ::tkutils::tkumdview::_find {path} {
    variable find
    variable state
    if {![info exists find($path)]} return
    unset -nocomplain state($path,findtimer)
    find $path $find($path)
}

# Mark every place of PATTERN (case ignored) and go to the first one from the
# top of the view; returns the number of hits.
proc ::tkutils::tkumdview::find {path pattern} {
    variable state
    variable find
    set t $path.pw.r.t
    set find($path) $pattern
    set state($path,findlast) $pattern
    $t tag remove found 1.0 end
    $t tag remove foundcur 1.0 end
    set state($path,found) {}
    set state($path,fpos) -1
    if {$pattern ne ""} {
        set lens {}
        set hits [$t search -all -nocase -exact -count lens -- $pattern 1.0 end]
        foreach i $hits n $lens {
            $t tag add found $i "$i + $n chars"
            lappend state($path,found) [list $i $n]
        }
        $t tag raise found
        $t tag raise foundcur
    }
    _hits $path
    if {[llength $state($path,found)]} {
        set top [$t index @0,0]
        set k 0
        foreach h $state($path,found) {
            if {[$t compare [lindex $h 0] >= $top]} break
            incr k
        }
        if {$k >= [llength $state($path,found)]} { set k 0 }
        set state($path,fpos) [expr {$k - 1}]
        findNext $path
    }
    return [llength $state($path,found)]
}

# Go to the next (or with -backwards the previous) hit; returns its index.
proc ::tkutils::tkumdview::findNext {path {dir ""}} {
    variable state
    set n [llength $state($path,found)]
    if {!$n} { return "" }
    set step [expr {$dir eq "-backwards" ? -1 : 1}]
    set k [expr {($state($path,fpos) + $step + $n) % $n}]
    set state($path,fpos) $k
    lassign [lindex $state($path,found) $k] i len
    set t $path.pw.r.t
    $t tag remove foundcur 1.0 end
    $t tag add foundcur $i "$i + $len chars"
    $t see $i
    _hits $path
    return $i
}

proc ::tkutils::tkumdview::_hits {path} {
    variable state
    variable find
    if {![winfo exists $path.bar.hits]} return
    set n [llength $state($path,found)]
    if {$find($path) eq ""} {
        set s ""
    } elseif {!$n} {
        set s "0"
    } else {
        set s "[expr {$state($path,fpos) + 1}]/$n"
    }
    $path.bar.hits configure -text $s
}

# ---- rendering ----------------------------------------------------------------

proc ::tkutils::tkumdview::_render {path} {
    variable state
    set t $path.pw.r.t
    $t configure -state normal
    $t delete 1.0 end
    foreach m [$t mark names] {
        if {[string match mark* $m] || [string match anc* $m]} { $t mark unset $m }
    }
    foreach tg [$t tag names] {
        if {[string match tbl* $tg] || [string match lnk* $tg]} { $t tag delete $tg }
    }
    foreach img $state($path,images) { catch {image delete $img} }
    set state($path,images) {}
    set state($path,tables) 0
    set state($path,links) {}
    set state($path,anchors) {}
    set state($path,nanchor) 0
    set state($path,hidx) 0

    set d [::tclutils::tumd::parse $state($path,md)]
    set blocks [dict get $d blocks]
    set state($path,refs) [dict get $d refs]
    set state($path,notes) [dict get $d notes]
    _blocks $path $t $blocks 0 0 1 0
    set notes [_notes $blocks]
    if {[llength $notes]} {
        $t insert end "[string repeat \u2500 12]\n" hr
        foreach {n ib} $notes {
            _anchor $path $t fn-$n
            set mt [_mtag $t 16 [expr {16 + [font measure mdvBase "$n. "]}] 0]
            $t insert end "$n. " [list li $mt]
            if {[lindex $ib 0 0] eq "p"} {
                _para $path $t [list li $mt] [lindex $ib 0 1]
                set ib [lrange $ib 1 end]
            }
            $t insert end " " [list li $mt]
            _linkText $path $t [list li $mt] "\u21a9" "#fnref-$n"
            $t insert end "\n" [list li $mt]
            _blocks $path $t $ib [expr {16 + [font measure mdvBase "$n. "]}] 0 0 1
        }
    }
    $t tag raise found
    $t tag raise foundcur
    $t configure -state disabled
    $t yview moveto 0
}

# The footnote blocks in document order: {number blocks ...}.
proc ::tkutils::tkumdview::_notes {blocks} {
    set out {}
    foreach b $blocks {
        switch -- [lindex $b 0] {
            quote { lappend out {*}[_notes [lindex $b 1]] }
            list {
                foreach it [lindex $b 4] { lappend out {*}[_notes [lindex $it 1]] }
            }
            footnote {
                if {[lindex $b 2]} { lappend out [lindex $b 2] [lindex $b 3] }
            }
        }
    }
    return $out
}

# Margin tag: left margins L1 (first line) and L2 (wrapped lines); Q>0 for
# block quotes (grey margin).
proc ::tkutils::tkumdview::_mtag {t l1 l2 q} {
    set tag m${l1}_${l2}_[expr {$q > 0}]
    if {$tag ni [$t tag names]} {
        $t tag configure $tag -lmargin1 $l1 -lmargin2 $l2
        if {$q} { catch {$t tag configure $tag -lmargincolor #e2e2e2} }
    }
    return $tag
}

proc ::tkutils::tkumdview::_anchor {path t id} {
    variable state
    set m anc[incr state($path,nanchor)]
    $t mark set $m [$t index "end-1c"]
    $t mark gravity $m left
    dict set state($path,anchors) $id $m
}

# Draw BLOCKS with left margin INDENT. Q: depth of block quotes; TOP: the
# top level (headings get outline marks); TIGHT: paragraphs of a tight list.
proc ::tkutils::tkumdview::_blocks {path t blocks indent q top tight} {
    variable state
    set qt [expr {$q ? "quote" : ""}]
    foreach b $blocks {
        set mt [_mtag $t $indent $indent $q]
        switch -- [lindex $b 0] {
            h {
                lassign $b - lvl text id
                if {$top} {
                    set m mark$state($path,hidx)
                    $t mark set $m [$t index "end-1c"]
                    $t mark gravity $m left
                    incr state($path,hidx)
                }
                _anchor $path $t $id
                _inline $path $t [concat h$lvl $qt $mt] $text
                $t insert end "\n" [concat h$lvl $qt $mt]
            }
            p {
                set tags [concat [expr {$tight ? "li" : "para"}] $qt $mt]
                _para $path $t $tags [lindex $b 1]
                $t insert end "\n" $tags
            }
            code {
                set mc [_mtag $t [expr {$indent + 16}] [expr {$indent + 16}] $q]
                $t insert end "[lindex $b 2]\n" [concat pre $qt $mc]
                _gap $t
            }
            hr {
                $t insert end "[string repeat \u2500 40]\n" [concat hr $qt $mt]
            }
            quote {
                _blocks $path $t [lindex $b 1] [expr {$indent + 16}] [expr {$q + 1}] 0 0
                _gap $t
            }
            list {
                _list $path $t $b $indent $q
            }
            table {
                lassign $b - al head rows
                _table $path $t [linsert $rows 0 $head] $al $indent [concat $qt $mt]
                _gap $t
            }
            footnote - comment {
                # footnotes are drawn at the end; comments are hidden
            }
        }
    }
}

proc ::tkutils::tkumdview::_list {path t b indent q} {
    variable state
    lassign $b - ordered start loose items
    set qt [expr {$q ? "quote" : ""}]
    # nesting depth from the indentation, for the bullet shape
    if {![info exists state($path,depth)]} { set state($path,depth) 0 }
    set depth [incr state($path,depth)]
    set bullets [list "\u2022 " "\u25e6 " "\u25aa "]
    set k 0
    foreach it $items {
        lassign $it task ib
        if {$task eq "open"} {
            set mark "\u2610 "
        } elseif {$task eq "done"} {
            set mark "\u2611 "
        } elseif {$ordered} {
            set mark "[expr {$start + $k}]. "
        } else {
            set mark [lindex $bullets [expr {($depth - 1) % 3}]]
        }
        set l1 [expr {$indent + 16}]
        set l2 [expr {$l1 + [font measure mdvBase $mark]}]
        set mt [_mtag $t $l1 $l2 $q]
        set tags [concat li [expr {$loose ? "para" : ""}] $qt $mt]
        $t insert end $mark $tags
        if {[lindex $ib 0 0] eq "p"} {
            _para $path $t $tags [lindex $ib 0 1]
            set ib [lrange $ib 1 end]
        }
        $t insert end "\n" $tags
        _blocks $path $t $ib $l2 $q 0 [expr {!$loose}]
        incr k
    }
    if {[incr state($path,depth) -1] == 0} { _gap $t }
}

# Space below the block just drawn (its last line).
proc ::tkutils::tkumdview::_gap {t} {
    $t tag add gap "end-2c linestart" "end-1c"
}

# A paragraph: tumd joins its lines and makes the hard breaks.
proc ::tkutils::tkumdview::_para {path t tags lines} {
    variable state
    _html $path $t $tags [::tclutils::tumd::paragraph $lines \
        $state($path,refs) $state($path,notes)]
}

# HTML of inline Markdown with the definitions of the current document.
proc ::tkutils::tkumdview::_inlineHtml {path text} {
    variable state
    ::tclutils::tumd::inline $text $state($path,refs) $state($path,notes)
}

# ---- inline -------------------------------------------------------------------

# Runs of the HTML tumd::inline writes: {text string tags href}, {br},
# {img src alt}, {anchor id}.
proc ::tkutils::tkumdview::_runs {html} {
    set out {}
    set stack {}
    set hrefs {}
    set pos 0
    set re {<(/?)([a-z0-9]+)((?:\s+[a-z-]+="[^"]*")*)\s*>}
    while {[regexp -start $pos -indices -- $re $html m cl nm at]} {
        lassign $m a b
        if {$a > $pos} {
            lappend out [list text [::tclutils::tumd::unescape \
                [string range $html $pos [expr {$a - 1}]]] $stack [lindex $hrefs end]]
        }
        set close [expr {[lindex $cl 1] >= [lindex $cl 0]}]
        set name [string range $html {*}$nm]
        set attrs {}
        foreach {- k v} [regexp -all -inline {([a-z-]+)="([^"]*)"} [string range $html {*}$at]] {
            dict set attrs $k [::tclutils::tumd::unescape $v]
        }
        if {$close} {
            set i [lsearch -exact [lreverse $stack] [expr {$name eq "a" ? "link" : $name}]]
            if {$i >= 0} {
                set i [expr {[llength $stack] - 1 - $i}]
                set stack [lreplace $stack $i $i]
            }
            if {$name eq "a"} { set hrefs [lrange $hrefs 0 end-1] }
        } else {
            switch -- $name {
                a {
                    lappend stack link
                    lappend hrefs [expr {[dict exists $attrs href] ? [dict get $attrs href] : ""}]
                }
                img {
                    set src [expr {[dict exists $attrs src] ? [dict get $attrs src] : ""}]
                    set alt [expr {[dict exists $attrs alt] ? [dict get $attrs alt] : ""}]
                    lappend out [list img $src $alt]
                }
                br { lappend out [list br] }
                sup {
                    lappend stack sup
                    if {[dict exists $attrs id]} { lappend out [list anchor [dict get $attrs id]] }
                }
                default { lappend stack $name }
            }
        }
        set pos [expr {$b + 1}]
    }
    if {$pos < [string length $html]} {
        lappend out [list text [::tclutils::tumd::unescape [string range $html $pos end]] \
            $stack [lindex $hrefs end]]
    }
    return $out
}

# Tk tags for the HTML tags of a run.
proc ::tkutils::tkumdview::_runTags {tags} {
    set out {}
    foreach tg $tags {
        if {$tg in {strong em del code sup link}} { lappend out $tg }
    }
    if {"strong" in $out && "em" in $out} { lappend out strongem }
    return $out
}

proc ::tkutils::tkumdview::_linkText {path t base text href} {
    variable state
    set tag lnk[dict size $state($path,links)]
    dict set state($path,links) $tag $href
    $t insert end $text [concat $base link $tag]
}

# Insert the inline Markdown TEXT with the tags BASE.
proc ::tkutils::tkumdview::_inline {path t base text} {
    _html $path $t $base [_inlineHtml $path $text]
}

# Insert HTML as written by tumd::inline with the tags BASE.
proc ::tkutils::tkumdview::_html {path t base html} {
    foreach run [_runs $html] {
        switch -- [lindex $run 0] {
            text {
                lassign $run - s tags href
                set s [string map {\n " "} $s]
                set tt [concat $base [_runTags $tags]]
                if {"link" in $tags} {
                    _linkText $path $t $tt $s $href
                } else {
                    $t insert end $s $tt
                }
            }
            br { $t insert end "\n" $base }
            img { _image $path $t $base {*}[lrange $run 1 2] }
            anchor { _anchor $path $t [lindex $run 1] }
        }
    }
}

# An image relative to the document (PNG/GIF and what Tk reads), else its
# alt text in brackets.
proc ::tkutils::tkumdview::_image {path t base src alt} {
    variable state
    if {$src ne "" && ![regexp {^[A-Za-z][A-Za-z0-9+.-]*:} $src]} {
        set f [file join $state($path,dir) [_urlDecode $src]]
        if {[file readable $f] && ![catch {image create photo -file $f} img]} {
            lappend state($path,images) $img
            $t image create end -image $img -padx 2
            return
        }
    }
    $t insert end "\[[expr {$alt ne "" ? $alt : $src}]\]" [concat $base imgalt]
}

# ---- tables (GitHub style) ------------------------------------------------

# Width in pixels of a cell as it will be drawn.
proc ::tkutils::tkumdview::_cellWidth {path t cell head} {
    set plain [expr {$head ? "mdvBold" : "mdvBase"}]
    set w 0
    foreach run [_runs [_inlineHtml $path $cell]] {
        if {[lindex $run 0] ne "text"} continue
        set tags [_runTags [lindex $run 2]]
        set f $plain
        if {"code" in $tags} { set f mdvMono }
        if {"strong" in $tags} { set f mdvBold }
        if {"em" in $tags} { set f mdvItalic }
        if {"strongem" in $tags} { set f mdvBoldItalic }
        incr w [font measure $f [lindex $run 1]]
    }
    return $w
}

# Lay out rows (first = header) with one tab stop per column.
proc ::tkutils::tkumdview::_table {path t rows align indent extra} {
    variable state
    set tag tbl[incr state($path,tables)]
    set ncol 0
    foreach r $rows { if {[llength $r] > $ncol} { set ncol [llength $r] } }
    set align [lmap a $align { expr {$a eq "" ? "left" : $a} }]
    while {[llength $align] < $ncol} { lappend align left }
    set widths [lrepeat $ncol 0]
    set head 1
    foreach r $rows {
        for {set c 0} {$c < $ncol} {incr c} {
            set w [_cellWidth $path $t [lindex $r $c] $head]
            if {$w > [lindex $widths $c]} { lset widths $c $w }
        }
        set head 0
    }
    set gap [font measure mdvBase "  "]
    set x [expr {$indent + 4}]
    set tabs {}
    for {set c 0} {$c < $ncol} {incr c} {
        set w [lindex $widths $c]
        switch -- [lindex $align $c] {
            right   { lappend tabs [expr {$x + $w}] right }
            center  { lappend tabs [expr {$x + $w / 2}] center }
            default { lappend tabs $x left }
        }
        set x [expr {$x + $w + $gap}]
    }
    $t tag configure $tag -tabs $tabs -tabstyle tabular
    $t tag raise $tag
    set k 0
    foreach r $rows {
        if {$k == 0} {
            set base [concat table $extra $tag thead]
        } elseif {$k % 2 == 0} {
            set base [concat table $extra $tag trowalt]
        } else {
            set base [concat table $extra $tag]
        }
        for {set c 0} {$c < $ncol} {incr c} {
            $t insert end "\t" $base
            _inline $path $t $base [lindex $r $c]
        }
        $t insert end "\n" $base
        incr k
    }
    return
}

package provide tkutils::tkumdview 0.2
