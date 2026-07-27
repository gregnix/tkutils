# tkutils::tkupreview -- a content preview widget.
#
# Policy-free by design: it knows how to *display* a few kinds of content
# (plain text, rendered Markdown, or a centered message), but nothing about
# file types, extensions, providers or where the content comes from. The
# caller decides what to show; this widget just shows it.
#
# That split keeps it reusable: a file manager, a diff tool, a help browser --
# anything with "here is some content, display it" -- can use it. The mapping
# from file type to preview kind lives in the application, not here.
#
#   tkupreview::widget .pv
#   tkupreview::text     .pv "notes.txt (1.2 KB)" $content
#   tkupreview::markdown .pv "README.md"          $content
#   tkupreview::message  .pv "Select a file to preview."
#   tkupreview::clear    .pv
#   tkupreview::kind     .pv        ;# -> text | markdown | message | ""
#
# Markdown rendering uses tkumdview (a tkutils sibling) when available and
# falls back to plain text otherwise.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkupreview {
    namespace export widget text markdown html json xml ini csv hex sqlite image photo pdf message clear kind
    variable state
}

proc ::tkutils::tkupreview::widget {path} {
    variable state
    ttk::frame $path
    ttk::label $path.hdr -anchor w -padding {6 3} -relief groove
    pack $path.hdr -side top -fill x
    ttk::frame $path.body
    pack $path.body -side top -fill both -expand 1
    bind $path <Destroy> [list ::tkutils::tkupreview::_cleanup $path %W]
    set state($path,kind) ""
    return $path
}

# Show plain text with a header title.
proc ::tkutils::tkupreview::text {path title content} {
    variable state
    $path.hdr configure -text $title
    _clear $path
    ::text $path.body.t -wrap none -undo 0 \
        -yscrollcommand [list $path.body.ys set] \
        -xscrollcommand [list $path.body.xs set]
    ttk::scrollbar $path.body.ys -orient vertical   -command [list $path.body.t yview]
    ttk::scrollbar $path.body.xs -orient horizontal -command [list $path.body.t xview]
    grid $path.body.t  $path.body.ys -sticky nsew
    grid $path.body.xs                -sticky ew
    grid rowconfigure    $path.body 0 -weight 1
    grid columnconfigure $path.body 0 -weight 1
    $path.body.t insert end $content
    $path.body.t configure -state disabled
    set state($path,kind) text
    return
}

# Show rendered Markdown with a header title. Falls back to text if the
# Markdown viewer is unavailable.
proc ::tkutils::tkupreview::markdown {path title content} {
    variable state
    $path.hdr configure -text $title
    _clear $path
    if {[catch {package require tkutils::tkumdview}]} {
        ::tkutils::tkupreview::text $path $title $content
        return
    }
    if {[catch {
        ::tkutils::tkumdview::widget $path.body.md
        ::tkutils::tkumdview::setMarkdown $path.body.md $content
        pack $path.body.md -fill both -expand 1
    }]} {
        ::tkutils::tkupreview::text $path $title $content
        return
    }
    set state($path,kind) markdown
    return
}

# Show a centered message (empty state, "no preview", errors).
proc ::tkutils::tkupreview::message {path msg} {
    variable state
    $path.hdr configure -text ""
    _clear $path
    ttk::label $path.body.msg -text $msg -anchor center -foreground gray40
    pack $path.body.msg -fill both -expand 1
    set state($path,kind) message
    return
}

# Show rendered HTML using tcllitehtml (its widget's `load` takes HTML text, so
# no file path is needed). Falls back to plain text if unavailable.
proc ::tkutils::tkupreview::html {path title content} {
    variable state
    $path.hdr configure -text $title
    _clear $path
    if {[catch {package require tcllitehtml}]} {
        $path.hdr configure -text "$title  --  (tcllitehtml not available, showing source)"
        text $path $title $content
        return
    }
    if {[catch {
        set h $path.body.html
        set sb $path.body.hsb
        ttk::scrollbar $sb -orient vertical -command [list $h yview]
        # Follow the tcllitehtml demo-browser: no fixed -width, a scrollbar, a
        # direct load. litehtml lays the document out at its internal width
        # (default 800) at load time and only re-flows on <Configure>. When the
        # widget is created into an already-settled pane no <Configure> follows,
        # so we force a re-flow to the widget's real width after loading --
        # otherwise the text wraps at 800px (or one word per line if narrower).
        ::tcllitehtml::widget $h -background white -yscrollcommand [list $sb set]
        pack $sb -side right -fill y
        pack $h  -side left  -fill both -expand 1
        $h load $content
        update idletasks
        set w [winfo width $h]
        set ht [winfo height $h]
        if {$w > 1 && $ht > 1} { ::tcllitehtml::_do_resize $h $w $ht }
    }]} {
        $path.hdr configure -text "$title  --  (render failed, showing source)"
        _clear $path
        text $path $title $content
        return
    }
    set state($path,kind) html
    return
}

# A small family of viewers from tkutils, each fed text/bytes directly (no file
# path needed). All fall back to plain text / a message if the viewer or the
# content cannot be used. They share the same shape as markdown/csv/html.
proc ::tkutils::tkupreview::json {path title content} {
    _viewer $path $title $content tkutils::tkujson \
        ::tkutils::tkujson::widget ::tkutils::tkujson::setJson json $content
}
proc ::tkutils::tkupreview::xml {path title content} {
    _viewer $path $title $content tkutils::tkuxml \
        ::tkutils::tkuxml::widget ::tkutils::tkuxml::setXml xml $content
}
proc ::tkutils::tkupreview::ini {path title content} {
    _viewer $path $title $content tkutils::tkuini \
        ::tkutils::tkuini::widget ::tkutils::tkuini::loadText ini $content
}
proc ::tkutils::tkupreview::hex {path title data} {
    _viewer $path $title $data tkutils::tkuhexedit \
        ::tkutils::tkuhexedit::widget ::tkutils::tkuhexedit::setData hex $data
}

