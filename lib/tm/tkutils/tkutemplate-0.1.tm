# tkutils::tkutemplate -- editor for document templates (block layout + attributes)
# Description: editor for document templates: place blocks, edit their attributes and table columns, preview as PDF
# Category: Tk · widgets
#
# A template is a dict
#
#   paper a4  margin 20  top 20  bottom 277  size 10
#   theme {accent {r g b} ...}
#   blocks {id {type text x 20 y 50 w 85 size 11 bold 0 ...} ...}
#
# in the format of pdf4tcltemplate (pdf4tcllib) and tclutils::tulayout. The
# editor places blocks with tkutils::tkulayoutcanvas and keeps everything the
# canvas does not know -- type, font size, alignment, text, table columns --
# in its own panel. Geometry coming back from the canvas is merged with
# tclutils::tulayout::mergeLayout (keys x y w show), so no attribute is lost.
#
# The preview draws the template with sample data through pdf4tcltemplate,
# which is loaded only when a preview is asked for; the editor itself needs
# Tk, tclutils and tkulayoutcanvas only.
#
#   tkutemplate::widget .te ?-template dict? ?-sample dict? ?-onchange cmd?
#                           ?-scale px/mm? ?-gridmm mm? ?-font f? ?-fontbold f?
#   tkutemplate::getTemplate .te
#   tkutemplate::setTemplate .te $template
#   tkutemplate::setSample .te $data
#   tkutemplate::select .te $blockId
#   tkutemplate::addBlock .te $id ?type?
#   tkutemplate::deleteBlock .te $id
#   tkutemplate::moveBlock .te $id up|down
#   tkutemplate::setBlock .te $id key value ?key value ...?
#   tkutemplate::loadFile .te $file
#   tkutemplate::saveFile .te $file
#   tkutemplate::preview .te ?file?          -> PDF file
#
# Error codes: {TKUTILS TKUTEMPLATE <REASON>}: OPTION EXISTS NOWIDGET BLOCK
# VALUE FILE PREVIEW.
# Tcl/Tk 8.6+ and 9.x compatible.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tulayout 0.1
package require tclutils::tuopen 0.1
package require tkutils::tkuopts 0.1
package require tkutils::tkulayoutcanvas 0.2

namespace eval ::tkutils {}
namespace eval ::tkutils::tkutemplate {
    namespace export widget getTemplate setTemplate setSample select \
        addBlock deleteBlock moveBlock setBlock loadFile saveFile preview
    variable state
    variable TYPES  {text pairs table image rule}
    variable PAGES  {first all rest last}
    variable ALIGNS {left center right}
    variable PAPERS {a4 {210 297} a5 {148 210} letter {215.9 279.4}}
    # attributes the block panel edits, with their form widget kind
    variable FIELDS {
        type    combo   size  num     bold  check   color   combo
        align   combo   leading num   gap   num     page    combo
        field   entry   list  check   labelw num    h       num
        zebra   check
        text    text
    }
    variable NEWBLOCK {
        text  {x 20 y 20 w 80}
        pairs {x 120 y 50 w 70 labelw 30}
        table {x 20 y 100 w 170 cols {pos text}}
        image {x 150 y 15 w 40 h 20}
        rule  {x 20 y 100 w 170}
    }
}

proc ::tkutils::tkutemplate::_err {kind msg} {
    return -code error -errorcode [list TKUTILS TKUTEMPLATE $kind] $msg
}

proc ::tkutils::tkutemplate::_require {path} {
    variable state
    if {![info exists state($path,tpl)]} {
        _err NOWIDGET "no tkutemplate widget \"$path\""
    }
}

proc ::tkutils::tkutemplate::_cleanup {path w} {
    variable state
    if {$w eq $path} { array unset state $path,* }
}

proc ::tkutils::tkutemplate::_g {d k {def ""}} {
    if {[dict exists $d $k]} { return [dict get $d $k] }
    return $def
}

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

proc ::tkutils::tkutemplate::widget {path args} {
    variable state
    if {[winfo exists $path]} { _err EXISTS "widget path \"$path\" already exists" }
    array set o {
        -template {} -sample {} -onchange {} -scale 2.5 -gridmm 5
        -font {} -fontbold {} -width 560 -height 640
    }
    array set o [::tkutils::tkuopts::merge TKUTEMPLATE [array get o] $args]

    ttk::frame $path
    bind $path <Destroy> [list ::tkutils::tkutemplate::_cleanup $path %W]
    foreach k {-onchange -scale -gridmm -font -fontbold} { set state($path,$k) $o($k) }
    set state($path,sample) $o(-sample)
    set state($path,sel) ""
    set state($path,syncing) 0
    set state($path,tpl) [_normalize $o(-template)]

    _buildToolbar $path
    ttk::panedwindow $path.pw -orient horizontal
    ttk::label $path.status -anchor w -foreground "#a01010"
    pack $path.tb -side top -fill x
    pack $path.status -side bottom -fill x
    pack $path.pw -side top -fill both -expand 1

    set lc [::tkutils::tkulayoutcanvas::widget $path.pw.lc \
        -scale $o(-scale) -gridmm $o(-gridmm) -width $o(-width) -height $o(-height) \
        -onchange [list ::tkutils::tkutemplate::_fromCanvas $path] \
        -onselect [list ::tkutils::tkutemplate::_onSelect $path]]
    $path.pw add $lc -weight 3

    ttk::notebook $path.pw.nb
    $path.pw add $path.pw.nb -weight 1
    _buildBlockTab $path
    _buildColumnsTab $path
    _buildPageTab $path

    _toCanvas $path
    _syncForms $path
    return $path
}

