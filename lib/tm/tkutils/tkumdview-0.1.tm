# tkutils::tkumdview -- Markdown viewer (headings outline + rendered preview)
#
# A Tk front-end on top of the tclutils Markdown engine (tumd). The left pane is
# a heading outline (from tumd::headings); the right pane renders a readable
# preview of the document in a text widget using tags for headings, code,
# emphasis, lists and block quotes. Selecting a heading scrolls the preview to
# it. The generated HTML (tumd::toHtml) is available via [toHtml]. This goes
# beyond tkumd, which only shows the outline. Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tumd

namespace eval ::tkutils {}
namespace eval ::tkutils::tkumdview {
    namespace export widget loadFile setMarkdown getMarkdown headings toHtml \
        tocWidget textWidget
    variable state
    variable fontsReady 0
}

proc ::tkutils::tkumdview::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

# Named fonts for the preview tags, derived once from the Tk text fonts.
proc ::tkutils::tkumdview::_ensureFonts {} {
    variable fontsReady
    if {$fontsReady} { return }
    catch {font create mdvBold   {*}[font configure TkTextFont] -weight bold}
    catch {font create mdvItalic {*}[font configure TkTextFont] -slant italic}
    catch {font create mdvMono   {*}[font configure TkFixedFont]}
    set base [dict get [font configure TkTextFont] -size]
    if {$base <= 0} { set base 10 }
    catch {font create mdvH1 {*}[font configure TkTextFont] -weight bold \
        -size [expr {$base + 9}]}
    catch {font create mdvH2 {*}[font configure TkTextFont] -weight bold \
        -size [expr {$base + 6}]}
    catch {font create mdvH3 {*}[font configure TkTextFont] -weight bold \
        -size [expr {$base + 3}]}
    set fontsReady 1
}

# Build the viewer under $path. Options: -width N -height N (preview geometry).
proc ::tkutils::tkumdview::widget {path args} {
    variable state
    array set opts {-width 72 -height 26}
    array set opts $args
    _ensureFonts

    ttk::frame $path
    set state($path,md)    ""
    set state($path,marks) {}
    bind $path <Destroy> [list ::tkutils::tkumdview::_cleanup $path %W]

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
    text $path.pw.r.t -width $opts(-width) -height $opts(-height) -wrap word \
        -state disabled -padx 8 -pady 6
    ttk::scrollbar $path.pw.r.ys -orient vertical -command [list $path.pw.r.t yview]
    $path.pw.r.t configure -yscrollcommand [list $path.pw.r.ys set]
    grid $path.pw.r.t $path.pw.r.ys -sticky nsew
    grid rowconfigure    $path.pw.r 0 -weight 1
    grid columnconfigure $path.pw.r 0 -weight 1

    $path.pw add $path.pw.l -weight 1
    $path.pw add $path.pw.r -weight 3
    grid $path.pw -sticky nsew
    grid rowconfigure    $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    _configureTags $path.pw.r.t
    bind $path.pw.l.toc <<TreeviewSelect>> [list ::tkutils::tkumdview::_gotoHeading $path]
    return $path
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
    $t tag configure code   -font mdvMono -background #f0f0f0
    $t tag configure pre    -font mdvMono -background #f4f4f4 \
        -lmargin1 16 -lmargin2 16 -spacing1 2 -spacing3 2
    $t tag configure quote  -lmargin1 16 -lmargin2 16 -foreground #555555
    $t tag configure li     -lmargin1 16 -lmargin2 28
    $t tag configure link   -foreground #1a5fb4 -underline 1
    $t tag configure para   -spacing3 6
}

proc ::tkutils::tkumdview::tocWidget  {path} { return $path.pw.l.toc }
proc ::tkutils::tkumdview::textWidget {path} { return $path.pw.r.t }
proc ::tkutils::tkumdview::getMarkdown {path} {
    variable state
    return $state($path,md)
}

# Convenience pass-throughs to the engine for the current document.
proc ::tkutils::tkumdview::headings {path} {
    variable state
    return [::tclutils::tumd::headings $state($path,md)]
}
proc ::tkutils::tkumdview::toHtml {path} {
    variable state
    return [::tclutils::tumd::toHtml $state($path,md)]
}

# Read $filename (utf-8) and render it.
proc ::tkutils::tkumdview::loadFile {path filename} {
    set ch [open $filename r]
    fconfigure $ch -encoding utf-8
    set md [read $ch]
    close $ch
    return [setMarkdown $path $md]
}

# Set the document text, rebuild the outline and render the preview.
proc ::tkutils::tkumdview::setMarkdown {path md} {
    variable state
    set state($path,md) $md
    _buildToc $path
    _render $path
    return [string length $md]
}

proc ::tkutils::tkumdview::_buildToc {path} {
    variable state
    set toc $path.pw.l.toc
    $toc delete [$toc children {}]
    set state($path,marks) {}
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
        $toc insert $up end -id $item -text $text -open 1
        set parent($lvl) $item
        # clear deeper levels
        foreach k [array names parent] { if {$k > $lvl} { unset parent($k) } }
        dict set state($path,marks) $item mark$idx
        incr idx
    }
}

