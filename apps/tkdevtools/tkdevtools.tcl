#!/usr/bin/env wish
# ===========================================================================
# Tcl/Tk Developer Toolbox -- a single app that bundles reference / helper
# views a Tk programmer reaches for: runtime (Tcl/Tk, OS, packages, paths,
# display, env), named colors, Unicode / graphemes, fonts, units, timezones,
# cursors, relief/anchor, keysym probe, ttk theme/style browser, widget
# explorer, pack/grid playgrounds, regexp and format/scan, package copies,
# path / glob / program / encoding-profile probes, font aliases and number
# formatting. Navigation tree
# on the left; tables / trees on the right. Belongs to tkutils.
#
#   wish tkdevtools.tcl
#   tclsh tkdevtools.tcl --shot out.png ?toolKey?   (e.g. tcltk, themes)
# ===========================================================================

# locate tkutils / tclutils via the shared bootstrap (as the other apps do):
# resolves TCLUTILS_TM/TKUTILS_TM, the install/share/XDG locations and a
# side-by-side source checkout -- a missing package then fails loudly later.
source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]

package require Tk
package require tablelist
package require tclutils::tucolor
package require tclutils::tustr 0.2       ;# graphemes, isPrintable
package require tclutils::tudate 0.2      ;# zones
package require tclutils::tupkgfinder 0.2 ;# package sources, copies, search paths
package require tclutils::tupath          ;# clean (Paths)
package require tclutils::tunum 0.4       ;# format, half away from zero
package require tclutils::tuappinfo       ;# "Copy report"
package require tkutils::tkutablelist 0.4 ;# scrolled, sortable tables
package require tkutils::tkuunits 0.1     ;# px/pt/mm/cm/inch
catch {package require tkutils::tkutlsort}
catch {package require tkutils::tkutlfind}
catch {package require tkutils::tkutlclip}