# Fills what a template must have; keeps block order.
proc ::tkutils::tkutemplate::_normalize {tpl} {
    if {$tpl eq ""} { set tpl {blocks {}} }
    if {[catch {dict size $tpl}] || ![dict exists $tpl blocks]
            || [catch {dict size [dict get $tpl blocks]}]} {
        _err VALUE "a template is a dict with a dict \"blocks\""
    }
    # rebuilt as plain dicts: a template read from a file compares equal
    # to the same template built in a program
    set out [dict create]
    dict for {k v} $tpl { if {$k ne "blocks"} { dict set out $k $v } }
    foreach {k v} {paper a4 margin 20 size 10} {
        if {![dict exists $out $k]} { dict set out $k $v }
    }
    set blocks [dict create]
    dict for {id b} [dict get $tpl blocks] {
        if {[catch {dict create {*}$b} nb]} { _err VALUE "block \"$id\" is not a dict" }
        dict set blocks $id $nb
    }
    dict set out blocks $blocks
    return $out
}

proc ::tkutils::tkutemplate::_buildToolbar {path} {
    variable TYPES
    set tb $path.tb
    ttk::frame $tb -padding {2 2}
    ttk::menubutton $tb.add -text "Add block" -menu $tb.add.m
    menu $tb.add.m -tearoff 0
    foreach t $TYPES {
        $tb.add.m add command -label $t \
            -command [list ::tkutils::tkutemplate::_addNew $path $t]
    }
    ttk::button $tb.del -text "Delete" -command [list ::tkutils::tkutemplate::_deleteSel $path]
    ttk::button $tb.up -text "Up" -command [list ::tkutils::tkutemplate::_moveSel $path up]
    ttk::button $tb.down -text "Down" -command [list ::tkutils::tkutemplate::_moveSel $path down]
    ttk::separator $tb.s1 -orient vertical
    ttk::button $tb.load -text "Load…" -command [list ::tkutils::tkutemplate::_loadAsk $path]
    ttk::button $tb.save -text "Save…" -command [list ::tkutils::tkutemplate::_saveAsk $path]
    ttk::button $tb.prev -text "Preview" -command [list ::tkutils::tkutemplate::_previewShow $path]
    pack $tb.add $tb.del $tb.up $tb.down -side left -padx 2
    pack $tb.s1 -side left -fill y -padx 6
    pack $tb.load $tb.save -side left -padx 2
    pack $tb.prev -side right -padx 2
}

proc ::tkutils::tkutemplate::_buildBlockTab {path} {
    variable FIELDS
    variable TYPES
    variable PAGES
    variable ALIGNS
    set f $path.pw.nb.block
    ttk::frame $f -padding 6
    $path.pw.nb add $f -text "Block"
    ttk::label $f.lid -text "Id"
    ttk::entry $f.id -textvariable ::tkutils::tkutemplate::state($path,f,id) -width 16
    bind $f.id <Return> [list ::tkutils::tkutemplate::_rename $path]
    grid $f.lid $f.id -sticky w -pady 2
    set row 1
    foreach {k kind} $FIELDS {
        set var ::tkutils::tkutemplate::state($path,f,$k)
        ttk::label $f.l$k -text $k
        switch -- $kind {
            num - entry {
                ttk::entry $f.e$k -textvariable $var -width [expr {$kind eq "num" ? 8 : 16}]
                bind $f.e$k <Return>   [list ::tkutils::tkutemplate::_apply $path $k]
                bind $f.e$k <FocusOut> [list ::tkutils::tkutemplate::_apply $path $k]
            }
            check {
                ttk::checkbutton $f.e$k -variable $var \
                    -command [list ::tkutils::tkutemplate::_apply $path $k]
            }
            combo {
                set vals [switch -- $k {
                    type  { set TYPES }
                    page  { set PAGES }
                    align { set ALIGNS }
                    color { list text muted accent rule }
                }]
                ttk::combobox $f.e$k -textvariable $var -values $vals -width 10
                if {$k ne "color"} { $f.e$k configure -state readonly }
                bind $f.e$k <<ComboboxSelected>> [list ::tkutils::tkutemplate::_apply $path $k]
                bind $f.e$k <Return>   [list ::tkutils::tkutemplate::_apply $path $k]
                bind $f.e$k <FocusOut> [list ::tkutils::tkutemplate::_apply $path $k]
            }
            text {
                text $f.e$k -width 24 -height 4 -wrap word -undo 1
                bind $f.e$k <FocusOut> [list ::tkutils::tkutemplate::_apply $path $k]
            }
        }
        grid $f.l$k $f.e$k -sticky nw -pady 2
        incr row
    }
    ttk::label $f.hint -wraplength 220 -foreground gray35 -text \
        "y 0 places a block in the flow, below the block before it. {key} in text is\
         replaced from the data, {page} and {pages} by the page numbers."
    grid $f.hint - -sticky w -pady {8 0}
}