# Shared helper: require $pkg, build the viewer under $path.body.v, feed it via
# $setcmd, and record $kind. On any failure fall back to plain text.
proc ::tkutils::tkupreview::_viewer {path title content pkg buildcmd setcmd kind data} {
    variable state
    $path.hdr configure -text $title
    _clear $path
    if {[catch {package require $pkg}]} {
        text $path $title $content
        return
    }
    if {[catch {
        $buildcmd $path.body.v
        $setcmd   $path.body.v $data
        pack $path.body.v -fill both -expand 1
    }]} {
        text $path $title $content
        return
    }
    set state($path,kind) $kind
    return
}

# Show CSV content as a table, using tkucsv (which parses text via setData, so
# no file path is needed). Falls back to plain text if tkucsv is unavailable.
proc ::tkutils::tkupreview::csv {path title content args} {
    variable state
    $path.hdr configure -text $title
    _clear $path
    if {[catch {package require tkutils::tkucsv}]} {
        text $path $title $content
        return
    }
    if {[catch {
        ::tkutils::tkucsv::widget $path.body.csv
        # args are passed through to the parser (e.g. -delimiter \t for TSV);
        # the widget stays policy-free, it is just told the separator.
        ::tkutils::tkucsv::setData $path.body.csv $content {*}$args
        pack $path.body.csv -fill both -expand 1
    }]} {
        text $path $title $content
        return
    }
    set state($path,kind) csv
    return
}

# Show an already-created Tk photo image (e.g. a page rendered by a PDF
# engine). Displayed on a scrollable canvas. The caller owns the photo's
# lifetime; this only displays it.
proc ::tkutils::tkupreview::photo {path title img} {
    variable state
    $path.hdr configure -text $title
    _clear $path
    canvas $path.body.c -highlightthickness 0 \
        -xscrollcommand [list $path.body.x set] \
        -yscrollcommand [list $path.body.y set]
    ttk::scrollbar $path.body.x -orient horizontal -command [list $path.body.c xview]
    ttk::scrollbar $path.body.y -orient vertical   -command [list $path.body.c yview]
    grid $path.body.c $path.body.y -sticky nsew
    grid $path.body.x              -sticky ew
    grid rowconfigure    $path.body 0 -weight 1
    grid columnconfigure $path.body 0 -weight 1
    $path.body.c create image 0 0 -anchor nw -image $img
    $path.body.c configure -scrollregion [list 0 0 [::image width $img] [::image height $img]]
    set state($path,kind) photo
    return
}

# Show a SQLite database from a file path, using tkusqlite (a table browser).
# Path-based, so callers over a provider hand it a temp file. Falls back to a
# message if sqlite3/tkusqlite are unavailable or the file is not a database.
proc ::tkutils::tkupreview::sqlite {path title file} {
    variable state
    $path.hdr configure -text $title
    _clear $path
    if {[catch {package require tkutils::tkusqlite}]} {
        message $path "SQLite preview unavailable."
        return
    }
    if {[catch {
        ::tkutils::tkusqlite::widget $path.body.db
        ::tkutils::tkusqlite::openFile $path.body.db $file
        pack $path.body.db -fill both -expand 1
    } e]} {
        message $path "Cannot open database:\n$e"
        return
    }
    set state($path,kind) sqlite
    return
}

# Show an image from a file path, using tkuimage's zoomable canvas viewer.
# Falls back to a message if the image toolkit or the file cannot be used.
proc ::tkutils::tkupreview::image {path title file} {
    variable state
    $path.hdr configure -text $title
    _clear $path
    if {[catch {package require tkutils::tkuimage}]} {
        message $path "Image preview unavailable."
        return
    }
    if {[catch {
        ::tkutils::tkuimage::view $path.body.iv
        ::tkutils::tkuimage::openFile $path.body.iv $file
        pack $path.body.iv -fill both -expand 1
    } e]} {
        message $path "Cannot show image:\n$e"
        return
    }
    set state($path,kind) image
    return
}

# Show a PDF's structure from a file path, using tkupdfinspect.
proc ::tkutils::tkupreview::pdf {path title file} {
    variable state
    $path.hdr configure -text $title
    _clear $path
    if {[catch {package require tkutils::tkupdfinspect}]} {
        message $path "PDF preview unavailable."
        return
    }
    if {[catch {
        ::tkutils::tkupdfinspect::widget $path.body.pv
        ::tkutils::tkupdfinspect::loadFile $path.body.pv $file
        pack $path.body.pv -fill both -expand 1
    } e]} {
        message $path "Cannot show PDF:\n$e"
        return
    }
    set state($path,kind) pdf
    return
}

proc ::tkutils::tkupreview::clear {path} {
    variable state
    $path.hdr configure -text ""
    _clear $path
    set state($path,kind) ""
    return
}

proc ::tkutils::tkupreview::kind {path} {
    variable state
    return [expr {[info exists state($path,kind)] ? $state($path,kind) : ""}]
}

# ---- internals ------------------------------------------------------------
proc ::tkutils::tkupreview::_clear {path} {
    foreach w [winfo children $path.body] { destroy $w }
}

proc ::tkutils::tkupreview::_cleanup {path w} {
    variable state
    if {$w ne $path} return
    array unset state $path,*
}

package provide tkutils::tkupreview 0.1
