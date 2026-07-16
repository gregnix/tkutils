#!/usr/bin/env wish
# ===========================================================================
# Tcl/Tk Developer Toolbox -- a single app that bundles reference / helper
# views a Tk programmer reaches for: named colors, a codepage / Unicode char
# map, font families, screen-unit conversion, world time zones, mouse cursors,
# a relief / anchor / sticky cheat sheet, a keysym probe and a ttk theme/style
# browser. Each view is a notebook tab; data is shown as tables, and the theme
# browser uses a tree. Belongs to tkutils.
#
#   wish tkdevtools.tcl
#   tclsh tkdevtools.tcl --shot out.png ?toolKey?   (e.g. themes, regexp)
# ===========================================================================

# locate tkutils / tclutils via the shared bootstrap (as the other apps do):
# resolves TCLUTILS_TM/TKUTILS_TM, the install/share/XDG locations and a
# side-by-side source checkout -- a missing package then fails loudly later.
source [file join [file dirname [file normalize [info script]]] .. _lib paths.tcl]

package require Tk
package require tablelist
package require tclutils::tucolor
catch {package require tkutils::tkutlsort}
catch {package require tkutils::tkutlfind}
catch {package require tkutils::tkutlclip}

# ----------------------------------------------------------------------------
# helper: a tablelist with vertical + horizontal scrollbars, wrapped in a frame
# (so the caller can pack it). Returns the tablelist path.
# ----------------------------------------------------------------------------
proc scrolledTable {parent cols args} {
    set fr $parent.tf
    frame $fr
    set t $fr.t
    tablelist::tablelist $t -columns $cols -stretch all \
        -stripebackground #f4f4f4 -labelcommand tablelist::sortByColumn \
        -yscrollcommand [list $fr.vsb set] -xscrollcommand [list $fr.hsb set] \
        {*}$args
    ttk::scrollbar $fr.vsb -orient vertical   -command [list $t yview]
    ttk::scrollbar $fr.hsb -orient horizontal -command [list $t xview]
    grid $t        -row 0 -column 0 -sticky nsew
    grid $fr.vsb   -row 0 -column 1 -sticky ns
    grid $fr.hsb   -row 1 -column 0 -sticky ew
    grid rowconfigure    $fr 0 -weight 1
    grid columnconfigure $fr 0 -weight 1
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
proc charPrintable {cp} {
    if {$cp < 0x20} { return 0 }
    if {$cp >= 0x7F && $cp <= 0xA0} { return 0 }
    return 1
}
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
            if {![charPrintable $cp]} continue
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
set ::unitSuffix {px "" pt p mm m cm c inch i}
proc unitToPixels {val unit} { winfo fpixels . "$val[dict get $::unitSuffix $unit]" }
proc unitFromPixels {px} {
    set ppi [winfo fpixels . 1i]; set ppm [winfo fpixels . 1m]
    dict create px $px pt [expr {$px/($ppi/72.0)}] mm [expr {$px/$ppm}] \
        cm [expr {$px/($ppm*10.0)}] inch [expr {$px/$ppi}]
}
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
        set d [unitFromPixels [unitToPixels $val $unit]]
        $t insert end [list $spec [dict get $d px] [dict get $d pt] \
            [dict get $d mm] [dict get $d cm] [dict get $d inch]]
    }
    pack $ref -fill both -expand 1 -padx 6 -pady 4
    unitConvert
}
proc unitConvert {args} {
    if {![string is double -strict $::unitVal]} { set ::unitOut "(enter a number)"; return }
    set d [unitFromPixels [unitToPixels $::unitVal $::unitU]]
    set ::unitOut [format "%.1f px  |  %.2f pt  |  %.2f mm  |  %.3f cm  |  %.4f inch" \
        [dict get $d px] [dict get $d pt] [dict get $d mm] [dict get $d cm] [dict get $d inch]]
}

# ============================ Timezones =====================================
proc tzList {} {
    set zones {}; set dirs {}
    lappend dirs [file join [info library] tzdata]
    # ::tcl_pkgPath is not defined on every Tcl build (notably some
    # Windows installations), so guard the access before iterating it.
    if {[info exists ::tcl_pkgPath]} {
        foreach p $::tcl_pkgPath { lappend dirs [file join $p tzdata] }
    }
    lappend dirs /usr/share/zoneinfo
    foreach base $dirs {
        if {![file isdirectory $base]} continue
        foreach z [glob -nocomplain -directory $base -tails -type f */* */*/*] {
            if {[regexp {^[A-Z][A-Za-z_]+/[A-Za-z0-9_+/-]+$} $z]} { lappend zones $z }
        }
        if {[llength $zones]} break
    }
    if {![llength $zones]} {
        set zones {UTC Europe/Berlin Europe/London America/New_York America/Los_Angeles
            Asia/Tokyo Asia/Shanghai Asia/Kolkata Australia/Sydney Pacific/Auckland}
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
# This is a SIMPLIFIED UAX #29 segmenter covering the common cases. When a future
# Tcl core gains a native grapheme command, prefer it in graphemeClusters, e.g.:
#   if {![catch {set out [string ?grapheme? $s]}]} { return $out }   ;# name TBD
proc graphExtend {cp} {
    expr {
        ($cp >= 0x0300 && $cp <= 0x036F) || ($cp >= 0x0483 && $cp <= 0x0489) ||
        ($cp >= 0x0591 && $cp <= 0x05BD) || ($cp >= 0x0610 && $cp <= 0x061A) ||
        ($cp >= 0x064B && $cp <= 0x065F) || ($cp >= 0x1AB0 && $cp <= 0x1AFF) ||
        ($cp >= 0x1DC0 && $cp <= 0x1DFF) || ($cp >= 0x20D0 && $cp <= 0x20FF) ||
        ($cp >= 0xFE00 && $cp <= 0xFE0F) || ($cp >= 0x1F3FB && $cp <= 0x1F3FF) ||
        $cp == 0x200C
    }
}
proc graphRI {cp} { expr {$cp >= 0x1F1E6 && $cp <= 0x1F1FF} }
proc graphemeClusters {s} {
    set chars [split $s ""]; set n [llength $chars]; set out {}; set i 0
    while {$i < $n} {
        set cl [lindex $chars $i]; incr i
        set ri [expr {[graphRI [scan $cl %c]] ? 1 : 0}]
        while {$i < $n} {
            set cp [scan [lindex $chars $i] %c]
            if {[graphExtend $cp]} { append cl [lindex $chars $i]; incr i; continue }
            if {$cp == 0x200D} {                       ;# ZWJ: joins the next base
                append cl [lindex $chars $i]; incr i
                if {$i < $n} { append cl [lindex $chars $i]; incr i }
                continue
            }
            if {$ri == 1 && [graphRI $cp]} {            ;# regional-indicator pair (flag)
                append cl [lindex $chars $i]; incr i; set ri 2; continue
            }
            break
        }
        lappend out $cl
    }
    return $out
}
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
    set clusters [graphemeClusters $::graphInput]
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
    "Reference" {
        colors  "Colors"          buildColors
        chars   "Characters"      buildChars
        graph   "Graphemes"       buildGraphemes
        fonts   "Fonts"           buildFonts
        bitmaps "Bitmaps"         buildBitmaps
    }
    "Conversion / time" {
        units   "Units"           buildUnits
        tz      "Timezones"       buildTz
        clock   "clock format"    buildClock
    }
    "Tk widgets / style" {
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