proc ::tkutils::tkutemplate::_buildColumnsTab {path} {
    variable ALIGNS
    set f $path.pw.nb.cols
    ttk::frame $f -padding 6
    $path.pw.nb add $f -text "Columns"
    ttk::treeview $f.tv -columns {key title w align} -show headings -height 8 \
        -selectmode browse
    foreach c {key title w align} wd {70 110 40 50} {
        $f.tv heading $c -text $c
        $f.tv column $c -width $wd -stretch [expr {$c eq "title"}]
    }
    bind $f.tv <<TreeviewSelect>> [list ::tkutils::tkutemplate::_colPick $path]
    grid $f.tv - - - -sticky nsew
    set r 1
    foreach k {key title w} {
        ttk::label $f.l$k -text $k
        ttk::entry $f.e$k -textvariable ::tkutils::tkutemplate::state($path,c,$k) -width 12
        bind $f.e$k <Return> [list ::tkutils::tkutemplate::_colApply $path]
        grid $f.l$k $f.e$k - - -sticky w -pady 1
    }
    ttk::label $f.lalign -text align
    ttk::combobox $f.ealign -textvariable ::tkutils::tkutemplate::state($path,c,align) \
        -values $ALIGNS -state readonly -width 8
    bind $f.ealign <<ComboboxSelected>> [list ::tkutils::tkutemplate::_colApply $path]
    grid $f.lalign $f.ealign - - -sticky w -pady 1
    ttk::frame $f.bt
    foreach {n t a} {add Add add del Delete del up Up up down Down down} {
        ttk::button $f.bt.$n -text $t -command [list ::tkutils::tkutemplate::_colCmd $path $a]
        pack $f.bt.$n -side left -padx 2
    }
    grid $f.bt - - - -sticky w -pady {6 0}
    ttk::label $f.hint -wraplength 220 -foreground gray35 -text \
        "Columns without w share the width that is left. Only for blocks of type table."
    grid $f.hint - - - -sticky w -pady {8 0}
    grid rowconfigure $f 0 -weight 1
    grid columnconfigure $f 3 -weight 1
}

proc ::tkutils::tkutemplate::_buildPageTab {path} {
    variable PAPERS
    set f $path.pw.nb.page
    ttk::frame $f -padding 6
    $path.pw.nb add $f -text "Page"
    foreach k {paper margin top bottom size accent muted} {
        set var ::tkutils::tkutemplate::state($path,p,$k)
        ttk::label $f.l$k -text $k
        if {$k eq "paper"} {
            ttk::combobox $f.e$k -textvariable $var -values [dict keys $PAPERS] \
                -state readonly -width 8
            bind $f.e$k <<ComboboxSelected>> [list ::tkutils::tkutemplate::_pageApply $path]
        } else {
            ttk::entry $f.e$k -textvariable $var -width 12
            bind $f.e$k <Return>   [list ::tkutils::tkutemplate::_pageApply $path]
            bind $f.e$k <FocusOut> [list ::tkutils::tkutemplate::_pageApply $path]
        }
        grid $f.l$k $f.e$k -sticky w -pady 2
    }
    ttk::label $f.hint -wraplength 220 -foreground gray35 -text \
        "Sizes in mm, font size in points. top and bottom: where the flow starts\
         and stops on a page. accent, muted: colours as \"r g b\" (0..1)."
    grid $f.hint - -sticky w -pady {8 0}
}

# ---------------------------------------------------------------------------
# Template <-> canvas
# ---------------------------------------------------------------------------

