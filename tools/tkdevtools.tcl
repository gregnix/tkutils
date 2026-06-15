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

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _root [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain \
            [file join [file dirname $_root] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c; break
    }
}

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
    foreach p $::tcl_pkgPath { lappend dirs [file join $p tzdata] }
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
    set left [frame $f.left]
    label $left.l -text "Themes / elements:"
    ttk::treeview $left.tv -show tree -height 20 \
        -yscrollcommand [list $left.sb set]
    ttk::scrollbar $left.sb -orient vertical -command [list $left.tv yview]
    grid $left.l  -row 0 -column 0 -columnspan 2 -sticky w
    grid $left.tv -row 1 -column 0 -sticky nsew
    grid $left.sb -row 1 -column 1 -sticky ns
    grid rowconfigure $left 1 -weight 1
    pack $left -side left -fill y -padx 4 -pady 4
    set ::themeTree $left.tv

    set r [labelframe $f.prev -text "Preview (selected theme applies app-wide)"]
    ttk::button      $r.b  -text "ttk::button"
    ttk::checkbutton $r.c  -text "ttk::checkbutton"
    ttk::radiobutton $r.r  -text "ttk::radiobutton" -variable ::themeRb -value 1
    ttk::entry       $r.e
    ttk::combobox    $r.cb -values {one two three} -state readonly
    ttk::progressbar $r.p  -value 60
    ttk::scale       $r.s  -from 0 -to 100 -value 40
    foreach w {b c r e cb p s} { pack $r.$w -anchor w -padx 8 -pady 5 -fill x }
    $r.e insert 0 "ttk::entry"
    pack $r -side left -fill both -expand 1 -padx 4 -pady 4

    themeReload
    bind $left.tv <<TreeviewSelect>> [list apply {{tv} {
        set id [lindex [$tv selection] 0]
        if {$id ne "" && [$tv parent $id] eq ""} {
            catch {ttk::style theme use [$tv item $id -text]}
            themeReload
        }
    }} $left.tv]
}
proc themeReload {} {
    set tv $::themeTree
    if {![winfo exists $tv]} return
    $tv delete [$tv children {}]
    set cur [ttk::style theme use]
    foreach th [lsort [ttk::style theme names]] {
        set tag [expr {$th eq $cur ? " (active)" : ""}]
        set node [$tv insert {} end -text "$th$tag" -open [expr {$th eq $cur}]]
        if {$th eq $cur} {
            foreach el [lsort [ttk::style element names]] {
                $tv insert $node end -text $el
            }
        }
    }
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

# ============================ assemble ======================================
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

proc navSelect {} {
    set id [lindex [.pw.nav.tv selection] 0]
    if {[info exists ::navFrame($id)]} { raise $::navFrame($id) }
}

# category -> {key title buildProc ...}
set ::toolTree {
    "Reference" {
        colors  "Colors"          buildColors
        chars   "Characters"      buildChars
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
    }
    "Text / patterns" {
        regexp  "regexp"          buildRegexp
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

set mode [lindex $argv 0]
if {$mode eq "--shot"} {
    set key [lindex $argv 2]
    if {$key ne "" && [info exists ::navNode($key)]} {
        .pw.nav.tv selection set $::navNode($key); navSelect
    }
    wm geometry . 900x600
    update idletasks; update; after 500; update
    catch {exec import -window root [lindex $argv 1]}
    exit 0
}