# ----------------------------------------------------------------------------
# helper: a scrolled, sortable table from tkutils::tkutablelist (frame with
# scrollbars, stripes, -exportselection 0), packed into PARENT. COLS are
# tablelist triples {width title align ...}; ARGS go to the tablelist
# itself (-height). Returns the tablelist path.
# ----------------------------------------------------------------------------
proc scrolledTable {parent cols args} {
    set spec {}
    foreach {w title align} $cols {
        lappend spec [list $title -width $w -align $align]
    }
    set fr [::tkutils::tkutablelist::widget $parent.tf -columns $spec \
        -stripes #f4f4f4]
    set t $fr.tbl
    if {[llength $args]} { $t configure {*}$args }
    pack $fr -fill both -expand 1
    return $t
}

# ============================ Colors =======================================
proc buildColors {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Find:"
    entry $bar.e -textvariable ::colorQ -width 20
    label $bar.n -textvariable ::colorStatus
    pack $bar.l $bar.e $bar.n -side left -padx 3
    pack $bar -fill x -pady 3
    set t [scrolledTable $f \
        {6 "" center 20 Name left 9 Hex left 5 R right 5 G right 5 B right \
         5 H right 5 S right 5 V right} -height 20]
    foreach name [::tclutils::tucolor::names] {
        lassign [::tclutils::tucolor::rgb $name]   r g b
        lassign [::tclutils::tucolor::toHsv $name] h s v
        set hex [::tclutils::tucolor::hex $name]
        $t insert end [list "" $name $hex $r $g $b $h $s $v]
        $t cellconfigure [expr {[$t size]-1}],0 -background $hex
    }
    set ::colorStatus "[$t size] colors"
    catch {::tkutils::tkutlsort::columns $t \
        {1 string 2 string 3 integer 4 integer 5 integer 6 integer 7 integer 8 integer}}
    catch {::tkutils::tkutlclip::installBindings $t}
    if {[llength [info commands ::tkutils::tkutlfind::find]]} {
        bind $bar.e <KeyRelease> [list apply {{t} {
            set ::colorStatus "[::tkutils::tkutlfind::find $t $::colorQ -columns {1 2}] match(es)"
        }} $t]
    }
}

# ============================ Characters ====================================
set ::charPresets [dict create \
    "ASCII (0x20-0x7E)"           {0x20 0x7E} \
    "Latin-1 (incl. oe ae ue ss)" {0xA0 0xFF} \
    "Basic Latin + Latin-1"       {0x20 0x7E 0xA0 0xFF} \
    "Currency (incl. euro)"       {0x20A0 0x20BF} \
    "Box drawing"                 {0x2500 0x257F} \
    "Arrows"                      {0x2190 0x21FF}]
proc buildChars {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Range:"
    ttk::combobox $bar.cb -textvariable ::charPreset -state readonly -width 28 \
        -values [dict keys $::charPresets]
    label $bar.n -textvariable ::charStatus
    pack $bar.l $bar.cb $bar.n -side left -padx 3
    pack $bar -fill x -pady 3
    set t [scrolledTable $f \
        {6 Char center 10 "\\u" left 10 "U+" left 7 Dec right 7 Hex right} -height 18]
    $t columnconfigure 0 -font {Helvetica 16}
    set ::charTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    bind $bar.cb <<ComboboxSelected>> charFill
    set ::charPreset "Basic Latin + Latin-1"
    charFill
}
proc charFill {} {
    set t $::charTable
    $t delete 0 end
    set n 0
    foreach {first last} [dict get $::charPresets $::charPreset] {
        set first [expr {$first}]; set last [expr {$last}]
        for {set cp $first} {$cp <= $last} {incr cp} {
            if {![::tclutils::tustr::isPrintable [format %c $cp]]} continue
            $t insert end [list [format %c $cp] [format {\u%04x} $cp] \
                [format {U+%04X} $cp] $cp [format %X $cp]]
            incr n
        }
    }
    set ::charStatus "$n characters"
}

# ============================ Fonts =========================================
proc buildFonts {f} {
    catch {font create tdtPreview}
    set ::fontExtra [join [lmap c {196 214 220 228 246 252 223 8364} {format %c $c}] ""]
    set ::fontSample "The quick brown fox 0123456789 $::fontExtra"
    set ::fontSize 18; set ::fontBold 0; set ::fontItalic 0; set ::fontUnderline 0

    set left [frame $f.left]
    label $left.l -text "Families ([llength [font families]]):"
    entry $left.f -textvariable ::fontFilter
    listbox $left.lb -width 26 -height 20 -exportselection 0 \
        -yscrollcommand [list $left.sb set]
    scrollbar $left.sb -command [list $left.lb yview]
    grid $left.l  -row 0 -column 0 -columnspan 2 -sticky w
    grid $left.f  -row 1 -column 0 -columnspan 2 -sticky ew
    grid $left.lb -row 2 -column 0 -sticky nsew
    grid $left.sb -row 2 -column 1 -sticky ns
    grid rowconfigure $left 2 -weight 1
    grid columnconfigure $left 0 -weight 1
    pack $left -side left -fill y -padx 4 -pady 4

    set r [frame $f.right]
    set ctl [frame $r.ctl]
    label $ctl.sl -text "Size:"
    spinbox $ctl.sp -from 6 -to 96 -width 4 -textvariable ::fontSize -command fontApply
    checkbutton $ctl.b -text Bold      -variable ::fontBold      -command fontApply
    checkbutton $ctl.i -text Italic    -variable ::fontItalic    -command fontApply
    checkbutton $ctl.u -text Underline -variable ::fontUnderline -command fontApply
    pack $ctl.sl $ctl.sp $ctl.b $ctl.i $ctl.u -side left -padx 3
    pack $ctl -fill x -pady 4
    label $r.fam -textvariable ::fontFamLabel -anchor w -fg #336
    pack $r.fam -fill x -padx 4
    entry $r.txt -textvariable ::fontSample
    pack $r.txt -fill x -padx 4 -pady 4
    bind $r.txt <KeyRelease> [list apply {{w} {$w configure -text $::fontSample}} $r.prev]
    label $r.prev -textvariable ::fontSample -font tdtPreview -anchor w \
        -justify left -wraplength 420 -height 5 -relief sunken -bg white
    pack $r.prev -fill both -expand 1 -padx 4 -pady 4
    label $r.met  -textvariable ::fontMetrics -anchor w -fg #555
    label $r.spec -textvariable ::fontSpec    -anchor w -fg #555
    pack $r.met $r.spec -fill x -padx 4
    pack $r -side left -fill both -expand 1

    set ::fontLb $left.lb
    bind $left.lb <<ListboxSelect>> fontApply
    trace add variable ::fontFilter write {apply {{a b c} {fontFill}}}
    fontFill
}
proc fontFill {} {
    set lb $::fontLb
    $lb delete 0 end
    foreach fam [lsort -dictionary [font families]] {
        if {$::fontFilter eq "" || [string match -nocase *$::fontFilter* $fam]} {
            $lb insert end $fam
        }
    }
    if {[$lb size] > 0} { $lb selection set 0; fontApply }
}
proc fontApply {} {
    set lb $::fontLb
    set sel [$lb curselection]
    if {[llength $sel] == 0} return
    set fam [$lb get [lindex $sel 0]]
    set weight [expr {$::fontBold ? "bold" : "normal"}]
    set slant  [expr {$::fontItalic ? "italic" : "roman"}]
    font configure tdtPreview -family $fam -size $::fontSize \
        -weight $weight -slant $slant -underline $::fontUnderline
    set ::fontFamLabel "$fam  ${::fontSize}pt $weight $slant"
    array set m [font metrics tdtPreview]
    set ::fontMetrics "metrics: ascent $m(-ascent)  descent $m(-descent)  linespace $m(-linespace)  fixed $m(-fixed)"
    set ::fontSpec "spec: \[font create f -family {$fam} -size $::fontSize -weight $weight -slant $slant\]"
}

# ============================ Units =========================================
# conversions: tkutils::tkuunits
proc buildUnits {f} {
    label $f.dpi -fg #336 \
        -text "Display: [format %.1f [winfo fpixels . 1i]] px/inch   (winfo fpixels . 1i)"
    pack $f.dpi -anchor w -padx 6 -pady 4
    set c [labelframe $f.conv -text Convert]
    set ::unitVal 10; set ::unitU mm
    label $c.l -text "Value:"
    entry $c.e -textvariable ::unitVal -width 10
    ttk::combobox $c.u -textvariable ::unitU -width 6 -state readonly \
        -values {px pt mm cm inch}
    label $c.out -textvariable ::unitOut -anchor w -fg #225
    grid $c.l $c.e $c.u -padx 3 -pady 4 -sticky w
    grid $c.out -row 1 -column 0 -columnspan 3 -sticky w -padx 6 -pady {0 6}
    pack $c -fill x -padx 6 -pady 4
    bind $c.e <KeyRelease> unitConvert
    bind $c.u <<ComboboxSelected>> unitConvert
    set ref [labelframe $f.ref -text Reference]
    set t [scrolledTable $ref \
        {10 "Tk spec" left 9 px right 9 pt right 9 mm right 9 cm right 9 inch right} -height 8]
    foreach col {1 2 3 4 5} { $t columnconfigure $col -formatcommand {format %.2f} }
    foreach {val unit spec} {1 px 1  10 px 10  1 pt 1p  12 pt 12p  1 mm 1m \
                             2 mm 2m  1 cm 1c  1 inch 1i  0.5 inch 0.5i} {
        set d [::tkutils::tkuunits::fromPixels [::tkutils::tkuunits::toPixels $val $unit]]
        $t insert end [list $spec [dict get $d px] [dict get $d pt] \
            [dict get $d mm] [dict get $d cm] [dict get $d inch]]
    }
    pack $ref -fill both -expand 1 -padx 6 -pady 4
    unitConvert
}
proc unitConvert {args} {
    if {![string is double -strict $::unitVal]} { set ::unitOut "(enter a number)"; return }
    set d [::tkutils::tkuunits::fromPixels [::tkutils::tkuunits::toPixels $::unitVal $::unitU]]
    set ::unitOut [format "%.1f px  |  %.2f pt  |  %.2f mm  |  %.3f cm  |  %.4f inch" \
        [dict get $d px] [dict get $d pt] [dict get $d mm] [dict get $d cm] [dict get $d inch]]
}

# ============================ Timezones =====================================
proc tzList {} {
    set zones [::tclutils::tudate::zones]
    if {[llength $zones] <= 1} {         ;# no zone database found: a few common ones
        lappend zones Europe/Berlin Europe/London America/New_York \
            America/Los_Angeles Asia/Tokyo Asia/Shanghai Asia/Kolkata \
            Australia/Sydney Pacific/Auckland
    }
    return [lsort -unique $zones]
}
proc buildTz {f} {
    set ::tzZones [tzList]
    set bar [frame $f.bar]
    label $bar.l -text "Filter:"
    entry $bar.e -textvariable ::tzFilter -width 20
    label $bar.n -textvariable ::tzStatus
    pack $bar.l $bar.e $bar.n -side left -padx 3
    pack $bar -fill x -pady 3
    set t [scrolledTable $f \
        {26 Zone left 9 Time right 12 Date center 7 UTC right 6 Abbr left} -height 18]
    set ::tzTable $t
    trace add variable ::tzFilter write {apply {{a b c} {tzFill}}}
    set ::tzFilter ""
    tzFill
}
proc tzFill {} {
    set t $::tzTable
    $t delete 0 end
    foreach z $::tzZones {
        if {$::tzFilter eq "" || [string match -nocase *$::tzFilter* $z]} {
            $t insert end [list $z "" "" "" ""]
        }
    }
    set ::tzStatus "[$t size] zones"
    tzTick
}
proc tzTick {} {
    catch {after cancel $::tzTickId}
    set t $::tzTable
    if {![winfo exists $t]} return
    set now [clock seconds]
    for {set i 0} {$i < [$t size]} {incr i} {
        set z [lindex [$t get $i] 0]
        if {[catch {clock format $now -timezone :$z -format {%H:%M:%S}} hms]} continue
        $t cellconfigure $i,1 -text $hms
        $t cellconfigure $i,2 -text [clock format $now -timezone :$z -format {%Y-%m-%d}]
        $t cellconfigure $i,3 -text [clock format $now -timezone :$z -format {%z}]
        $t cellconfigure $i,4 -text [clock format $now -timezone :$z -format {%Z}]
    }
    set ::tzTickId [after 1000 tzTick]
}

# ============================ Cursors =======================================
set ::cursorNames {
    arrow based_arrow_down based_arrow_up boat bogosity bottom_left_corner
    bottom_right_corner bottom_side bottom_tee box_spiral center_ptr circle
    clock coffee_mug cross cross_reverse crosshair diamond_cross dot dotbox
    double_arrow draft_large draft_small draped_box exchange fleur gobbler
    gumby hand1 hand2 heart icon iron_cross left_ptr left_side left_tee
    ll_angle lr_angle man middlebutton mouse pencil pirate plus question_arrow
    right_ptr right_side right_tee rtl_logo sailboat sb_down_arrow
    sb_h_double_arrow sb_left_arrow sb_right_arrow sb_up_arrow sb_v_double_arrow
    shuttle sizing spider spraycan star target tcross top_left_arrow
    top_left_corner top_right_corner top_side top_tee trek ul_angle umbrella
    ur_angle watch xterm X_cursor
}
proc buildCursors {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Select a cursor, then move the mouse over the preview box:"
    pack $bar.l -side left -padx 4
    pack $bar -fill x -pady 3
    set ::cursorPrev [label $f.prev -text "  preview  " -relief groove -bg white \
        -width 24 -height 3]
    pack $::cursorPrev -pady 4
    set t [scrolledTable $f {26 Cursor left} -height 16]
    foreach c $::cursorNames { $t insert end [list $c] }
    set ::cursorTable $t
    bind $t <<TablelistSelect>> cursorPick
}
proc cursorPick {} {
    set t $::cursorTable
    set sel [$t curselection]
    if {[llength $sel] == 0} return
    set c [lindex [$t get [lindex $sel 0]] 0]
    if {[catch {$::cursorPrev configure -cursor $c}]} {
        $::cursorPrev configure -text "$c (n/a here)"
    } else {
        $::cursorPrev configure -text $c
    }
}

# ====================== Relief / Anchor cheat sheet =========================
proc buildRelief {f} {
    set rf [labelframe $f.relief -text "-relief"]
    foreach rel {flat raised sunken groove ridge solid} {
        label $rf.$rel -text $rel -relief $rel -bd 3 -width 9 -padx 6 -pady 6
        pack $rf.$rel -side left -padx 6 -pady 6
    }
    pack $rf -fill x -padx 6 -pady 6
    set af [labelframe $f.anchor -text "-anchor (text inside a fixed cell)"]
    set i 0
    foreach {a row col} {nw 0 0 n 0 1 ne 0 2 w 1 0 center 1 1 e 1 2 sw 2 0 s 2 1 se 2 2} {
        label $af.$a -text $a -anchor $a -width 8 -height 2 -relief solid -bd 1
        grid $af.$a -row $row -column $col -padx 4 -pady 4 -sticky nsew
    }
    pack $af -padx 6 -pady 6
    set jf [labelframe $f.just -text "-justify (multi-line)"]
    foreach j {left center right} {
        label $jf.$j -text "justify\n$j" -justify $j -relief ridge -bd 2 \
            -width 12 -padx 4 -pady 4
        pack $jf.$j -side left -padx 6 -pady 6
    }
    pack $jf -fill x -padx 6 -pady 6
}

# ============================ Keysym probe ==================================
proc buildKeysym {f} {
    set box [labelframe $f.box -text "Click here, then press keys"]
    label $box.hint -text "(focus this area and press any key / combo)" -fg #555
    pack $box.hint -pady 8
    pack $box -fill x -padx 6 -pady 6
    bind $box <Button-1> [list focus $box]
    set fields [frame $f.fields]
    foreach {lbl var} {Keysym ::ksK Char ::ksA Keycode ::ksk State ::kss} {
        label $fields.l$lbl -text "$lbl:" -anchor e -width 8
        label $fields.v$lbl -textvariable $var -anchor w -fg #225 -width 22 -relief sunken
        grid $fields.l$lbl $fields.v$lbl -sticky w -padx 4 -pady 2
    }
    pack $fields -anchor w -padx 6 -pady 4
    set t [scrolledTable $f {12 Keysym left 8 Char left 9 Keycode right 18 State left} -height 10]
    set ::ksTable $t
    bind $box <KeyPress> {keysymShow %K %A %k %s}
    foreach v {::ksK ::ksA ::ksk ::kss} { set $v "" }
}
proc keysymShow {K A k s} {
    set ::ksK $K; set ::ksA $A; set ::ksk $k; set ::kss $s
    if {[winfo exists $::ksTable]} {
        $::ksTable insert 0 [list $K $A $k $s]
        if {[$::ksTable size] > 200} { $::ksTable delete end }
    }
}

# ============================ ttk Themes (tree) =============================
proc buildThemes {f} {
    # ---- left: theme + element tree --------------------------------------
    set left [ttk::frame $f.left]
    ttk::label $left.l -text "Themes / elements (click a theme to apply):"
    ttk::treeview $left.tv -show tree -height 22 \
        -yscrollcommand [list $left.sb set]
    ttk::scrollbar $left.sb -orient vertical -command [list $left.tv yview]
    grid $left.l  -row 0 -column 0 -columnspan 2 -sticky w
    grid $left.tv -row 1 -column 0 -sticky nsew
    grid $left.sb -row 1 -column 1 -sticky ns
    grid rowconfigure $left 1 -weight 1
    pack $left -side left -fill y -padx 4 -pady 4
    set ::themeTree $left.tv

    # ---- right: notebook (widget preview + style inspector) --------------
    set nb [ttk::notebook $f.nb]
    pack $nb -side left -fill both -expand 1 -padx 4 -pady 4

    set pv [ttk::frame $nb.pv -padding 6]
    themeBuildPreview $pv
    $nb add $pv -text "Widget preview"

    set ins [ttk::frame $nb.ins -padding 6]
    themeBuildInspector $ins
    $nb add $ins -text "Style inspector"

    themeReload
    themeInspect
    bind $left.tv <<TreeviewSelect>> [list apply {{tv} {
        set id [lindex [$tv selection] 0]
        if {$id eq "" || [$tv parent $id] ne ""} return
        set name [lindex [$tv item $id -values] 0]
        if {$name eq ""} return
        catch {ttk::style theme use $name}
        themeReload
        themeInspect
    }} $left.tv]
}

# ---- populate the theme/element tree -------------------------------------
proc themeReload {} {
    set tv $::themeTree
    if {![winfo exists $tv]} return
    $tv delete [$tv children {}]
    set cur [ttk::style theme use]
    foreach th [lsort [ttk::style theme names]] {
        set label [expr {$th eq $cur ? "$th  (active)" : $th}]
        set node [$tv insert {} end -text $label -values [list $th] \
            -open [expr {$th eq $cur}]]
        if {$th eq $cur} {
            set elems [lsort [ttk::style element names]]
            set en [$tv insert $node end -text "elements ([llength $elems])"]
            foreach el $elems { $tv insert $en end -text $el }
        }
    }
}

# ---- a broad gallery of ttk widgets so the theme can be eyeballed ---------
proc themeBuildPreview {f} {
    set m $f.menu
    catch {destroy $m}
    menu $m -tearoff 0
    foreach lbl {"Item one" "Item two" "Item three"} { $m add command -label $lbl }

    set g1 [ttk::labelframe $f.g1 -text "Buttons / choices" -padding 6]
    ttk::button      $g1.b   -text "Button"
    ttk::button      $g1.bd  -text "Disabled" -state disabled
    ttk::menubutton  $g1.mb  -text "Menubutton" -menu $m
    ttk::checkbutton $g1.c1  -text "Checked"   -variable ::themeChk1
    ttk::checkbutton $g1.c2  -text "Unchecked" -variable ::themeChk2
    ttk::radiobutton $g1.r1  -text "Option A"  -variable ::themeRb -value a
    ttk::radiobutton $g1.r2  -text "Option B"  -variable ::themeRb -value b
    ttk::radiobutton $g1.r3  -text "Option C"  -variable ::themeRb -value c
    set ::themeChk1 1; set ::themeChk2 0; set ::themeRb a
    grid $g1.b  $g1.bd $g1.mb -sticky w -padx 4 -pady 3
    grid $g1.c1 $g1.c2        -sticky w -padx 4 -pady 3
    grid $g1.r1 $g1.r2 $g1.r3 -sticky w -padx 4 -pady 3

    set g2 [ttk::labelframe $f.g2 -text "Inputs" -padding 6]
    ttk::label    $g2.le -text "entry:"
    ttk::entry    $g2.e
    ttk::label    $g2.lc -text "combobox:"
    ttk::combobox $g2.cb -values {Alpha Beta Gamma} -state readonly
    ttk::label    $g2.ls -text "spinbox:"
    ttk::spinbox  $g2.sp -from 0 -to 100 -width 8
    ttk::label    $g2.ld -text "disabled:"
    ttk::entry    $g2.ed -state disabled
    $g2.e insert 0 "editable text"
    $g2.cb current 0
    $g2.sp set 42
    grid $g2.le $g2.e  -sticky w -padx 4 -pady 3
    grid $g2.lc $g2.cb -sticky w -padx 4 -pady 3
    grid $g2.ls $g2.sp -sticky w -padx 4 -pady 3
    grid $g2.ld $g2.ed -sticky w -padx 4 -pady 3

    set g3 [ttk::labelframe $f.g3 -text "Range / progress" -padding 6]
    ttk::label       $g3.l1  -text "scale:"
    ttk::scale       $g3.s   -from 0 -to 100 -value 40 -length 160
    ttk::label       $g3.l2  -text "progress:"
    ttk::progressbar $g3.p   -value 65 -length 160
    ttk::separator   $g3.sep -orient horizontal
    grid $g3.l1 $g3.s -sticky w -padx 4 -pady 3
    grid $g3.l2 $g3.p -sticky w -padx 4 -pady 3
    grid $g3.sep -row 2 -column 0 -columnspan 2 -sticky ew -pady 4

    set g4 [ttk::labelframe $f.g4 -text "Containers / list" -padding 6]
    set tnb [ttk::notebook $g4.nb]
    foreach {tab txt} {one "Content of tab one" two "Content of tab two"} {
        set p [ttk::frame $tnb.$tab -padding 8]
        ttk::label $p.l -text $txt
        pack $p.l -anchor w
        $tnb add $p -text [string totitle $tab]
    }
    set tv [ttk::treeview $g4.tv -columns {size date} -height 4]
    $tv heading #0   -text "Name"
    $tv heading size -text "Size"
    $tv heading date -text "Date"
    $tv column size -width 70 -anchor e
    $tv column date -width 90 -anchor center
    foreach row {{report.pdf 248K 2026-01-04} {data.csv 12K 2026-02-11} \
                 {notes.txt 3K 2026-03-02}} {
        lassign $row n s d
        $tv insert {} end -text $n -values [list $s $d]
    }
    grid $tnb -row 0 -column 0 -sticky nsew -padx 4 -pady 3
    grid $tv  -row 1 -column 0 -sticky nsew -padx 4 -pady 3

    grid $g1 -row 0 -column 0 -sticky nsew -padx 6 -pady 6
    grid $g2 -row 0 -column 1 -sticky nsew -padx 6 -pady 6
    grid $g3 -row 1 -column 0 -sticky nsew -padx 6 -pady 6
    grid $g4 -row 1 -column 1 -sticky nsew -padx 6 -pady 6
    grid columnconfigure $f 0 -weight 1
    grid columnconfigure $f 1 -weight 1
    grid rowconfigure    $f 0 -weight 1
    grid rowconfigure    $f 1 -weight 1
}

# ---- style inspector: configure + map (table) and layout (tree) ----------
proc themeBuildInspector {f} {
    set bar [ttk::frame $f.bar]
    ttk::label $bar.l -text "Style:"
    ttk::combobox $bar.cb -textvariable ::themeStyleName -width 26 -values {
        TButton TMenubutton TCheckbutton TRadiobutton
        TEntry TCombobox TSpinbox TScale TProgressbar
        TNotebook TNotebook.Tab Treeview Treeview.Item Heading
        TLabel TLabelframe TLabelframe.Label TSeparator TSizegrip
        TScrollbar Vertical.TScrollbar Horizontal.TScrollbar TFrame
    }
    ttk::button $bar.go -text "Inspect" -command themeInspect
    pack $bar.l $bar.cb $bar.go -side left -padx 3
    pack $bar -fill x -pady {0 4}
    set ::themeStyleName TButton
    bind $bar.cb <<ComboboxSelected>> themeInspect
    bind $bar.cb <Return>             themeInspect

    set lf1 [ttk::labelframe $f.cfg \
        -text "configure (declared) + map (state-specific)" -padding 4]
    set t [scrolledTable $lf1 \
        {12 Kind left 22 Option left 24 State left 28 Value left} -height 12]
    set ::themeCfgTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    catch {::tkutils::tkutlsort::columns $t {0 string 1 string 2 string 3 string}}
    pack $lf1 -fill both -expand 1 -pady {0 4}

    set lf2 [ttk::labelframe $f.lay -text "layout (element tree)" -padding 4]
    set txt [text $lf2.t -height 9 -wrap none -font TkFixedFont \
        -yscrollcommand [list $lf2.sb set]]
    ttk::scrollbar $lf2.sb -orient vertical -command [list $txt yview]
    grid $txt    -row 0 -column 0 -sticky nsew
    grid $lf2.sb -row 0 -column 1 -sticky ns
    grid rowconfigure    $lf2 0 -weight 1
    grid columnconfigure $lf2 0 -weight 1
    pack $lf2 -fill both -expand 1
    set ::themeLayoutText $txt
}

# ---- fill the inspector for the currently selected style ------------------
proc themeInspect {} {
    if {![info exists ::themeCfgTable] || ![winfo exists $::themeCfgTable]} return
    set style $::themeStyleName
    set t $::themeCfgTable
    if {[$t size] > 0} { $t delete 0 end }

    if {[catch {ttk::style configure $style} cfg]} { set cfg {} }
    foreach {opt val} $cfg {
        $t insert end [list configure $opt "" $val]
    }
    if {[catch {ttk::style map $style} mp]} { set mp {} }
    foreach {opt statemap} $mp {
        foreach {state val} $statemap {
            $t insert end [list map $opt $state $val]
        }
    }
    if {[$t size] == 0} {
        $t insert end [list "" "(no declared options for $style)" "" ""]
    }

    set txt $::themeLayoutText
    $txt configure -state normal
    $txt delete 1.0 end
    if {[catch {ttk::style layout $style} lay] || $lay eq ""} {
        $txt insert end "(no layout defined for style \"$style\")"
    } else {
        $txt insert end [themeFmtLayout $lay 0]
    }
    $txt configure -state disabled
}

# ---- pretty-print a ttk layout spec (a sequence of element + options) -----
proc themeFmtLayout {spec indent} {
    set pad [string repeat "    " $indent]
    set out ""
    set i 0
    set n [llength $spec]
    while {$i < $n} {
        set el [lindex $spec $i]; incr i
        set opts {}
        set children {}
        while {$i < $n && [string match -* [lindex $spec $i]]} {
            set k [lindex $spec $i]
            set v [lindex $spec [expr {$i + 1}]]
            incr i 2
            if {$k eq "-children"} { set children $v } else { lappend opts "$k $v" }
        }
        append out $pad $el
        if {[llength $opts]} { append out "  ([join $opts {, }])" }
        append out "\n"
        if {[llength $children]} {
            append out [themeFmtLayout $children [expr {$indent + 1}]]
        }
    }
    return $out
}

# ============================ clock format codes ===========================
proc buildClock {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Format:"
    entry $bar.e -textvariable ::clockFmt -width 40
    pack $bar.l $bar.e -side left -padx 3
    pack $bar -fill x -pady 4
    set ::clockFmt "%Y-%m-%d %H:%M:%S"
    label $f.out -textvariable ::clockOut -anchor w -fg #225 -font {Helvetica 14}
    pack $f.out -anchor w -padx 8 -pady 4
    bind $bar.e <KeyRelease> clockUpdate
    set t [scrolledTable $f {7 Code left 34 Meaning left 18 Example right} -height 16]
    set now [clock seconds]
    foreach {code meaning} {
        %Y "year, 4 digits"        %y "year, 2 digits"
        %m "month 01-12"           %B "month name"        %b "month abbrev"
        %d "day of month 01-31"    %e "day, space padded" %j "day of year 001-366"
        %H "hour 00-23"            %I "hour 01-12"        %p "AM/PM"
        %M "minute 00-59"          %S "second 00-59"
        %A "weekday name"          %a "weekday abbrev"    %u "weekday 1-7 (Mon=1)"
        %w "weekday 0-6 (Sun=0)"   %U "week of year (Sun)" %W "week of year (Mon)"
        %Z "time zone name"        %z "time zone offset"  %s "epoch seconds"
        %D "%m/%d/%y"              %T "%H:%M:%S"
        %% "literal percent"
    } {
        catch {clock format $now -format $code} ex
        $t insert end [list $code $meaning $ex]
    }
    clockTick
}
proc clockUpdate {} {
    if {[catch {clock format [clock seconds] -format $::clockFmt} r]} {
        set ::clockOut "(error: $r)"
    } else { set ::clockOut $r }
}
proc clockTick {} {
    catch {after cancel $::clockTickId}
    clockUpdate
    set ::clockTickId [after 1000 clockTick]
}

# ============================ regexp tester ================================
proc buildRegexp {f} {
    set top [frame $f.top]
    label $top.pl -text "Pattern:"
    entry $top.pe -textvariable ::rePat -width 40
    checkbutton $top.ci -text "-nocase" -variable ::reNocase -command regexpRun
    checkbutton $top.li -text "-line"   -variable ::reLine   -command regexpRun
    checkbutton $top.al -text "-all"    -variable ::reAll    -command regexpRun
    grid $top.pl $top.pe $top.ci $top.li $top.al -sticky w -padx 3 -pady 2
    pack $top -fill x -pady 3
    label $f.sl -text "Subject:" -anchor w
    pack $f.sl -anchor w -padx 6
    text $f.sub -height 4 -wrap word
    pack $f.sub -fill x -padx 6 -pady {0 4}
    set ::reSubject $f.sub
    label $f.ml -textvariable ::reStatus -anchor w -fg #225
    pack $f.ml -anchor w -padx 6
    frame $f.rs
    label $f.rs.l -text "regsub ->"
    entry $f.rs.rep -textvariable ::reRep -width 22
    label $f.rs.out -textvariable ::reSubOut -anchor w -fg #225
    pack $f.rs.l $f.rs.rep $f.rs.out -side left -padx 3
    pack $f.rs -fill x -padx 6 -pady 4
    set t [scrolledTable $f {8 "Group" right 50 "Match" left} -height 8]
    set ::reTable $t
    set ::rePat {(\w+)@(\w+)}
    $f.sub insert end "contact a@b and c@d"
    set ::reRep {\2.\1}
    foreach ev {<KeyRelease>} { bind $top.pe $ev regexpRun; bind $f.rs.rep $ev regexpRun }
    bind $f.sub <KeyRelease> regexpRun
    regexpRun
}
proc regexpRun {args} {
    set t $::reTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set subj [string trimright [$::reSubject get 1.0 end]]
    set flags {}
    if {$::reNocase} { lappend flags -nocase }
    if {$::reLine}   { lappend flags -line }
    if {$::reAll}    { lappend flags -all }
    if {[catch {regexp {*}$flags -inline -- $::rePat $subj} m]} {
        set ::reStatus "regexp error: $m"; return
    }
    if {[llength $m] == 0} {
        set ::reStatus "no match"
    } else {
        set ::reStatus "[llength $m] item(s)"
        set i 0
        foreach g $m { $t insert end [list $i $g]; incr i }
    }
    set rflags {}
    if {$::reNocase} { lappend rflags -nocase }
    if {$::reLine}   { lappend rflags -line }
    if {$::reAll}    { lappend rflags -all }
    if {[catch {regsub {*}$rflags -- $::rePat $subj $::reRep} out]} {
        set ::reSubOut "(error)"
    } else { set ::reSubOut $out }
}

# ============================ encodings ====================================
proc buildEncodings {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Sample bytes for the selected encoding (hex):"
    pack $bar.l -side left -padx 4
    pack $bar -fill x -pady 3
    set ::encSample [join [lmap c {72 105 32 196 214 220 228 246 252 223 8364} \
        {format %c $c}] ""]
    label $f.s -text "sample text: Hi + accented + euro" -anchor w -fg #555
    pack $f.s -anchor w -padx 6
    label $f.out -textvariable ::encOut -anchor w -fg #225 -wraplength 760 -justify left
    pack $f.out -anchor w -padx 6 -pady 4
    set t [scrolledTable $f {28 Encoding left} -height 16]
    foreach e [lsort [encoding names]] { $t insert end [list $e] }
    set ::encTable $t
    bind $t <<TablelistSelect>> encPick
}
proc encPick {} {
    set t $::encTable
    set sel [$t curselection]
    if {[llength $sel] == 0} return
    set enc [lindex [$t get [lindex $sel 0]] 0]
    if {[catch {encoding convertto $enc $::encSample} bytes]} {
        set ::encOut "$enc: (cannot encode sample)"; return
    }
    binary scan $bytes H* hex
    regsub -all {..} $hex {& } hex
    set ::encOut "$enc:  $hex"
}

# ============================ virtual events ===============================
proc buildVirtualEvents {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Defined virtual events and their physical bindings (event info):"
    pack $bar.l -side left -padx 4
    pack $bar -fill x -pady 3
    set t [scrolledTable $f {26 "Virtual event" left 40 "Physical sequence(s)" left} -height 18]
    foreach ve [lsort [event info]] {
        $t insert end [list $ve [event info $ve]]
    }
    catch {::tkutils::tkutlclip::installBindings $t}
}

# ============================ bitmaps ======================================
proc buildBitmaps {f} {
    label $f.l -text "Built-in Tk bitmaps (-bitmap option):" -anchor w
    pack $f.l -anchor w -padx 6 -pady 4
    set g [frame $f.g]
    set col 0; set row 0
    foreach bm {error gray75 gray50 gray25 gray12 hourglass info questhead question warning} {
        set cell [frame $g.c$bm -relief groove -bd 1]
        if {[catch {label $cell.b -bitmap $bm}]} {
            label $cell.b -text "(n/a)"
        }
        label $cell.t -text $bm
        pack $cell.b $cell.t -pady 2 -padx 6
        grid $cell -row $row -column $col -padx 8 -pady 8
        incr col
        if {$col >= 5} { set col 0; incr row }
    }
    pack $g -anchor nw -padx 6 -pady 4
}

# ====================== widget explorer (configure / winfo) ================
set ::weTypes {
    button label entry frame labelframe listbox text canvas message
    scale scrollbar checkbutton radiobutton menubutton spinbox
    ttk::button ttk::label ttk::entry ttk::frame ttk::labelframe
    ttk::checkbutton ttk::radiobutton ttk::combobox ttk::progressbar
    ttk::scale ttk::separator ttk::treeview ttk::notebook ttk::spinbox
}
proc buildWidgetExplorer {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Widget:"
    ttk::combobox $bar.cb -textvariable ::weType -state readonly -width 18 \
        -values $::weTypes
    label $bar.n -textvariable ::weInfo -fg #336
    pack $bar.l $bar.cb $bar.n -side left -padx 3
    pack $bar -fill x -pady 3
    set ::weHidden [frame $f.hidden]   ;# sample widget lives here, never mapped
    set t [scrolledTable $f {26 Option left 26 Default left 26 Current left} -height 18]
    set ::weTable $t
    bind $bar.cb <<ComboboxSelected>> widgetExplore
    set ::weType button
    widgetExplore
}
proc widgetExplore {} {
    set t $::weTable
    $t delete 0 end
    set s $::weHidden.s
    catch {destroy $s}
    if {[catch {$::weType $s} err]} { set ::weInfo "cannot create: $err"; return }
    foreach spec [lsort -index 0 [$s configure]] {
        if {[llength $spec] == 5} {
            lassign $spec opt db cls def cur
            $t insert end [list $opt $def $cur]
        }
    }
    set ::weInfo "class [winfo class $s]   reqw [winfo reqwidth $s]   reqh [winfo reqheight $s]   ([$t size] options)"
}

# ====================== pack playground ====================================
proc buildPack {f} {
    set bar [frame $f.bar]
    label $bar.s -text "-side:"
    ttk::combobox $bar.side -textvariable ::packSide -state readonly -width 7 \
        -values {top bottom left right}
    label $bar.fl -text "-fill:"
    ttk::combobox $bar.fill -textvariable ::packFill -state readonly -width 6 \
        -values {none x y both}
    checkbutton $bar.exp -text "-expand" -variable ::packExpand
    button $bar.add   -text "Add box" -command packAddBox
    button $bar.reset -text "Reset"   -command packReset
    pack $bar.s $bar.side $bar.fl $bar.fill $bar.exp $bar.add $bar.reset \
        -side left -padx 3
    pack $bar -fill x -pady 3
    label $f.cmd -textvariable ::packCmd -anchor w -fg #225 -font {Courier 10}
    pack $f.cmd -fill x -padx 6 -pady 2
    set ::packDemo [frame $f.demo -relief sunken -bd 2 -bg #eeeeee]
    pack $::packDemo -fill both -expand 1 -padx 6 -pady 6
    set ::packSide top; set ::packFill none; set ::packExpand 0; set ::packN 0
}
proc packAddBox {} {
    set d $::packDemo
    incr ::packN
    set colors {#ee8888 #88ee88 #8888ee #eeee88 #ee88ee #88eeee #eebb88 #88bbee}
    set c [lindex $colors [expr {($::packN-1)%[llength $colors]}]]
    set w $d.box$::packN
    label $w -text "box $::packN" -bg $c -relief raised -bd 2 -width 8 -height 2
    pack $w -side $::packSide -fill $::packFill -expand $::packExpand
    set ::packCmd "pack $w -side $::packSide -fill $::packFill -expand $::packExpand"
}
proc packReset {} {
    foreach c [winfo children $::packDemo] { destroy $c }
    set ::packN 0; set ::packCmd ""
}

# --- grid: interactive grid(7) sandbox (sibling of the pack tab) ----------
proc buildGrid {f} {
    set bar [frame $f.bar]
    label $bar.r -text "-row:"
    ttk::combobox $bar.row -textvariable ::gridRow -state readonly -width 3 \
        -values {0 1 2 3 4}
    label $bar.c -text "-column:"
    ttk::combobox $bar.col -textvariable ::gridCol -state readonly -width 3 \
        -values {0 1 2 3 4}
    label $bar.st -text "-sticky:"
    ttk::combobox $bar.sticky -textvariable ::gridSticky -state readonly -width 5 \
        -values {{} n s e w ns ew ne nw se sw nsew}
    label $bar.rs -text "-rowspan:"
    ttk::combobox $bar.rspan -textvariable ::gridRspan -state readonly -width 3 \
        -values {1 2 3}
    label $bar.cs -text "-columnspan:"
    ttk::combobox $bar.cspan -textvariable ::gridCspan -state readonly -width 3 \
        -values {1 2 3}
    button $bar.add   -text "Add cell" -command gridAddCell
    button $bar.reset -text "Reset"    -command gridReset
    pack $bar.r $bar.row $bar.c $bar.col $bar.st $bar.sticky \
         $bar.rs $bar.rspan $bar.cs $bar.cspan $bar.add $bar.reset \
        -side left -padx 3
    pack $bar -fill x -pady 3
    label $f.cmd -textvariable ::gridCmd -anchor w -fg #225 -font {Courier 10}
    pack $f.cmd -fill x -padx 6 -pady 2
    set ::gridDemo [frame $f.demo -relief sunken -bd 2 -bg #eeeeee]
    pack $::gridDemo -fill both -expand 1 -padx 6 -pady 6
    # give every cell room so that -sticky has a visible effect
    for {set i 0} {$i < 5} {incr i} {
        grid rowconfigure    $::gridDemo $i -weight 1 -minsize 40
        grid columnconfigure $::gridDemo $i -weight 1 -minsize 60
    }
    set ::gridRow 0; set ::gridCol 0; set ::gridSticky {}
    set ::gridRspan 1; set ::gridCspan 1; set ::gridN 0; set ::gridCmd ""
}

proc gridAddCell {} {
    set d $::gridDemo
    incr ::gridN
    set colors {#ee8888 #88ee88 #8888ee #eeee88 #ee88ee #88eeee #eebb88 #88bbee}
    set c [lindex $colors [expr {($::gridN-1)%[llength $colors]}]]
    set w $d.cell$::gridN
    label $w -text "cell $::gridN" -bg $c -relief raised -bd 2
    set opt [list -row $::gridRow -column $::gridCol \
        -rowspan $::gridRspan -columnspan $::gridCspan]
    if {$::gridSticky ne ""} { lappend opt -sticky $::gridSticky }
    grid $w {*}$opt
    set ::gridCmd "grid $w $opt"
}

proc gridReset {} {
    foreach c [winfo children $::gridDemo] { destroy $c }
    set ::gridN 0; set ::gridCmd ""
}

# --- format / scan: interactive tester plus a conversion cheat sheet -------
proc buildFormatScan {f} {
    # format tester
    set ft [labelframe $f.ft -text " format "]
    label $ft.sl -text "Spec:"
    entry $ft.spec -textvariable ::fmtSpec -width 28
    label $ft.al -text "Args:"
    entry $ft.args -textvariable ::fmtArgs -width 24
    label $ft.ar -text "(space-separated list)" -fg #777
    grid $ft.sl $ft.spec $ft.al $ft.args $ft.ar -sticky w -padx 3 -pady 2
    label $ft.out -textvariable ::fmtOut -anchor w -fg #225 -font {Courier 10}
    grid $ft.out -columnspan 5 -sticky we -padx 3 -pady {0 3}
    pack $ft -fill x -padx 6 -pady 4

    # scan tester
    set st [labelframe $f.st -text " scan (inline) "]
    label $st.il -text "Input:"
    entry $st.input -textvariable ::scnInput -width 24
    label $st.sl -text "Spec:"
    entry $st.spec -textvariable ::scnSpec -width 24
    grid $st.il $st.input $st.sl $st.spec -sticky w -padx 3 -pady 2
    label $st.out -textvariable ::scnOut -anchor w -fg #225 -font {Courier 10}
    grid $st.out -columnspan 4 -sticky we -padx 3 -pady {0 3}
    pack $st -fill x -padx 6 -pady 4

    # conversion cheat sheet
    set t [scrolledTable $f {10 "Code" left 64 "Meaning / example" left} -height 12]
    foreach row {
        {%d "signed integer:  format %d 42 -> 42"}
        {%i "integer, base from prefix (0x, 0):  scan only"}
        {%u "unsigned integer"}
        {%o "octal:  format %o 8 -> 10"}
        {%x "hex lower:  format %x 255 -> ff"}
        {%X "hex upper:  format %X 255 -> FF"}
        {%b "binary:  format %b 5 -> 101"}
        {%c "character from code point:  format %c 65 -> A"}
        {%s "string:  format %-8s hi -> 'hi      '"}
        {%f "fixed float:  format %.2f 3.14159 -> 3.14"}
        {%e "scientific:  format %e 1234.0 -> 1.234000e+03"}
        {%g "shortest of %e/%f"}
        {%% "literal percent sign"}
        {flags "width .prec - (left) + (sign) 0 (zero-pad) # (alt)"}
        {pos "argument index:  format {%2\$s %1\$s} a b -> 'b a'"}
        {scan "%n chars consumed, %\[set\] char class, * to skip"}
    } {
        $t insert end $row
    }
    set ::fmtSpec {%-6s = %05.2f}
    set ::fmtArgs {pi 3.14159}
    set ::scnInput {2026-06-16}
    set ::scnSpec {%d-%d-%d}
    foreach e [list $ft.spec $ft.args $st.input $st.spec] {
        bind $e <KeyRelease> formatScanRun
    }
    formatScanRun
}

proc formatScanRun {} {
    if {[catch {format $::fmtSpec {*}$::fmtArgs} r]} {
        set ::fmtOut "-> error: $r"
    } else {
        set ::fmtOut "-> \[$r\]"
    }
    if {[catch {scan $::scnInput $::scnSpec} r]} {
        set ::scnOut "-> error: $r"
    } else {
        set ::scnOut "-> values: {$r}  ([llength $r] item(s))"
    }
}

# ============================ Graphemes ====================================
# A grapheme cluster is what a user perceives as one character; it may span
# several code points (combining marks, emoji skin-tone / ZWJ sequences, flags).
# Tcl works on code points, so [string length] counts code points, not clusters.
# Segmentation: tclutils::tustr::graphemes (simplified UAX #29).
proc buildGraphemes {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Text:"
    ttk::entry $bar.e -textvariable ::graphInput -width 44
    label $bar.n -textvariable ::graphStatus
    pack $bar.l $bar.e -side left -padx 3
    pack $bar.n -side left -padx 8
    pack $bar -fill x -pady 3
    set t [scrolledTable $f \
        {4 "#" right 8 Cluster center 5 "cps" right 46 "Code points" left} -height 16]
    $t columnconfigure 1 -font {Helvetica 20}
    set ::graphTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    bind $bar.e <KeyRelease> graphFill
    # sample: café (combining accent), waving hand + skin tone, DE flag, family ZWJ
    set ::graphInput "cafe\u0301 \U0001F44B\U0001F3FD \U0001F1E9\U0001F1EA \U0001F468\u200D\U0001F469\u200D\U0001F467"
    graphFill
}
proc graphFill {} {
    set t $::graphTable
    $t delete 0 end
    set clusters [::tclutils::tustr::graphemes $::graphInput]
    set i 1
    foreach cl $clusters {
        set cps {}
        foreach ch [split $cl ""] { lappend cps [format {U+%04X} [scan $ch %c]] }
        $t insert end [list $i $cl [string length $cl] [join $cps " "]]
        incr i
    }
    set ::graphStatus "[llength $clusters] clusters  /  [string length $::graphInput] code points\
                       (string length)  --  simplified UAX #29"
}

# ============================ Runtime: Tcl / Tk ============================
proc runtimeAddRow {t key value} {
    $t insert end [list $key $value]
}
# Full runtime report (Tcl/Tk, environment, packages, tm paths, loaded
# modules) from tclutils::tuappinfo onto the clipboard -- for bug reports.
proc copyReport {} {
    set r [::tclutils::tuappinfo::buildReport -title "tkdevtools"]
    clipboard clear
    clipboard append $r
    set ::tcltkStatus "report copied ([llength [split $r \n]] lines)"
}
proc buildTclTk {f} {
    set bar [frame $f.bar]
    ttk::button $bar.refresh -text "Refresh" -command tclTkFill
    ttk::button $bar.report -text "Copy report" -command copyReport
    label $bar.n -textvariable ::tcltkStatus -fg #555
    pack $bar.refresh $bar.report $bar.n -side left -padx 4
    pack $bar -fill x -pady 3
    set t [scrolledTable $f {22 Key left 72 Value left} -height 22]
    set ::tcltkTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    tclTkFill
}
proc tclTkFill {} {
    set t $::tcltkTable
    if {![winfo exists $t]} return
    $t delete 0 end
    runtimeAddRow $t "Tcl patchlevel"    [info patchlevel]
    runtimeAddRow $t "tcl_version"       $::tcl_version
    runtimeAddRow $t "Tk patchLevel"     $::tk_patchLevel
    runtimeAddRow $t "tk_version"        $::tk_version
    runtimeAddRow $t "windowingsystem"   [tk windowingsystem]
    runtimeAddRow $t "nameofexecutable"  [info nameofexecutable]
    runtimeAddRow $t "info library"      [info library]
    runtimeAddRow $t "tcl_library"       $::tcl_library
    runtimeAddRow $t "tk_library"        $::tk_library
    runtimeAddRow $t "encoding system"   [encoding system]
    runtimeAddRow $t "sharedlibextension" [info sharedlibextension]
    runtimeAddRow $t "tcl_platform(os)"  $::tcl_platform(os)
    runtimeAddRow $t "tcl_platform(osVersion)" $::tcl_platform(osVersion)
    runtimeAddRow $t "tcl_platform(machine)"   $::tcl_platform(machine)
    runtimeAddRow $t "tcl_platform(platform)"  $::tcl_platform(platform)
    runtimeAddRow $t "tcl_platform(byteOrder)" $::tcl_platform(byteOrder)
    runtimeAddRow $t "tcl_platform(wordSize)"  $::tcl_platform(wordSize)
    if {[info exists ::tcl_platform(pointerSize)]} {
        runtimeAddRow $t "tcl_platform(pointerSize)" $::tcl_platform(pointerSize)
    }
    if {[info exists ::tcl_platform(threaded)]} {
        runtimeAddRow $t "tcl_platform(threaded)" $::tcl_platform(threaded)
    }
    runtimeAddRow $t "tcl_interactive"   $::tcl_interactive
    if {[info exists ::tcl_precision]} {    ;# not set by default in Tcl 9
        runtimeAddRow $t "tcl_precision" $::tcl_precision
    }
    runtimeAddRow $t "argv0"             $::argv0
    runtimeAddRow $t "argc / argv"       [list $::argc $::argv]
    if {![catch {set z [zipfs mount]}]} {
        runtimeAddRow $t "zipfs mount" $z
    }
    if {![catch {package require Thread}]} {
        runtimeAddRow $t "Thread package" [package present Thread]
    }
    set themes [ttk::style theme names]
    runtimeAddRow $t "ttk themes"        [join [lsort $themes] {, }]
    runtimeAddRow $t "ttk theme use"     [ttk::style theme use]
    set ::tcltkStatus "[$t size] fields  \u00b7  [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
}

# ============================ Runtime: OS / platform =======================
proc buildOs {f} {
    set bar [frame $f.bar]
    ttk::button $bar.refresh -text "Refresh" -command osFill
    label $bar.n -textvariable ::osStatus -fg #555
    pack $bar.refresh $bar.n -side left -padx 4
    pack $bar -fill x -pady 3
    set t [scrolledTable $f {22 Key left 72 Value left} -height 22]
    set ::osTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    osFill
}
proc osFill {} {
    set t $::osTable
    if {![winfo exists $t]} return
    $t delete 0 end
    foreach {k cmd} {
        hostname {info hostname}
        uname    {exec uname -a}
        whoami   {exec whoami}
        pwd      {pwd}
        home     {file normalize ~}
    } {
        if {[catch {set v [{*}$cmd]} err]} { set v "(n/a: $err)" }
        runtimeAddRow $t $k $v
    }
    if {[info exists ::env(TMPDIR)] && $::env(TMPDIR) ne ""} {
        runtimeAddRow $t TMPDIR $::env(TMPDIR)
    } elseif {[info exists ::env(TEMP)] && $::env(TEMP) ne ""} {
        runtimeAddRow $t TEMP $::env(TEMP)
    } elseif {[info exists ::env(TMP)] && $::env(TMP) ne ""} {
        runtimeAddRow $t TMP $::env(TMP)
    }
    foreach k {
        USER USERNAME HOME LANG LC_ALL LANGUAGE DISPLAY WAYLAND_DISPLAY
        XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DESKTOP_SESSION
        SHELL TERM PATH
    } {
        if {[info exists ::env($k)] && $::env($k) ne ""} {
            runtimeAddRow $t "env($k)" $::env($k)
        }
    }
    if {$::tcl_platform(platform) eq "windows"} {
        foreach k {OS PROCESSOR_ARCHITECTURE NUMBER_OF_PROCESSORS COMPUTERNAME SYSTEMROOT} {
            if {[info exists ::env($k)]} { runtimeAddRow $t "env($k)" $::env($k) }
        }
    } else {
        foreach cmd {{nproc} {free -h} {df -h /}} {
            set label [lindex $cmd 0]
            if {[catch {set v [exec {*}$cmd]} err]} {
                # optional tools — skip quietly
            } else {
                runtimeAddRow $t $label [string map {"\n" " | "} [string trim $v]]
            }
        }
    }
    set ::osStatus "[$t size] fields"
}

# ============================ Runtime: packages ============================
proc buildPackages {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Filter:"
    entry $bar.e -textvariable ::pkgFilter -width 18
    checkbutton $bar.loaded -text "loaded only" -variable ::pkgLoadedOnly \
        -command pkgFill
    ttk::button $bar.refresh -text "Refresh" -command pkgFill
    label $bar.n -textvariable ::pkgStatus -fg #555
    pack $bar.l $bar.e $bar.loaded $bar.refresh $bar.n -side left -padx 3
    pack $bar -fill x -pady 3
    set t [scrolledTable $f \
        {28 Package left 10 Loaded left 14 Versions left 48 "ifneeded (source)" left} \
        -height 20]
    set ::pkgTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    catch {::tkutils::tkutlsort::columns $t {0 string 1 string 2 string 3 string}}
    if {[llength [info commands ::tkutils::tkutlfind::find]]} {
        bind $bar.e <KeyRelease> [list apply {{t} {
            set ::pkgStatus "[::tkutils::tkutlfind::find $t $::pkgFilter -columns {0 1 2 3}] match(es)"
        }} $t]
    } else {
        bind $bar.e <KeyRelease> pkgFill
    }
    set ::pkgFilter ""
    set ::pkgLoadedOnly 0
    pkgFill
}
proc pkgFill {} {
    set t $::pkgTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set n 0
    foreach p [lsort -dictionary [package names]] {
        if {$::pkgFilter ne "" && ![string match -nocase *$::pkgFilter* $p]} continue
        set loaded ""
        if {![catch {package present $p} v]} { set loaded $v }
        if {$::pkgLoadedOnly && $loaded eq ""} continue
        set vers [join [lsort -dictionary [package versions $p]] {, }]
        set src ""
        set v $loaded
        if {$v eq "" && [llength [package versions $p]]} {
            set v [lindex [lsort -dictionary [package versions $p]] end]
        }
        if {$v ne "" && ![catch {::tclutils::tupkgfinder::pkgInfo $p} info]
                && [dict exists $info locations $v]} {
            set src [lindex [dict get $info locations $v] 0]
        }
        if {$src eq "" && $v ne ""} {   ;# no file found (built-in, odd script)
            catch {set src [lindex [package ifneeded $p $v] end]}
        }
        if {[string length $src] > 80} { set src "[string range $src 0 77]..." }
        $t insert end [list $p $loaded $vers $src]
        incr n
    }
    set ::pkgStatus "$n package(s)  \u00b7  [llength [package names]] known"
}

# ============================ Runtime: paths ===============================
proc buildPaths {f} {
    set bar [frame $f.bar]
    ttk::button $bar.refresh -text "Refresh" -command pathsFill
    label $bar.n -textvariable ::pathsStatus -fg #555
    pack $bar.refresh $bar.n -side left -padx 4
    pack $bar -fill x -pady 3
    set t [scrolledTable $f {14 Kind left 80 Path left} -height 22]
    set ::pathsTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    pathsFill
}
proc pathsFill {} {
    set t $::pathsTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set sp [::tclutils::tupkgfinder::paths]
    foreach key {auto_path tm_path} label {auto_path tm} {
        if {![dict exists $sp $key]} continue
        dict for {pos p} [dict get $sp $key] { $t insert end [list $label $p] }
    }
    if {[info exists ::tcl_pkgPath]} {
        foreach p $::tcl_pkgPath { $t insert end [list tcl_pkgPath $p] }
    }
    foreach p [encoding dirs] {
        $t insert end [list encoding $p]
    }
    $t insert end [list script [file normalize [info script]]]
    $t insert end [list pwd [pwd]]
    set ::pathsStatus "[$t size] entries"
}

# ============================ Runtime: display =============================
proc buildDisplay {f} {
    set bar [frame $f.bar]
    ttk::button $bar.refresh -text "Refresh" -command displayFill
    label $bar.n -textvariable ::dispStatus -fg #555
    pack $bar.refresh $bar.n -side left -padx 4
    pack $bar -fill x -pady 3
    set t [scrolledTable $f {28 Key left 56 Value left} -height 20]
    set ::dispTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    displayFill
}
proc displayFill {} {
    set t $::dispTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set w .
    runtimeAddRow $t "screenwidth \u00d7 height" \
        "[winfo screenwidth $w] \u00d7 [winfo screenheight $w] px"
    runtimeAddRow $t "screen mm" \
        "[winfo screenmmwidth $w] \u00d7 [winfo screenmmheight $w] mm"
    runtimeAddRow $t "screendepth"      [winfo screendepth $w]
    runtimeAddRow $t "screenvisual"     [winfo screenvisual $w]
    runtimeAddRow $t "screen cells"     [winfo cells $w]
    runtimeAddRow $t "server"           [winfo server $w]
    runtimeAddRow $t "vroot" \
        "[winfo vrootwidth $w] \u00d7 [winfo vrootheight $w] @ [winfo vrootx $w],[winfo vrooty $w]"
    runtimeAddRow $t "fpixels 1i"       [format %.2f [winfo fpixels $w 1i]]
    runtimeAddRow $t "fpixels 1m"       [format %.4f [winfo fpixels $w 1m]]
    runtimeAddRow $t "tk scaling"       [tk scaling]
    lassign [winfo pointerxy $w] px py
    runtimeAddRow $t "pointerxy"        "$px , $py"
    runtimeAddRow $t "rgb of white"     [winfo rgb $w white]
    set imgPkgs {}
    foreach p {Img img::png img::jpeg img::gif img::bmp img::tiff img::window} {
        if {![catch {package present $p} v]} {
            lappend imgPkgs "$p $v"
        } elseif {[llength [package versions $p]]} {
            lappend imgPkgs "$p ([join [package versions $p] {, }])"
        }
    }
    if {[llength $imgPkgs]} {
        runtimeAddRow $t "image packages" [join $imgPkgs {; }]
    }
    set ::dispStatus "[$t size] fields"
}

# ============================ Runtime: environment =========================
proc buildEnv {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Filter:"
    entry $bar.e -textvariable ::envFilter -width 20
    ttk::button $bar.refresh -text "Refresh" -command envFill
    label $bar.n -textvariable ::envStatus -fg #555
    pack $bar.l $bar.e $bar.refresh $bar.n -side left -padx 3
    pack $bar -fill x -pady 3
    set t [scrolledTable $f {28 Variable left 72 Value left} -height 22]
    set ::envTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    catch {::tkutils::tkutlsort::columns $t {0 string 1 string}}
    bind $bar.e <KeyRelease> envFill
    set ::envFilter ""
    envFill
}
proc envFill {} {
    set t $::envTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set n 0
    foreach name [lsort -dictionary [array names ::env]] {
        if {$::envFilter ne "" && ![string match -nocase *$::envFilter* $name]
                && ![string match -nocase *$::envFilter* $::env($name)]} {
            continue
        }
        set val $::env($name)
        if {[string length $val] > 200} {
            set val "[string range $val 0 197]..."
        }
        $t insert end [list $name $val]
        incr n
    }
    set ::envStatus "$n of [array size ::env] variable(s)"
}

# ====================== Widgets: hierarchy + bindtags ======================
proc buildWidgets {f} {
    set bar [frame $f.bar]
    ttk::button $bar.refresh -text "Refresh tree" -command widgetsFill
    label $bar.n -textvariable ::widgetsStatus -fg #555
    pack $bar.refresh $bar.n -side left -padx 4
    pack $bar -fill x -pady 3

    ttk::panedwindow $f.pw -orient horizontal
    pack $f.pw -fill both -expand 1 -padx 4 -pady 4

    set left [ttk::frame $f.pw.left]
    ttk::treeview $left.tv -show tree -height 22 \
        -yscrollcommand [list $left.sb set]
    ttk::scrollbar $left.sb -orient vertical -command [list $left.tv yview]
    pack $left.sb -side right -fill y
    pack $left.tv -side left -fill both -expand 1
    $f.pw add $left -weight 1
    set ::widgetsTree $left.tv

    set right [ttk::frame $f.pw.right]
    set info [ttk::labelframe $right.info -text "winfo" -padding 4]
    set ti [scrolledTable $info {18 Key left 48 Value left} -height 8]
    set ::widgetsInfo $ti
    pack $info -fill x -pady {0 4}

    set bt [ttk::labelframe $right.bt -text "bindtags (order)" -padding 4]
    set tb [scrolledTable $bt {8 "#" right 36 Tag left} -height 5]
    set ::widgetsTags $tb
    pack $bt -fill x -pady {0 4}

    set bn [ttk::labelframe $right.bn -text "bindings on selected tag / widget" -padding 4]
    set tn [scrolledTable $bn {22 Sequence left 50 Script left} -height 8]
    set ::widgetsBinds $tn
    catch {::tkutils::tkutlclip::installBindings $tn}
    pack $bn -fill both -expand 1
    $f.pw add $right -weight 2

    bind $left.tv <<TreeviewSelect>> widgetsSelect
    bind $tb <<TablelistSelect>> widgetsTagSelect
    widgetsFill
}
proc widgetsFill {} {
    set tv $::widgetsTree
    if {![winfo exists $tv]} return
    $tv delete [$tv children {}]
    set n [widgetsInsert $tv {} .]
    set ::widgetsStatus "$n widget(s) under ."
    catch {$tv selection set [$tv children {}]; widgetsSelect}
}
proc widgetsInsert {tv parent w} {
    if {![winfo exists $w]} { return 0 }
    set class [winfo class $w]
    set label [expr {$w eq "." ? ".  ($class)" : "$w  ($class)"}]
    set id [$tv insert $parent end -text $label -tags [list W $w] \
        -open [expr {$w eq "."}]]
    set n 1
    foreach c [winfo children $w] {
        incr n [widgetsInsert $tv $id $c]
    }
    return $n
}
proc widgetsSelect {} {
    set tv $::widgetsTree
    set id [lindex [$tv selection] 0]
    if {$id eq ""} return
    set tags [$tv item $id -tags]
    # tag list is {W .path} — path is the element after W
    set ix [lsearch -exact $tags W]
    if {$ix < 0} return
    set w [lindex $tags [expr {$ix + 1}]]
    if {$w eq "" || ![winfo exists $w]} return

    set ti $::widgetsInfo
    $ti delete 0 end
    runtimeAddRow $ti path $w
    runtimeAddRow $ti class [winfo class $w]
    runtimeAddRow $ti manager [winfo manager $w]
    runtimeAddRow $ti geometry [winfo geometry $w]
    runtimeAddRow $ti "req (w\u00d7h)" "[winfo reqwidth $w] \u00d7 [winfo reqheight $w]"
    runtimeAddRow $ti ismapped [winfo ismapped $w]
    runtimeAddRow $ti viewable [winfo viewable $w]
    runtimeAddRow $ti exists [winfo exists $w]
    runtimeAddRow $ti toplevel [winfo toplevel $w]
    runtimeAddRow $ti parent [winfo parent $w]
    catch {runtimeAddRow $ti "pack info" [pack info $w]}
    catch {runtimeAddRow $ti "grid info" [grid info $w]}
    catch {runtimeAddRow $ti "place info" [place info $w]}

    set tb $::widgetsTags
    $tb delete 0 end
    set i 0
    foreach tag [bindtags $w] {
        $tb insert end [list $i $tag]
        incr i
    }
    if {[$tb size] > 0} {
        $tb selection set 0
        widgetsTagSelect
    } else {
        $::widgetsBinds delete 0 end
    }
}
proc widgetsTagSelect {} {
    set tb $::widgetsTags
    set tn $::widgetsBinds
    if {![winfo exists $tb] || ![winfo exists $tn]} return
    $tn delete 0 end
    set sel [$tb curselection]
    if {[llength $sel] == 0} return
    set tag [lindex [$tb get [lindex $sel 0]] 1]
    foreach seq [lsort [bind $tag]] {
        set script [bind $tag $seq]
        if {[string length $script] > 120} {
            set script "[string range $script 0 117]..."
        }
        $tn insert end [list $seq $script]
    }
    if {[$tn size] == 0} {
        $tn insert end [list "" "(no bindings on $tag)"]
    }
}

# ============================ open channels ================================
proc buildChannels {f} {
    set bar [frame $f.bar]
    ttk::button $bar.refresh -text "Refresh" -command channelsFill
    label $bar.n -textvariable ::chanStatus -fg #555
    pack $bar.refresh $bar.n -side left -padx 4
    pack $bar -fill x -pady 3
    set t [scrolledTable $f \
        {16 Channel left 12 Type left 10 Mode left 12 Encoding left 10 Blocking left 40 Configure left} \
        -height 20]
    set ::chanTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    channelsFill
}
proc channelsFill {} {
    set t $::chanTable
    if {![winfo exists $t]} return
    $t delete 0 end
    foreach ch [lsort [chan names]] {
        set typ ""; set mode ""; set enc ""; set blk ""; set cfg ""
        catch {set typ [chan configure $ch -type]}
        catch {
            set r [chan configure $ch -blocking]
            set blk [expr {$r ? "blocking" : "nonblock"}]
        }
        catch {set enc [chan configure $ch -encoding]}
        catch {set mode [chan configure $ch -mode]}
        if {$mode eq ""} {
            # sockets often have -sockname; files have neither r/w flags here
            catch {
                if {[llength [chan configure $ch -sockname]]} { set mode sock }
            }
        }
        if {[catch {set cfg [chan configure $ch]} err]} { set cfg $err }
        if {[string length $cfg] > 80} { set cfg "[string range $cfg 0 77]..." }
        $t insert end [list $ch $typ $mode $enc $blk $cfg]
    }
    set ::chanStatus "[$t size] channel(s)"
}

# ============================ clipboard probe ==============================
proc buildClipboard {f} {
    set bar [frame $f.bar]
    ttk::button $bar.refresh -text "Read" -command clipboardRead
    ttk::button $bar.clearC -text "Clear CLIPBOARD" -command {clipboardClear CLIPBOARD}
    ttk::button $bar.clearP -text "Clear PRIMARY" -command {clipboardClear PRIMARY}
    label $bar.n -textvariable ::clipStatus -fg #555
    pack $bar.refresh $bar.clearC $bar.clearP $bar.n -side left -padx 3
    pack $bar -fill x -pady 3

    set setf [ttk::labelframe $f.set -text "Set selection" -padding 6]
    label $setf.l -text "Text:"
    entry $setf.e -textvariable ::clipSetText -width 40
    ttk::combobox $setf.sel -textvariable ::clipSetSel -state readonly -width 12 \
        -values {CLIPBOARD PRIMARY}
    ttk::button $setf.go -text "clipboard append" -command clipboardWrite
    pack $setf.l $setf.e $setf.sel $setf.go -side left -padx 3
    pack $setf -fill x -padx 6 -pady 4
    set ::clipSetSel CLIPBOARD
    set ::clipSetText "tkdevtools sample"

    set t [scrolledTable $f {14 Selection left 12 Type left 60 Content left} -height 12]
    set ::clipTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    clipboardRead
}
proc clipboardRead {} {
    set t $::clipTable
    if {![winfo exists $t]} return
    $t delete 0 end
    foreach sel {CLIPBOARD PRIMARY} {
        if {[catch {set types [selection get -displayof . -selection $sel -type TARGETS]} err]} {
            $t insert end [list $sel "(empty/error)" $err]
            continue
        }
        foreach typ $types {
            if {[catch {set data [selection get -displayof . -selection $sel -type $typ]} err]} {
                set data "(error: $err)"
            }
            set data [string map {"\n" "\\n" "\t" "\\t"} $data]
            if {[string length $data] > 100} {
                set data "[string range $data 0 97]..."
            }
            $t insert end [list $sel $typ $data]
        }
    }
    set ::clipStatus "[$t size] row(s)  \u00b7  [clock format [clock seconds] -format %H:%M:%S]"
}
proc clipboardWrite {} {
    set sel $::clipSetSel
    if {[catch {
        clipboard clear -displayof . -selection $sel
        clipboard append -displayof . -selection $sel -- $::clipSetText
    } err]} {
        set ::clipStatus "write error: $err"
        return
    }
    set ::clipStatus "wrote [string length $::clipSetText] char(s) to $sel"
    clipboardRead
}
proc clipboardClear {sel} {
    if {[catch {clipboard clear -displayof . -selection $sel} err]} {
        set ::clipStatus "clear error: $err"
        return
    }
    set ::clipStatus "cleared $sel"
    clipboardRead
}

# ============================ photo formats (load) =========================
proc buildPhotos {f} {
    set bar [frame $f.bar]
    ttk::button $bar.load -text "Load packages" -command photosLoad
    ttk::button $bar.refresh -text "Refresh" -command photosFill
    label $bar.n -textvariable ::photoStatus -fg #555
    pack $bar.load $bar.refresh $bar.n -side left -padx 3
    pack $bar -fill x -pady 3

    set prev [ttk::labelframe $f.prev -text "probe images" -padding 6]
    set ::photoPrev [frame $prev.g]
    pack $::photoPrev -fill x
    pack $prev -fill x -padx 6 -pady 4

    set t [scrolledTable $f \
        {22 Package left 10 Version left 12 Status left 40 Detail left} -height 14]
    set ::photoTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    photosFill
}
proc photosFill {} {
    set t $::photoTable
    if {![winfo exists $t]} return
    $t delete 0 end
    foreach p {
        Img img::png img::jpeg img::gif img::bmp img::tiff img::ico
        img::xbm img::xpm img::ppm img::window img::pcx img::sgi img::sun img::tga
    } {
        set ver ""; set st "unknown"; set det ""
        if {![catch {package present $p} v]} {
            set ver $v; set st loaded
        } elseif {[llength [set vers [package versions $p]]]} {
            set ver [join [lsort -dictionary $vers] {, }]
            set st available
            catch {set det [lindex [package ifneeded $p [lindex [lsort -dictionary $vers] end]] end]}
            if {[string length $det] > 60} { set det "[string range $det 0 57]..." }
        } else {
            set st missing
        }
        $t insert end [list $p $ver $st $det]
    }
    # core Tk photo formats (always there when Tk is loaded)
    foreach fmt {gif ppm pgm} {
        $t insert end [list "Tk core:$fmt" $::tk_patchLevel builtin "image create photo -format $fmt"]
    }
    set ::photoStatus "[$t size] row(s) \u2014 click \u201eLoad packages\u201c to require Img formats"
}
proc photosLoad {} {
    set t $::photoTable
    set loaded 0; set failed 0
    foreach p {
        Img img::png img::jpeg img::gif img::bmp img::tiff img::ico
        img::xbm img::xpm img::ppm img::window
    } {
        if {![catch {package require $p} v]} {
            incr loaded
        } else {
            incr failed
        }
    }
    photosFill
    photosProbe
    set ::photoStatus "require: $loaded ok, $failed fail \u2014 probe images below"
}
proc photosProbe {} {
    set g $::photoPrev
    if {![winfo exists $g]} return
    foreach c [winfo children $g] { destroy $c }
    set col 0
    set i 0
    foreach {label fmt var} {
        gif-core gif ::photoGifB64
        png-Img  png ::photoPngB64
    } {
        incr i
        set cell [frame $g.c$i -relief groove -bd 1]
        set img ""
        if {[catch {
            if {$fmt eq "png"} { package require img::png }
            set img [image create photo -format $fmt -data [set $var]]
        } err]} {
            label $cell.l -text "$label\n(n/a: [lindex [split $err \n] 0])" -fg #a00
        } else {
            label $cell.i -image $img
            label $cell.l -text "$label\n[$img cget -width]x[$img cget -height]"
            pack $cell.i -padx 6 -pady 2
        }
        pack $cell.l -padx 6 -pady 2
        grid $cell -row 0 -column $col -padx 8 -pady 4
        incr col
    }
}
# 1x1 red GIF (base64) and 1x1 red PNG
set ::photoGifB64 {R0lGODlhAQABAPAAAP8AAP///yH5BAAAAAAALAAAAAABAAEAAAICRAEAOw==}
set ::photoPngB64 {iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==}

# ============================ external tools ===============================
proc buildTools {f} {
    label $f.hint -anchor w -justify left -wraplength 720 -fg #333 \
        -text "Startet bekannte Entwickler-Hilfen in einem eigenen Prozess\
 (oder einbettet tkcon). Fehlt ein Tool, steht der Hinweis in der Zeile."
    pack $f.hint -anchor w -padx 8 -pady 6

    set t [scrolledTable $f \
        {18 Tool left 12 Status left 56 Detail left} -height 8]
    set ::toolsTable $t
    catch {::tkutils::tkutlclip::installBindings $t}

    set bar [frame $f.bar]
    ttk::button $bar.tkcon -text "tkcon (embed)" -command toolsTkconEmbed
    ttk::button $bar.tkcon2 -text "tkcon (process)" -command toolsTkconProcess
    ttk::button $bar.insp -text "tkinspect" -command toolsTkinspect
    ttk::button $bar.demo -text "Tk widget demo" -command toolsWidgetDemo
    ttk::button $bar.refresh -text "Refresh" -command toolsFill
    pack $bar.tkcon $bar.tkcon2 $bar.insp $bar.demo $bar.refresh -side left -padx 4
    pack $bar -fill x -padx 6 -pady 4

    label $f.msg -textvariable ::toolsMsg -anchor w -fg #225
    pack $f.msg -fill x -padx 8 -pady 4
    toolsFill
}
proc toolsFindTkcon {} {
    set exe [auto_execok tkcon]
    if {$exe ne ""} { return [list exe [lindex $exe 0]] }
    foreach p {
        /usr/share/tcltk/tkcon2.7.10/tkcon.tcl
        /usr/share/tcltk/tkcon/tkcon.tcl
    } {
        if {[file isfile $p]} { return [list script $p] }
    }
    if {[llength [package versions tkcon]]} {
        return [list package tkcon]
    }
    return {}
}
proc toolsFindTkinspect {} {
    set exe [auto_execok tkinspect]
    if {$exe ne ""} { return [list exe [lindex $exe 0]] }
    foreach p {
        /usr/bin/tkinspect
        /usr/local/bin/tkinspect
    } {
        if {[file isfile $p]} { return [list exe $p] }
    }
    return {}
}
proc toolsFindWidgetDemo {} {
    set candidates [list \
        [file join $::tk_library demos widget] \
        /usr/share/doc/tk$::tk_version-doc/demos/widget \
        /usr/share/doc/tk8.6-doc/demos/widget \
        /usr/share/doc/tk9.0-doc/demos/widget]
    foreach p $candidates {
        if {[file isfile $p]} { return $p }
    }
    return ""
}
proc toolsFill {} {
    set t $::toolsTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set tkc [toolsFindTkcon]
    if {[llength $tkc]} {
        $t insert end [list tkcon found "[join $tkc " \u2192 "]"]
    } else {
        $t insert end [list tkcon missing "apt: tkcon  \u00b7  package require tkcon"]
    }
    set insp [toolsFindTkinspect]
    if {[llength $insp]} {
        $t insert end [list tkinspect found "[join $insp " \u2192 "]"]
    } else {
        $t insert end [list tkinspect missing "apt: tkinspect  (nicht installiert)"]
    }
    set demo [toolsFindWidgetDemo]
    if {$demo ne ""} {
        $t insert end [list "widget demo" found $demo]
    } else {
        $t insert end [list "widget demo" missing "tk_library/demos/widget oder tk*-doc"]
    }
    set ::toolsMsg "wish [info nameofexecutable]  \u00b7  [info patchlevel]"
}
proc toolsTkconEmbed {} {
    set loc [toolsFindTkcon]
    if {![llength $loc]} {
        set ::toolsMsg "tkcon nicht gefunden"
        return
    }
    if {[catch {
        if {![llength [package versions tkcon]] && [lindex $loc 0] eq "script"} {
            set dir [file dirname [lindex $loc 1]]
            if {$dir ni $::auto_path} { lappend ::auto_path $dir }
        }
        package require tkcon
        tkcon show
    } err]} {
        set ::toolsMsg "tkcon embed: $err"
        return
    }
    set ::toolsMsg "tkcon eingebettet (tkcon show)"
}
proc toolsTkconProcess {} {
    set loc [toolsFindTkcon]
    if {![llength $loc]} {
        set ::toolsMsg "tkcon nicht gefunden"
        return
    }
    if {[catch {
        switch -- [lindex $loc 0] {
            exe    { exec [lindex $loc 1] & }
            script { exec [info nameofexecutable] [lindex $loc 1] & }
            package {
                exec [info nameofexecutable] << {
                    package require tkcon
                    tkcon show
                    vwait forever
                } &
            }
        }
    } err]} {
        set ::toolsMsg "tkcon process: $err"
        return
    }
    set ::toolsMsg "tkcon als Prozess gestartet"
}
proc toolsTkinspect {} {
    set loc [toolsFindTkinspect]
    if {![llength $loc]} {
        set ::toolsMsg "tkinspect fehlt \u2014 z. B.: apt install tkinspect"
        return
    }
    if {[catch {exec [lindex $loc 1] &} err]} {
        set ::toolsMsg "tkinspect: $err"
        return
    }
    set ::toolsMsg "tkinspect gestartet"
}
proc toolsWidgetDemo {} {
    set demo [toolsFindWidgetDemo]
    if {$demo eq ""} {
        set ::toolsMsg "Widget-Demo nicht gefunden"
        return
    }
    if {[catch {exec [info nameofexecutable] $demo &} err]} {
        set ::toolsMsg "widget demo: $err"
        return
    }
    set ::toolsMsg "Widget-Demo gestartet: $demo"
}

# ============================ Runtime: package shadows =====================
# Every copy of a package on the module paths and auto_path, from
# tclutils::tupkgfinder::shadows. The package database keeps one ifneeded per
# version, so a second copy with the SAME version (an installed library next
# to a working tree) is invisible in "Packages"; here it is marked.
proc buildShadows {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Filter:"
    entry $bar.e -textvariable ::shFilter -width 18
    checkbutton $bar.all -text "also single copies" -variable ::shAll -command shFill
    ttk::button $bar.refresh -text "Refresh" -command shFill
    label $bar.n -textvariable ::shStatus -fg #555
    pack $bar.l $bar.e $bar.all $bar.refresh $bar.n -side left -padx 3
    pack $bar -fill x -pady 3
    label $f.hint -anchor w -justify left -fg #555 -text \
        "\"same version\": a second copy of the version package require takes -- it is never\
        used, and which one wins depends on path order. Red rows need a look."
    pack $f.hint -fill x -padx 6
    set t [scrolledTable $f \
        {26 Package left 10 Version left 13 Status left 8 Kind left 60 Path left} \
        -height 20]
    set ::shTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    bind $bar.e <KeyRelease> shFill
    set ::shFilter ""
    set ::shAll 0
    shFill
}
proc shFill {} {
    set t $::shTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set pat *
    if {$::shFilter ne ""} { set pat *$::shFilter* }
    if {[catch {::tclutils::tupkgfinder::shadows -pattern $pat -all $::shAll} res]} {
        set ::shStatus "error: $res"
        return
    }
    set npk 0 ; set ndup 0
    foreach d $res {
        incr npk
        if {[dict get $d duplicate]} { incr ndup }
        set first 1
        foreach c [dict get $d candidates] {
            set name [expr {$first ? [dict get $d package] : ""}]
            set first 0
            $t insert end [list $name [dict get $c version] [dict get $c status] \
                [dict get $c kind] [file nativename [dict get $c path]]]
            switch -- [dict get $c status] {
                "same version"  { $t rowconfigure end -background #ffd8d8 }
                active          { $t rowconfigure end -foreground #064 }
                default         { $t rowconfigure end -foreground #777 }
            }
        }
    }
    set what [expr {$::shAll ? "package(s)" : "package(s) with several copies"}]
    set ::shStatus "$npk $what, $ndup with one version twice"
}

# ============================ Platform: paths ==============================
# What Tcl's file commands make of a path, and how Windows and Unix classify
# it. The Windows/Unix columns follow the rules of file pathtype, so a path
# can be checked for the other platform too.
proc pathTypeFor {platform p} {
    if {$platform eq "windows"} {
        set p [string map {\\ /} $p]
        if {[regexp {^//[^/]+/[^/]+} $p]}  { return absolute }       ;# UNC
        if {[regexp {^[A-Za-z]:/} $p]}     { return absolute }
        if {[regexp {^[A-Za-z]:} $p]}      { return volumerelative } ;# C:x
        if {[string match /* $p]}          { return volumerelative } ;# /x
        return relative
    }
    if {[string match /* $p]} { return absolute }
    return relative   ;# Tcl 9: no ~ expansion; 8.6 treats ~ as absolute
}
proc buildPathProbe {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Path:"
    entry $bar.e -textvariable ::ppPath -width 50
    pack $bar.l $bar.e -side left -padx 3
    pack $bar -fill x -pady 3
    set ex [frame $f.ex]
    label $ex.l -text "Examples:" -fg #555
    pack $ex.l -side left -padx 3
    foreach p {/x C:x C:/x //srv/share/x ~/x a/../../b /a/./b/../c C:/a/../../b} {
        ttk::button $ex.b[incr i] -text $p -command [list set ::ppPath $p]
        pack $ex.b$i -side left -padx 1
    }
    pack $ex -fill x -padx 3 -pady {0 4}
    set t [scrolledTable $f {24 Command left 70 Result left} -height 18]
    set ::ppTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    trace add variable ::ppPath write {apply {args { after idle ppFill }}}
    set ::ppPath a/../../b
}
proc ppFill {} {
    set t $::ppTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set p $::ppPath
    set rows [list \
        "pathtype (this: $::tcl_platform(platform))" {file pathtype $p} \
        "pathtype, Windows rules"  {pathTypeFor windows $p} \
        "pathtype, Unix rules"     {pathTypeFor unix $p} \
        "file split"               {file split $p} \
        "file dirname"             {file dirname $p} \
        "file tail"                {file tail $p} \
        "file rootname"            {file rootname $p} \
        "file extension"           {file extension $p} \
        "file join \$p x"          {file join $p x} \
        "file nativename"          {file nativename $p} \
        "file normalize"           {file normalize $p} \
        "tupath::clean"            {::tclutils::tupath::clean $p} \
        "file exists"              {file exists $p} \
    ]
    foreach {label script} $rows {
        if {[catch $script r]} { set r "error: $r" }
        $t insert end [list $label $r]
    }
}

# ============================ Platform: glob ===============================
# What a pattern matches here. Windows differs: "*" matches dot files there,
# so "*" plus ".*" lists them twice -- the tkufiletree ITEM_EXISTS case.
proc buildGlobProbe {f} {
    set bar [frame $f.bar]
    label $bar.dl -text "Directory:"
    entry $bar.d -textvariable ::gpDir -width 40
    ttk::button $bar.b -text "..." -width 3 -command {
        set d [tk_chooseDirectory -initialdir $::gpDir -mustexist 1]
        if {$d ne ""} { set ::gpDir $d ; gpFill }
    }
    label $bar.pl -text "Pattern:"
    entry $bar.p -textvariable ::gpPat -width 12
    pack $bar.dl $bar.d $bar.b $bar.pl $bar.p -side left -padx 3
    pack $bar -fill x -pady 3
    set opt [frame $f.opt]
    label $opt.l -text "-types:"
    pack $opt.l -side left -padx 3
    foreach ty {f d hidden} {
        checkbutton $opt.$ty -text $ty -variable ::gpType($ty) -command gpFill
        pack $opt.$ty -side left
    }
    checkbutton $opt.dot -text {also ".*" (as a hidden-files option does)} \
        -variable ::gpDot -command gpFill
    pack $opt.dot -side left -padx 8
    pack $opt -fill x -padx 3
    label $f.st -textvariable ::gpStatus -anchor w -justify left -fg #225
    pack $f.st -fill x -padx 6 -pady 3
    set t [scrolledTable $f {40 Name left 10 Type left 10 Note left} -height 16]
    set ::gpTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    foreach w [list $bar.d $bar.p] { bind $w <Return> gpFill ; bind $w <FocusOut> gpFill }
    set ::gpDir [pwd]
    set ::gpPat *
    array set ::gpType {f 0 d 0 hidden 0}
    set ::gpDot 0
    gpFill
}
proc gpFill {} {
    set t $::gpTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set types [lmap ty {f d hidden} { if {$::gpType($ty)} { set ty } else continue }]
    set cmd [list glob -nocomplain -directory $::gpDir]
    if {[llength $types]} { lappend cmd -types $types }
    if {[catch {{*}$cmd -- $::gpPat} res]} {
        set ::gpStatus "error: $res"
        return
    }
    set dots {}
    if {$::gpDot} {
        catch {set dots [lmap x [{*}$cmd -- .*] {
            if {[file tail $x] in {. ..}} continue ; set x }]}
        lappend res {*}$dots
    }
    set count {}
    foreach r $res { dict incr count $r }
    set ndup 0
    foreach r [lsort -dictionary $res] {
        set ty [expr {[file isdirectory $r] ? "dir" : "file"}]
        set note ""
        if {[dict get $count $r] > 1} { set note twice ; incr ndup }
        $t insert end [list [file tail $r] $ty $note]
        if {$note ne ""} { $t rowconfigure end -background #ffd8d8 }
    }
    # how many dot files "*" leaves out here (it does not on Windows)
    set hidden [llength [lmap x [glob -nocomplain -directory $::gpDir .*] {
        if {[file tail $x] in {. ..}} continue ; set x }]]
    set cmdText "glob -directory <dir>[expr {[llength $types] ? " -types {$types}" : ""}] -- $::gpPat"
    set ::gpStatus "$cmdText  ->  [llength $res] result(s)"
    if {$ndup} { append ::gpStatus ", [expr {$ndup / 2}] listed twice" }
    if {$::gpPat eq "*" && $::tcl_platform(platform) ne "windows" && $hidden} {
        append ::gpStatus "\nHere \"*\" skips the $hidden dot file(s); on Windows it\
            matches them, and \"*\" plus \".*\" lists them twice."
    }
}

# ============================ Platform: programs ===========================
# Which program a name resolves to (auto_execok), and where along PATH the
# candidates are -- with the platform's separator and, on Windows, PATHEXT.
proc buildProgProbe {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Program:"
    entry $bar.e -textvariable ::prName -width 24
    ttk::button $bar.go -text "Look up" -command prFill
    pack $bar.l $bar.e $bar.go -side left -padx 3
    pack $bar -fill x -pady 3
    label $f.st -textvariable ::prStatus -anchor w -justify left -fg #225 -wraplength 820
    pack $f.st -fill x -padx 6 -pady 3
    set t [scrolledTable $f {6 "#" right 52 "PATH entry" left 40 Found left} -height 18]
    set ::prTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    bind $bar.e <Return> prFill
    set ::prName [regsub -nocase {\.exe$} [file tail [info nameofexecutable]] ""]
    prFill
}
proc prFill {} {
    set t $::prTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set name $::prName
    set win [expr {$::tcl_platform(platform) eq "windows"}]
    set sep [expr {$win ? ";" : ":"}]
    set exts {""}
    if {$win} {
        set pe .COM\;.EXE\;.BAT\;.CMD
        if {[info exists ::env(PATHEXT)]} { set pe $::env(PATHEXT) }
        set exts [concat {""} [split [string tolower $pe] ";"]]
    }
    array unset ::auto_execs $name   ;# no cached answer
    set ae [auto_execok $name]
    set path [expr {[info exists ::env(PATH)] ? $::env(PATH) : ""}]
    set i 0 ; set hits 0
    foreach dir [split $path $sep] {
        incr i
        if {$dir eq ""} continue
        set found {}
        foreach e $exts {
            set f [file join $dir $name$e]
            if {[file isfile $f] && ($win || [file executable $f])} { lappend found [file tail $f] }
        }
        if {[llength $found]} { incr hits }
        $t insert end [list $i $dir [join $found ", "]]
        if {[llength $found]} { $t rowconfigure end -background #e2f4e2 }
    }
    set ::prStatus "auto_execok $name  ->  [expr {$ae eq "" ? "(not found)" : $ae}]\
        \nPATH separator \"$sep\", $i entries, found in $hits"
    if {$win} {
        append ::prStatus "\nPATHEXT: [join [lrange $exts 1 end] { }]\
            -- a launcher that goes through \"cmd /c start\" also finds programs\
            registered under App Paths, which are not on PATH."
    }
}

# ============================ Platform: encoding profiles ==================
# How the bytes are read with each -profile (Tcl 9): strict raises an error
# at the first invalid byte, replace puts U+FFFD there, tcl8 maps it as Tcl
# 8.6 did. A test runner reading a child's output with strict stalled on
# one such byte.
proc buildEncProfile {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Bytes (hex):"
    entry $bar.e -textvariable ::epHex -width 36
    label $bar.el -text "Encoding:"
    ttk::combobox $bar.enc -textvariable ::epEnc -width 14 \
        -values [lsort [encoding names]]
    pack $bar.l $bar.e $bar.el $bar.enc -side left -padx 3
    pack $bar -fill x -pady 3
    label $f.st -textvariable ::epStatus -anchor w -justify left -fg #225
    pack $f.st -fill x -padx 6 -pady 3
    set t [scrolledTable $f {10 Profile left 50 Result left 40 "Code points" left} -height 8]
    set ::epTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    bind $bar.e <KeyRelease> epFill
    bind $bar.enc <<ComboboxSelected>> epFill
    bind $bar.enc <KeyRelease> epFill
    set ::epHex "48 69 20 FF E4 81"
    set ::epEnc utf-8
    epFill
}
proc epCodepoints {s} {
    set out {}
    foreach ch [split $s ""] {
        scan $ch %c cp
        lappend out [format U+%04X $cp]
    }
    return [join $out " "]
}
proc epFill {} {
    set t $::epTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set hex [regsub -all {[^0-9A-Fa-f]} $::epHex ""]
    if {[string length $hex] % 2} { set ::epStatus "odd number of hex digits" ; return }
    set bytes [binary format H* $hex]
    if {$::epEnc ni [encoding names]} { set ::epStatus "unknown encoding" ; return }
    if {[package vsatisfies [package provide Tcl] 9-]} {
        set ::epStatus "Tcl [info patchlevel]: channels read with the profile set by\
            chan configure -profile (default strict)."
        foreach prof {strict replace tcl8} {
            if {[catch {encoding convertfrom -profile $prof -failindex fi $::epEnc $bytes} s]} {
                $t insert end [list $prof "error: $s" ""]
                $t rowconfigure end -background #ffd8d8
                continue
            }
            set note ""
            if {$prof eq "strict" && $fi >= 0} {
                set note "  (stops at byte $fi)"
                $t insert end [list $prof "[epShow $s]$note" [epCodepoints $s]]
                $t rowconfigure end -background #ffd8d8
                continue
            }
            $t insert end [list $prof [epShow $s] [epCodepoints $s]]
        }
    } else {
        set ::epStatus "Tcl [info patchlevel] has no -profile: invalid bytes are\
            mapped silently (what Tcl 9 calls the tcl8 profile)."
        set s [encoding convertfrom $::epEnc $bytes]
        $t insert end [list (8.6) [epShow $s] [epCodepoints $s]]
    }
}
# printable view: non-printable characters as U+XXXX
proc epShow {s} {
    set out ""
    foreach ch [split $s ""] {
        scan $ch %c cp
        if {$cp < 32 || ($cp >= 127 && $cp < 160)} {
            append out [format <U+%04X> $cp]
        } else { append out $ch }
    }
    return $out
}

# ============================ Reference: font aliases ======================
# What Tk makes of a family name. A family that comes back unchanged (Tk 9
# on Windows: "Helvetica" stays "Helvetica") can collide with a PDF standard
# font of the same name in an export.
proc buildFontAliases {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Add family:"
    entry $bar.e -textvariable ::faExtra -width 24
    ttk::button $bar.add -text "Add" -command faFill
    pack $bar.l $bar.e $bar.add -side left -padx 3
    pack $bar -fill x -pady 3
    label $f.hint -anchor w -justify left -fg #555 -text \
        "Green: Tk substituted another family. Yellow: the name came back unchanged."
    pack $f.hint -fill x -padx 6
    set t [scrolledTable $f \
        {20 Requested left 24 "Resolved family" left 6 Size right 8 Weight left \
         8 Slant left 6 Ascent right 7 Descent right 9 Linespace right} -height 20]
    set ::faTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    bind $bar.e <Return> faFill
    set ::faExtra ""
    faFill
}
proc faFill {} {
    set t $::faTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set names {Helvetica Times Courier Arial {Times New Roman} {Courier New}
               Symbol {DejaVu Sans} TkDefaultFont TkTextFont TkFixedFont
               TkMenuFont TkHeadingFont TkCaptionFont TkSmallCaptionFont
               TkIconFont TkTooltipFont}
    if {$::faExtra ne ""} { lappend names $::faExtra }
    foreach n $names {
        set spec [expr {[string match Tk* $n] && $n in [font names] ? $n : [list $n 12]}]
        if {[catch {font actual $spec} a]} {
            $t insert end [list $n "error: $a" "" "" "" "" "" ""]
            continue
        }
        set m [font metrics $spec]
        $t insert end [list $n [dict get $a -family] [dict get $a -size] \
            [dict get $a -weight] [dict get $a -slant] [dict get $m -ascent] \
            [dict get $m -descent] [dict get $m -linespace]]
        if {![string match Tk* $n]} {
            if {[string equal -nocase [dict get $a -family] $n]} {
                $t rowconfigure end -background #fff3c4
            } else {
                $t rowconfigure end -background #e2f4e2
            }
        }
    }
}

# ============================ Conversion: number format ====================
# The same values through [format %.Nf] (rounding left to the C runtime:
# halfway cases differ between glibc and Windows) and tclutils::tunum::format
# (half away from zero on every platform, German grouping).
proc buildNumFormat {f} {
    set bar [frame $f.bar]
    label $bar.l -text "Values:"
    entry $bar.e -textvariable ::nfValues -width 44
    label $bar.dl -text "Decimals:"
    ttk::spinbox $bar.d -from 0 -to 8 -width 4 -textvariable ::nfDec -command nfFill
    pack $bar.l $bar.e $bar.dl $bar.d -side left -padx 3
    pack $bar -fill x -pady 3
    label $f.hint -anchor w -justify left -fg #555 -text \
        "Red: format and tunum::format round differently. \"stored as\" shows the binary\
        double -- 2.675 is stored just below, yet tunum gives 2.68 (it rounds the digits\
        Tcl prints)."
    pack $f.hint -fill x -padx 6
    set t [scrolledTable $f \
        {14 Value left 26 "stored as (%.17g)" left 16 "format %.Nf" left 18 "tunum::format" left} \
        -height 16]
    set ::nfTable $t
    catch {::tkutils::tkutlclip::installBindings $t}
    bind $bar.e <KeyRelease> nfFill
    bind $bar.d <KeyRelease> nfFill
    set ::nfValues "1234.5 2.5 0.5 -0.5 2.675 1.005 0.125 1000000.455"
    set ::nfDec 0
    nfFill
}
proc nfFill {} {
    set t $::nfTable
    if {![winfo exists $t]} return
    $t delete 0 end
    set n $::nfDec
    if {![string is integer -strict $n] || $n < 0} return
    foreach v $::nfValues {
        if {![string is double -strict $v]} {
            $t insert end [list $v "(not a number)" "" ""] ; continue
        }
        set c [format %.*f $n $v]
        if {[catch {::tclutils::tunum::format $v -decimals $n} u]} { set u "error: $u" }
        $t insert end [list $v [format %.17g $v] $c $u]
        # compare without the German separators
        set uPlain [string map {. "" , .} $u]
        if {$uPlain ne $c} { $t rowconfigure end -background #ffd8d8 }
    }
}

# ============================ assemble ======================================
namespace eval ::tkdevtools {}

# (1) buildApp assembles the whole UI into "." and returns -- no event loop, no
#     blocking. The argv0 guard at the end runs it directly; build-app packages
#     it with -launch '::tkdevtools::buildApp .'. (A parent arg is accepted for
#     that call, but the toolbox is hardwired to the main window ".".)
proc ::tkdevtools::buildApp {{parent .}} {
wm title . "Tcl/Tk Developer Toolbox"

# navigation tree (left) + stacked content frames (right)
ttk::panedwindow .pw -orient horizontal
frame .pw.nav
ttk::treeview .pw.nav.tv -show tree \
    -yscrollcommand [list .pw.nav.sb set]
.pw.nav.tv column #0 -width 200 -minwidth 140
ttk::scrollbar .pw.nav.sb -orient vertical -command [list .pw.nav.tv yview]
pack .pw.nav.sb -side right -fill y
pack .pw.nav.tv -side left -fill both -expand 1
frame .pw.content
grid rowconfigure    .pw.content 0 -weight 1
grid columnconfigure .pw.content 0 -weight 1
.pw add .pw.nav
.pw add .pw.content -weight 1
pack .pw -fill both -expand 1

proc ::navSelect {} {
    set id [lindex [.pw.nav.tv selection] 0]
    if {[info exists ::navFrame($id)]} { raise $::navFrame($id) }
}

# category -> {key title buildProc ...}
set ::toolTree {
    "Runtime" {
        tcltk   "Tcl / Tk"         buildTclTk
        os      "OS / platform"    buildOs
        pkgs    "Packages"         buildPackages
        shadow  "Package shadows"  buildShadows
        paths   "Paths"            buildPaths
        display "Display"          buildDisplay
        env     "Environment"      buildEnv
        chans   "Channels"         buildChannels
        photos  "Photo formats"    buildPhotos
        tools   "External tools"   buildTools
    }
    "Reference" {
        colors  "Colors"          buildColors
        chars   "Characters"      buildChars
        graph   "Graphemes"       buildGraphemes
        fonts   "Fonts"           buildFonts
        bitmaps "Bitmaps"         buildBitmaps
        falias  "Font aliases"    buildFontAliases
    }
    "Conversion / time" {
        units   "Units"           buildUnits
        tz      "Timezones"       buildTz
        clock   "clock format"    buildClock
        numfmt  "Number format"   buildNumFormat
    }
    "Platform" {
        pathp   "Paths"            buildPathProbe
        globp   "glob"             buildGlobProbe
        progp   "Programs"         buildProgProbe
        encprof "Encoding profiles" buildEncProfile
    }
    "Tk widgets / style" {
        widgets "Widget tree"      buildWidgets
        clip    "Clipboard"        buildClipboard
        cursors "Cursors"          buildCursors
        relief  "Relief / Anchor"  buildRelief
        keysym  "Keysym probe"     buildKeysym
        themes  "ttk Themes"       buildThemes
        wexpl   "Widget explorer"  buildWidgetExplorer
    }
    "Layout" {
        pack    "pack"             buildPack
        grid    "grid"             buildGrid
    }
    "Text / patterns" {
        regexp  "regexp"          buildRegexp
        fmt     "format / scan"   buildFormatScan
        enc     "Encodings"       buildEncodings
        vevents "Virtual events"  buildVirtualEvents
    }
}

set first ""
foreach {cat items} $::toolTree {
    set parent [.pw.nav.tv insert {} end -text $cat -open 1]
    foreach {key title proc} $items {
        set fr .pw.content.$key
        frame $fr
        grid $fr -row 0 -column 0 -sticky nsew
        $proc $fr
        set node [.pw.nav.tv insert $parent end -text $title]
        set ::navFrame($node)   $fr
        set ::navNode($key)     $node
        if {$first eq ""} { set first $node }
    }
}
bind .pw.nav.tv <<TreeviewSelect>> navSelect
.pw.nav.tv selection set $first
navSelect
}

# (3) Screenshot helper -- Img's "window" photo format grabs a Tk window with no
#     external tool, works cross-platform and inside a zipkit. Falls back to
#     ImageMagick's "import" only if img::window is unavailable.
proc ::tkdevtools::shot {out {key ""}} {
    if {$key ne "" && [info exists ::navNode($key)]} {
        .pw.nav.tv selection set $::navNode($key); navSelect
    }
    wm geometry . 900x600
    update idletasks; update; after 500; update
    if {![catch {package require img::window}]} {
        set p [image create photo -format window -data .]
        $p write $out -format png
        image delete $p
    } else {
        catch {exec import -window root $out}
    }
}

# (1) argv0 guard: build the UI when run as the main program. Inside a zipkit
#     this does NOT fire (main.tcl sources the file); build-app is told the
#     entry with -launch '::tkdevtools::buildApp .'.
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    package require Tk 8.6-
    ::tkdevtools::buildApp
    if {[lindex $argv 0] eq "--shot"} {
        ::tkdevtools::shot [lindex $argv 1] [lindex $argv 2]
        exit 0
    }
}