# Canvas blocks: geometry only, h estimated from type and sample data.
proc ::tkutils::tkutemplate::_toCanvas {path} {
    variable state
    variable PAPERS
    set tpl $state($path,tpl)
    set margin [_g $tpl margin 20]
    lassign [_paper $tpl] pw ph
    set blocks [dict create]
    dict for {id b} [dict get $tpl blocks] {
        set x [_g $b x $margin]
        set w [_g $b w [expr {$pw - 2 * $margin}]]
        dict set blocks $id [dict create label $id x $x y [_g $b y 0] w $w \
            h [_height $path $id $b] show [_g $b show 1]]
    }
    set lc $path.pw.lc
    set state($path,syncing) 1
    set paper [_g $tpl paper a4]
    if {[llength $paper] == 2} { set paper [join $paper x] }
    ::tkutils::tkulayoutcanvas::configure $lc -paper $paper -margin $margin \
        -blockorder [dict keys $blocks]
    ::tkutils::tkulayoutcanvas::setBlocks $lc $blocks
    if {$state($path,sel) ne "" && [dict exists $blocks $state($path,sel)]} {
        ::tkutils::tkulayoutcanvas::select $lc $state($path,sel)
    }
    set state($path,syncing) 0
}

proc ::tkutils::tkutemplate::_paper {tpl} {
    variable PAPERS
    set p [_g $tpl paper a4]
    if {[dict exists $PAPERS $p]} { return [dict get $PAPERS $p] }
    if {[llength $p] == 2} { return $p }
    return {210 297}
}

# Height on the canvas in mm: what the block would roughly need.
proc ::tkutils::tkutemplate::_height {path id b} {
    variable state
    if {[dict exists $b h]} { return [dict get $b h] }
    set size [_g $b size [_g $state($path,tpl) size 10]]
    set lh [expr {[_g $b leading [expr {$size * 1.3}]] * 25.4 / 72.0}]
    set v [_sampleFor $path $id $b]
    # sample data of another shape (a type just changed) must not break this
    if {[catch {llength $v} len]} { set len 1 }
    switch -- [_g $b type text] {
        rule  { return 1 }
        pairs { set n [expr {max(1, $len / 2)}] }
        table { set n [expr {min(12, $len) + 1}] }
        default {
            if {[_g $b list 0]} { set n $len } else { set n [llength [split $v \n]] }
        }
    }
    return [format %.1f [expr {max(1, $n) * $lh + 1}]]
}

# Geometry back from the canvas, merged so every other key stays.
proc ::tkutils::tkutemplate::_fromCanvas {path lc blocks} {
    variable state
    if {$state($path,syncing)} return
    set tpl $state($path,tpl)
    set merged [::tclutils::tulayout::mergeLayout $tpl [dict create blocks $blocks]]
    # h only where the template has one (an image); the canvas h is an estimate
    dict for {id b} [dict get $merged blocks] {
        foreach k {x y w} {
            if {[dict exists $b $k]} {
                dict set merged blocks $id $k [_num [dict get $b $k]]
            }
        }
    }
    set state($path,tpl) $merged
    _syncBlockForm $path
    _changed $path
}

# 25.0 -> 25, 27.5 stays
proc ::tkutils::tkutemplate::_num {v} {
    if {[string is double -strict $v] && $v == round($v)} { return [expr {int(round($v))}] }
    return $v
}

proc ::tkutils::tkutemplate::_changed {path} {
    variable state
    if {$state($path,-onchange) ne ""} {
        uplevel #0 [list {*}$state($path,-onchange) $path $state($path,tpl)]
    }
}

proc ::tkutils::tkutemplate::_onSelect {path lc id} {
    variable state
    if {$state($path,syncing)} return
    set state($path,sel) $id
    _syncBlockForm $path
    _syncColumns $path
}

# ---------------------------------------------------------------------------
# Forms
# ---------------------------------------------------------------------------

proc ::tkutils::tkutemplate::_syncForms {path} {
    _syncBlockForm $path
    _syncColumns $path
    _syncPage $path
}

proc ::tkutils::tkutemplate::_syncBlockForm {path} {
    variable state
    variable FIELDS
    set f $path.pw.nb.block
    set id $state($path,sel)
    set has [expr {$id ne "" && [dict exists $state($path,tpl) blocks $id]}]
    set b [expr {$has ? [dict get $state($path,tpl) blocks $id] : {}}]
    set state($path,syncing) 1
    set state($path,f,id) $id
    foreach {k kind} $FIELDS {
        set state($path,f,$k) [_g $b $k [_fieldDefault $k]]
        if {$kind eq "text"} {
            $f.e$k configure -state normal
            $f.e$k delete 1.0 end
            $f.e$k insert end [_g $b $k]
        }
        set st [expr {$has ? "normal" : "disabled"}]
        if {$kind eq "combo" && $k ne "color" && $has} { set st readonly }
        catch {$f.e$k configure -state $st}
    }
    $f.id configure -state [expr {$has ? "normal" : "disabled"}]
    set state($path,syncing) 0
}

proc ::tkutils::tkutemplate::_fieldDefault {k} {
    switch -- $k {
        type  { return text }
        bold - list - zebra { return 0 }
        align { return left }
        page  { return first }
    }
    return ""
}