proc ::tkutils::tkumdview::_gotoHeading {path} {
    variable state
    set sel [$path.pw.l.toc selection]
    if {![dict exists $state($path,marks) $sel]} { return }
    set mark [dict get $state($path,marks) $sel]
    set t $path.pw.r.t
    if {$mark in [$t mark names]} { $t see $mark }
    return
}

# ---- rendering ----------------------------------------------------------

proc ::tkutils::tkumdview::_render {path} {
    variable state
    set t $path.pw.r.t
    $t configure -state normal
    $t delete 1.0 end
    foreach m [$t mark names] {
        if {[string match mark* $m]} { $t mark unset $m }
    }

    set body [lindex [::tclutils::tumd::frontmatter $state($path,md)] 1]
    set lines [split $body \n]
    set n [llength $lines]
    set i 0
    set hidx 0
    while {$i < $n} {
        set line [lindex $lines $i]
        # fenced code block
        if {[regexp {^[ \t]*(```+|~~~+)} $line]} {
            incr i
            set buf {}
            while {$i < $n && ![regexp {^[ \t]*(```+|~~~+)} [lindex $lines $i]]} {
                lappend buf [lindex $lines $i]
                incr i
            }
            incr i ;# closing fence
            $t insert end "[join $buf \n]\n" pre
            continue
        }
        # heading
        if {[regexp {^(#{1,6})[ \t]+(.*)$} $line -> h text]} {
            regsub {[ \t]+#+[ \t]*$} $text "" text
            set lvl [string length $h]
            $t mark set mark$hidx [$t index "end-1c linestart"]
            $t mark gravity mark$hidx left
            incr hidx
            _emitInline $t [list h$lvl] [string trim $text]
            $t insert end "\n"
            incr i
            continue
        }
        # horizontal rule
        if {[regexp {^[ \t]*([-*_])([ \t]*\1){2,}[ \t]*$} $line]} {
            $t insert end "[string repeat \u2500 40]\n"
            incr i
            continue
        }
        # block quote (collect consecutive > lines)
        if {[regexp {^[ \t]*>[ \t]?(.*)$} $line -> q]} {
            set buf [list $q]
            incr i
            while {$i < $n && [regexp {^[ \t]*>[ \t]?(.*)$} [lindex $lines $i] -> q]} {
                lappend buf $q
                incr i
            }
            _emitInline $t [list quote] [join $buf " "]
            $t insert end "\n"
            continue
        }
        # list item (unordered or ordered)
        if {[regexp {^[ \t]*([-*+]|[0-9]+\.)[ \t]+(.*)$} $line -> mark text]} {
            if {[string match {*.} $mark]} {
                set bullet "$mark "
            } else {
                set bullet "\u2022 "
            }
            $t insert end $bullet li
            _emitInline $t [list li] $text
            $t insert end "\n"
            incr i
            continue
        }
        # blank line -> paragraph separator
        if {[string trim $line] eq ""} {
            $t insert end "\n"
            incr i
            continue
        }
        # paragraph: gather consecutive non-blank, non-special lines
        set buf [list $line]
        incr i
        while {$i < $n} {
            set l [lindex $lines $i]
            if {[string trim $l] eq ""} break
            if {[regexp {^(#{1,6})[ \t]+|^[ \t]*(```+|~~~+)|^[ \t]*>|^[ \t]*([-*+]|[0-9]+\.)[ \t]+} $l]} break
            lappend buf $l
            incr i
        }
        _emitInline $t [list para] [join $buf " "]
        $t insert end "\n"
    }
    $t configure -state disabled
    $t see 1.0
}

# Insert $s into the text widget applying inline tags (code, strong, em, link)
# on top of the supplied base tags. A small left-to-right scanner; flat spans
# only (no nested emphasis), which covers the common cases.
proc ::tkutils::tkumdview::_emitInline {t base s} {
    set i 0
    set n [string length $s]
    set buf ""
    while {$i < $n} {
        set rest [string range $s $i end]
        # inline code: `...`
        if {[string index $s $i] eq "`"} {
            set close [string first "`" $s [expr {$i + 1}]]
            if {$close > $i} {
                if {$buf ne ""} { $t insert end $buf $base; set buf "" }
                $t insert end [string range $s [expr {$i + 1}] [expr {$close - 1}]] \
                    [concat $base code]
                set i [expr {$close + 1}]
                continue
            }
        }
        # strong: **...** or __...__
        if {[regexp {^(\*\*|__)(.+?)\1} $rest m -> mid]} {
            if {$buf ne ""} { $t insert end $buf $base; set buf "" }
            $t insert end $mid [concat $base strong]
            incr i [string length $m]
            continue
        }
        # emphasis: *...* or _..._
        if {[regexp {^(\*|_)([^*_]+?)\1} $rest m -> mid]} {
            if {$buf ne ""} { $t insert end $buf $base; set buf "" }
            $t insert end $mid [concat $base em]
            incr i [string length $m]
            continue
        }
        # link: [text](url) -- show the text, tagged as a link
        if {[regexp {^\[([^\]]+)\]\(([^)]*)\)} $rest m txt url]} {
            if {$buf ne ""} { $t insert end $buf $base; set buf "" }
            $t insert end $txt [concat $base link]
            incr i [string length $m]
            continue
        }
        append buf [string index $s $i]
        incr i
    }
    if {$buf ne ""} { $t insert end $buf $base }
    return
}

package provide tkutils::tkumdview 0.1