# Takes one field of the block form into the template.
proc ::tkutils::tkutemplate::_apply {path k} {
    variable state
    if {$state($path,syncing)} return
    set id $state($path,sel)
    if {$id eq "" || ![dict exists $state($path,tpl) blocks $id]} return
    if {$k eq "text"} {
        set v [string trimright [$path.pw.nb.block.etext get 1.0 end] \n]
    } else {
        set v [string trim $state($path,f,$k)]
    }
    if {[catch {setBlock $path $id $k $v} msg]} {
        bell
        _status $path $msg
        _syncBlockForm $path
    } else {
        _status $path ""
    }
}

proc ::tkutils::tkutemplate::_status {path msg} {
    $path.status configure -text $msg
}

proc ::tkutils::tkutemplate::_syncPage {path} {
    variable state
    set tpl $state($path,tpl)
    lassign [_paper $tpl] pw ph
    set m [_g $tpl margin 20]
    set state($path,syncing) 1
    set p [_g $tpl paper a4]
    set state($path,p,paper)  [expr {[llength $p] == 2 ? "a4" : $p}]
    set state($path,p,margin) $m
    set state($path,p,top)    [_g $tpl top $m]
    set state($path,p,bottom) [_g $tpl bottom [expr {$ph - $m}]]
    set state($path,p,size)   [_g $tpl size 10]
    set state($path,p,accent) [_g [_g $tpl theme] accent]
    set state($path,p,muted)  [_g [_g $tpl theme] muted]
    set state($path,syncing) 0
}

proc ::tkutils::tkutemplate::_pageApply {path} {
    variable state
    if {$state($path,syncing)} return
    set tpl $state($path,tpl)
    dict set tpl paper $state($path,p,paper)
    foreach k {margin top bottom size} {
        set v [string trim $state($path,p,$k)]
        if {$v eq ""} { dict unset tpl $k; continue }
        if {![string is double -strict $v] || $v < 0} {
            bell; _status $path "$k must be a number >= 0"; _syncPage $path; return
        }
        dict set tpl $k $v
    }
    foreach k {accent muted} {
        set v [string trim $state($path,p,$k)]
        if {$v eq ""} {
            if {[dict exists $tpl theme $k]} { dict unset tpl theme $k }
            continue
        }
        if {![_isRgb $v]} { bell; _status $path "$k is \"r g b\" (0..1)"; _syncPage $path; return }
        dict set tpl theme $k $v
    }
    set state($path,tpl) $tpl
    _status $path ""
    _toCanvas $path
    _changed $path
}

proc ::tkutils::tkutemplate::_isRgb {v} {
    if {[llength $v] != 3} { return 0 }
    foreach c $v {
        if {![string is double -strict $c] || $c < 0 || $c > 1} { return 0 }
    }
    return 1
}

# -- columns of a table block ------------------------------------------------

proc ::tkutils::tkutemplate::_cols {path} {
    variable state
    set id $state($path,sel)
    if {$id eq "" || [_g [dict get $state($path,tpl) blocks $id] type text] ne "table"} {
        return ""
    }
    set out {}
    foreach c [_g [dict get $state($path,tpl) blocks $id] cols] {
        if {[llength $c] == 1} { set c [dict create key $c] }
        lappend out $c
    }
    return $out
}

proc ::tkutils::tkutemplate::_syncColumns {path} {
    variable state
    set f $path.pw.nb.cols
    $f.tv delete [$f.tv children {}]
    set id $state($path,sel)
    set isTable [expr {$id ne "" && [dict exists $state($path,tpl) blocks $id]
        && [_g [dict get $state($path,tpl) blocks $id] type text] eq "table"}]
    set st [expr {$isTable ? "!disabled" : "disabled"}]
    foreach w [winfo children $f] { catch {$w state $st} }
    foreach w [winfo children $f.bt] { catch {$w state $st} }
    if {!$isTable} return
    set i 0
    foreach c [_cols $path] {
        $f.tv insert {} end -id c$i -values [list [_g $c key] [_g $c title [_g $c key]] \
            [_g $c w] [_g $c align left]]
        incr i
    }
}

proc ::tkutils::tkutemplate::_colPick {path} {
    variable state
    set sel [$path.pw.nb.cols.tv selection]
    if {$sel eq ""} return
    set c [lindex [_cols $path] [string range $sel 1 end]]
    foreach k {key title w} { set state($path,c,$k) [_g $c $k] }
    set state($path,c,align) [_g $c align left]
}

proc ::tkutils::tkutemplate::_setCols {path cols {pick ""}} {
    variable state
    setBlock $path $state($path,sel) cols $cols
    _syncColumns $path
    if {$pick ne "" && $pick >= 0 && $pick < [llength $cols]} {
        $path.pw.nb.cols.tv selection set c$pick
    }
}

proc ::tkutils::tkutemplate::_colApply {path} {
    variable state
    set sel [$path.pw.nb.cols.tv selection]
    if {$sel eq ""} return
    set i [string range $sel 1 end]
    set key [string trim $state($path,c,key)]
    set w [string trim $state($path,c,w)]
    if {$key eq "" || ($w ne "" && (![string is double -strict $w] || $w <= 0))} { bell; return }
    set c [dict create key $key title $state($path,c,title) align $state($path,c,align)]
    if {$w ne ""} { dict set c w $w }
    set cols [_cols $path]
    lset cols $i $c
    if {[catch {_setCols $path $cols $i}]} { bell; _syncColumns $path }
}

proc ::tkutils::tkutemplate::_colCmd {path what} {
    set cols [_cols $path]
    set sel [$path.pw.nb.cols.tv selection]
    set i [expr {$sel eq "" ? -1 : [string range $sel 1 end]}]
    switch -- $what {
        add {
            set n [llength $cols]
            while {[lsearch -exact [lmap c $cols { dict get $c key }] col$n] >= 0} { incr n }
            lappend cols [dict create key col$n title col$n align left]
            set i [expr {[llength $cols] - 1}]
        }
        del {
            if {$i < 0 || [llength $cols] <= 1} { bell; return }
            set cols [lreplace $cols $i $i]
            set i [expr {min($i, [llength $cols] - 1)}]
        }
        up - down {
            set j [expr {$what eq "up" ? $i - 1 : $i + 1}]
            if {$i < 0 || $j < 0 || $j >= [llength $cols]} { bell; return }
            set t [lindex $cols $i]
            lset cols $i [lindex $cols $j]
            lset cols $j $t
            set i $j
        }
    }
    if {[catch {_setCols $path $cols $i}]} { bell; _syncColumns $path }
}

# ---------------------------------------------------------------------------
# Public operations
# ---------------------------------------------------------------------------

proc ::tkutils::tkutemplate::getTemplate {path} {
    _require $path
    variable state
    return $state($path,tpl)
}

proc ::tkutils::tkutemplate::setTemplate {path tpl} {
    _require $path
    variable state
    set state($path,tpl) [_normalize $tpl]
    if {![dict exists $state($path,tpl) blocks $state($path,sel)]} { set state($path,sel) "" }
    _toCanvas $path
    _syncForms $path
    return
}

proc ::tkutils::tkutemplate::setSample {path data} {
    _require $path
    variable state
    if {[catch {dict size $data}]} { _err VALUE "sample data must be a dict" }
    set state($path,sample) $data
    _toCanvas $path
    return
}

proc ::tkutils::tkutemplate::select {path id} {
    _require $path
    variable state
    if {$id ne "" && ![dict exists $state($path,tpl) blocks $id]} {
        _err BLOCK "unknown block \"$id\""
    }
    set state($path,sel) $id
    set state($path,syncing) 1
    ::tkutils::tkulayoutcanvas::select $path.pw.lc $id
    set state($path,syncing) 0
    _syncBlockForm $path
    _syncColumns $path
    return
}

# Sets block attributes; an empty value removes the key. Checks values.
proc ::tkutils::tkutemplate::setBlock {path id args} {
    _require $path
    variable state
    variable TYPES
    variable PAGES
    variable ALIGNS
    variable NEWBLOCK
    if {![dict exists $state($path,tpl) blocks $id]} { _err BLOCK "unknown block \"$id\"" }
    if {[llength $args] % 2} { _err VALUE "setBlock: key value pairs expected" }
    set b [dict get $state($path,tpl) blocks $id]
    foreach {k v} $args {
        # an empty value removes the attribute -- not for those a block
        # cannot do without
        if {$v eq "" && $k ni {text type cols}} {
            dict unset b $k
            continue
        }
        switch -- $k {
            x - y - w - h - size - leading - gap - labelw {
                if {![string is double -strict $v] || $v < 0} {
                    _err VALUE "$k must be a number >= 0, not \"$v\""
                }
                set v [_num $v]
            }
            bold - list - show - zebra - header {
                if {![string is boolean -strict $v]} { _err VALUE "$k must be 0 or 1" }
                set v [expr {$v ? 1 : 0}]
            }
            type {
                if {$v ni $TYPES} { _err VALUE "type must be one of: [join $TYPES {, }]" }
                # a new type gets what it cannot do without
                if {$v eq "table" && ![dict exists $b cols]} { dict set b cols {pos text} }
                if {$v eq "image" && ![dict exists $b h]} { dict set b h 20 }
            }
            page {
                if {$v ni $PAGES} { _err VALUE "page must be one of: [join $PAGES {, }]" }
                if {$v ne "first" && [_g $b y 0] == 0} {
                    _err VALUE "page $v needs a fixed y"
                }
            }
            align {
                if {$v ni $ALIGNS} { _err VALUE "align must be one of: [join $ALIGNS {, }]" }
            }
            color {
                if {[llength $v] != 1 && ![_isRgb $v]} {
                    _err VALUE "color is a theme name or \"r g b\" (0..1)"
                }
            }
            cols {
                if {![llength $v]} { _err VALUE "a table needs at least one column" }
            }
            text - field {}
            default { _err VALUE "unknown block attribute \"$k\"" }
        }
        if {$k eq "text" && $v eq ""} { dict unset b text; continue }
        dict set b $k $v
    }
    dict set state($path,tpl) blocks $id $b
    _toCanvas $path
    _syncBlockForm $path
    _changed $path
    return $b
}

proc ::tkutils::tkutemplate::addBlock {path id {type text}} {
    _require $path
    variable state
    variable NEWBLOCK
    variable TYPES
    if {$id eq "" || [string match {*[ {}]*} $id]} { _err VALUE "block id \"$id\" is not usable" }
    if {[dict exists $state($path,tpl) blocks $id]} { _err BLOCK "block \"$id\" exists" }
    if {$type ni $TYPES} { _err VALUE "type must be one of: [join $TYPES {, }]" }
    set b [dict merge [dict create type $type] [dict get $NEWBLOCK $type]]
    if {$type eq "text"} { dict set b text $id }
    dict set state($path,tpl) blocks $id $b
    set state($path,sel) $id
    _toCanvas $path
    _syncForms $path
    _changed $path
    return $id
}

proc ::tkutils::tkutemplate::deleteBlock {path id} {
    _require $path
    variable state
    if {![dict exists $state($path,tpl) blocks $id]} { _err BLOCK "unknown block \"$id\"" }
    dict unset state($path,tpl) blocks $id
    if {$state($path,sel) eq $id} { set state($path,sel) "" }
    _toCanvas $path
    _syncForms $path
    _changed $path
    return
}

# Order matters: a block in the flow follows the one before it.
proc ::tkutils::tkutemplate::moveBlock {path id dir} {
    _require $path
    variable state
    set blocks [dict get $state($path,tpl) blocks]
    set ids [dict keys $blocks]
    set i [lsearch -exact $ids $id]
    if {$i < 0} { _err BLOCK "unknown block \"$id\"" }
    set j [expr {$dir eq "up" ? $i - 1 : $i + 1}]
    if {$dir ni {up down}} { _err VALUE "direction is up or down" }
    if {$j < 0 || $j >= [llength $ids]} { return 0 }
    set t [lindex $ids $i]
    lset ids $i [lindex $ids $j]
    lset ids $j $t
    set new [dict create]
    foreach k $ids { dict set new $k [dict get $blocks $k] }
    dict set state($path,tpl) blocks $new
    _toCanvas $path
    _changed $path
    return 1
}

proc ::tkutils::tkutemplate::_rename {path} {
    variable state
    set old $state($path,sel)
    set new [string trim $state($path,f,id)]
    if {$old eq "" || $new eq $old} return
    set blocks [dict get $state($path,tpl) blocks]
    if {$new eq "" || [dict exists $blocks $new] || [string match {*[ {}]*} $new]} {
        bell
        set state($path,f,id) $old
        return
    }
    set out [dict create]
    dict for {k b} $blocks {
        dict set out [expr {$k eq $old ? $new : $k}] $b
    }
    dict set state($path,tpl) blocks $out
    set state($path,sel) $new
    _toCanvas $path
    _changed $path
}

proc ::tkutils::tkutemplate::loadFile {path file} {
    _require $path
    if {[catch {
        set fh [open $file r]
        fconfigure $fh -encoding utf-8
        set data [read $fh]
        close $fh
    } msg]} {
        _err FILE "cannot read \"$file\": $msg"
    }
    setTemplate $path $data
    variable state
    _changed $path
    return $state($path,tpl)
}

proc ::tkutils::tkutemplate::saveFile {path file} {
    _require $path
    variable state
    if {[catch {
        set fh [open $file w]
        fconfigure $fh -encoding utf-8
        puts $fh [_pretty $state($path,tpl)]
        close $fh
    } msg]} {
        _err FILE "cannot write \"$file\": $msg"
    }
    return $file
}

# One block per line, readable in a text editor and in a diff.
proc ::tkutils::tkutemplate::_pretty {tpl} {
    set out ""
    dict for {k v} $tpl {
        if {$k eq "blocks"} continue
        append out [list $k $v] \n
    }
    append out "blocks \{\n"
    dict for {id b} [dict get $tpl blocks] {
        append out "    " [list $id $b] \n
    }
    append out "\}\n"
    return $out
}

# ---------------------------------------------------------------------------
# Sample data and preview
# ---------------------------------------------------------------------------

# What a block shows in the preview: the sample data, else a stand-in.
proc ::tkutils::tkutemplate::_sampleFor {path id b} {
    variable state
    set f [_g $b field $id]
    if {[dict exists $state($path,sample) $f]} { return [dict get $state($path,sample) $f] }
    if {[dict exists $b text]} { return [dict get $b text] }
    switch -- [_g $b type text] {
        pairs { return [list Label value "Label 2" "value 2"] }
        table {
            set rows {}
            for {set r 1} {$r <= 3} {incr r} {
                set row {}
                foreach c [_g $b cols] {
                    set k [expr {[llength $c] == 1 ? $c : [_g $c key]}]
                    dict set row $k "$k $r"
                }
                lappend rows $row
            }
            return $rows
        }
        image { return "" }
    }
    return $id
}

proc ::tkutils::tkutemplate::_sample {path} {
    variable state
    set data $state($path,sample)
    dict for {id b} [dict get $state($path,tpl) blocks] {
        set f [_g $b field $id]
        if {[dict exists $data $f] || [dict exists $b text]} continue
        set v [_sampleFor $path $id $b]
        if {$v ne ""} { dict set data $f $v }
    }
    return $data
}

# Draws the template with the sample data; returns the PDF file. Needs
# pdf4tcltemplate (pdf4tcllib), loaded here and not before.
proc ::tkutils::tkutemplate::preview {path {file ""}} {
    _require $path
    variable state
    # pdf4tcllib loads even without pdf4tcl (its own require is caught), so
    # pdf4tcl is checked on its own: everything that is missing for the
    # preview is {TKUTILS TKUTEMPLATE PREVIEW}, never an unknown command
    if {[catch {package require pdf4tcltemplate} msg]} {
        _err PREVIEW "preview needs pdf4tcltemplate (pdf4tcllib): $msg"
    }
    if {[catch {package require pdf4tcl} msg] || [info commands ::pdf4tcl::new] eq ""} {
        _err PREVIEW "preview needs pdf4tcl: [expr {$msg ne "" ? $msg : "::pdf4tcl::new missing"}]"
    }
    set font $state($path,-font)
    if {$font eq ""} { catch {::pdf4tcllib::fonts::init} }
    set opts {}
    if {$font ne ""} { lappend opts -font $font }
    if {$state($path,-fontbold) ne ""} { lappend opts -fontbold $state($path,-fontbold) }
    lassign [_paper $state($path,tpl)] pw ph
    set paper [_g $state($path,tpl) paper a4]
    if {[llength $paper] == 2} { set paper [list [expr {$pw * 72 / 25.4}] [expr {$ph * 72 / 25.4}]] }
    set temp 0
    if {$file eq ""} {
        set fh [file tempfile file tkutemplate.pdf]
        close $fh
        set temp 1
    }
    set pdf ""
    try {
        set pdf [::pdf4tcl::new %AUTO% -paper $paper]
        ::pdf4tcllib::template::render $pdf $state($path,tpl) [_sample $path] {*}$opts
        $pdf write -file $file
    } on error {msg} {
        if {$temp} { catch {file delete $file} }
        _err PREVIEW $msg
    } finally {
        if {$pdf ne ""} { catch {$pdf destroy} }
    }
    return $file
}

# -- toolbar commands ------------------------------------------------------------

proc ::tkutils::tkutemplate::_addNew {path type} {
    variable state
    set n 1
    while {[dict exists $state($path,tpl) blocks $type$n]} { incr n }
    addBlock $path $type$n $type
    focus $path.pw.nb.block.id
}

proc ::tkutils::tkutemplate::_deleteSel {path} {
    variable state
    if {$state($path,sel) eq ""} { bell; return }
    deleteBlock $path $state($path,sel)
}

proc ::tkutils::tkutemplate::_moveSel {path dir} {
    variable state
    if {$state($path,sel) eq "" || ![moveBlock $path $state($path,sel) $dir]} { bell }
}

proc ::tkutils::tkutemplate::_loadAsk {path} {
    set f [tk_getOpenFile -parent $path -filetypes {{Template .tcl} {All *}}]
    if {$f eq ""} return
    if {[catch {loadFile $path $f} msg]} {
        tk_messageBox -parent $path -icon error -message $msg
    }
}

proc ::tkutils::tkutemplate::_saveAsk {path} {
    set f [tk_getSaveFile -parent $path -defaultextension .tcl \
        -filetypes {{Template .tcl} {All *}}]
    if {$f eq ""} return
    if {[catch {saveFile $path $f} msg]} {
        tk_messageBox -parent $path -icon error -message $msg
    }
}

proc ::tkutils::tkutemplate::_previewShow {path} {
    if {[catch {preview $path} f]} {
        tk_messageBox -parent $path -icon error -message $f
        return
    }
    catch {::tclutils::tuopen::launch $f}
}

package provide tkutils::tkutemplate 0.1
