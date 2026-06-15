# tkutils::tkumonthcanvas -- canvas calendar widget (month/quarter/year)
# OPTIONAL: requires tical (engine). Re-homed from the standalone
# 'monthcanvas' toolkit; same procedural API, tical-native, Tk 8.6+/9.x.
# 2025-12-29

package provide tkutils::tkumonthcanvas 0.5

package require Tk
package require tical::config 1.0
package require tical::locale 1.0
package require tical::holidays 1.0
package require tical::holidays::de 1.0
package require tical::view::month 1.0

namespace eval ::tkutils {}
namespace eval ::tkutils::tkumonthcanvas {
    # Theme-System (aehnlich ttk, aber fuer Canvas)
    variable themes
    variable currentTheme "default"
    
    # Callback-Handler
    variable onDayClick ""
    variable onWeekClick ""
    variable onMonthClick ""
    variable onSelect ""

    # Auswahl (Mehrtagesauswahl)
    variable selected {}
    variable selectMode none
    variable selAnchor ""

    # Redraw-Kontext (fuer Auswahl-Refresh)
    variable current ""
    variable currentW ""
    variable inComposite 0
    
    # Interne Variablen
    variable today
    variable notes
    variable itemsets
    
    # Geometrie
    variable cellW 30
    variable cellH 24
    variable leftW 22
    variable topH 40
    variable font "Arial 11"
    variable fontSmall "Arial 10"
}

# ============================================================
# THEME-SYSTEM
# ============================================================

proc tkutils::tkumonthcanvas::defineTheme {name spec} {
    variable themes
    dict set themes $name $spec
}

proc tkutils::tkumonthcanvas::setTheme {name} {
    variable themes
    variable currentTheme
    if {![dict exists $themes $name]} {
        error "Theme '$name' nicht definiert"
    }
    set currentTheme $name
}

proc tkutils::tkumonthcanvas::getThemeValue {key} {
    variable themes
    variable currentTheme
    if {[dict exists $themes $currentTheme $key]} {
        return [dict get $themes $currentTheme $key]
    }
    # Fallback auf default
    if {[dict exists $themes default $key]} {
        return [dict get $themes default $key]
    }
    return ""
}

# Standard-Themes definieren
tkutils::tkumonthcanvas::defineTheme default {
    bg              white
    fg              black
    
    dayBg           white
    dayFg           black
    dayOutline      "#e0e0e0"
    
    todayBg         "#90EE90"
    todayFg         "#006400"
    todayOutline    "#228B22"
    
    holidayBg       "#FFE4E1"
    holidayFg       "#8B0000"
    holidayOutline  "#CD5C5C"
    
    weekendBg       "#F0F8FF"
    weekendFg       "#4169E1"
    
    otherMonthBg    "#F5F5F5"
    otherMonthFg    "#A0A0A0"
    
    noteBg          "#FFFACD"
    noteFg          black
    noteMarker      "#FF6347"
    
    weeknrBg        "#F8F8F8"
    weeknrFg        "#606060"
    
    headerBg        "#E8E8E8"
    headerFg        "#333333"
    
    titleFg         "#1a1a1a"
    
    hoverOutline    "#4169E1"
    selectOutline   "#FF4500"
    
    font            "Arial 11"
    fontSmall       "Arial 10"
    fontTitle       "Arial 12 bold"
}

tkutils::tkumonthcanvas::defineTheme dark {
    bg              "#2d2d2d"
    fg              "#e0e0e0"
    
    dayBg           "#3d3d3d"
    dayFg           "#e0e0e0"
    dayOutline      "#505050"
    
    todayBg         "#2E8B57"
    todayFg         "#FFFFFF"
    todayOutline    "#3CB371"
    
    holidayBg       "#8B4513"
    holidayFg       "#FFE4C4"
    holidayOutline  "#CD853F"
    
    weekendBg       "#4a4a5a"
    weekendFg       "#87CEEB"
    
    otherMonthBg    "#353535"
    otherMonthFg    "#707070"
    
    noteBg          "#4a4a2a"
    noteFg          "#FFD700"
    noteMarker      "#FF6347"
    
    weeknrBg        "#383838"
    weeknrFg        "#909090"
    
    headerBg        "#404040"
    headerFg        "#c0c0c0"
    
    titleFg         "#ffffff"
    
    hoverOutline    "#6495ED"
    selectOutline   "#FF6347"
    
    font            "Arial 11"
    fontSmall       "Arial 10"
    fontTitle       "Arial 12 bold"
}

tkutils::tkumonthcanvas::defineTheme light {
    bg              "#fafafa"
    fg              "#333333"
    
    dayBg           "#ffffff"
    dayFg           "#333333"
    dayOutline      "#d0d0d0"
    
    todayBg         "#4CAF50"
    todayFg         "#ffffff"
    todayOutline    "#388E3C"
    
    holidayBg       "#FFCDD2"
    holidayFg       "#C62828"
    holidayOutline  "#EF9A9A"
    
    weekendBg       "#E3F2FD"
    weekendFg       "#1565C0"
    
    otherMonthBg    "#f0f0f0"
    otherMonthFg    "#b0b0b0"
    
    noteBg          "#FFF9C4"
    noteFg          "#F57F17"
    noteMarker      "#FF5722"
    
    weeknrBg        "#f5f5f5"
    weeknrFg        "#757575"
    
    headerBg        "#e0e0e0"
    headerFg        "#424242"
    
    titleFg         "#212121"
    
    hoverOutline    "#2196F3"
    selectOutline   "#FF5722"
    
    font            "Arial 11"
    fontSmall       "Arial 10"
    fontTitle       "Arial 12 bold"
}

# ============================================================
# INITIALISIERUNG
# ============================================================

proc tkutils::tkumonthcanvas::init {args} {
    array set opts {
        -fontsize 11
        -font Arial
        -locale de_DE
        -timezone :Europe/Berlin
        -theme default
        -onDayClick ""
        -onWeekClick ""
        -onMonthClick ""
    }
    array set opts $args
    
    # Locale setzen
    tical::config::set locale $opts(-locale)
    tical::config::set timezone [string trimleft $opts(-timezone) :]
    
    # Theme setzen
    variable currentTheme
    set currentTheme $opts(-theme)
    
    # Callbacks setzen
    variable onDayClick
    variable onWeekClick
    variable onMonthClick
    set onDayClick $opts(-onDayClick)
    set onWeekClick $opts(-onWeekClick)
    set onMonthClick $opts(-onMonthClick)
    
    # Heute merken
    variable today
    set today [clock format [clock seconds] -format "%Y-%m-%d"]
    
    # Notizen initialisieren
    variable notes
    if {![info exists notes]} {
        set notes [dict create]
    }
    
    # Geometrie berechnen
    setFontSize $opts(-fontsize) $opts(-font)
}

proc tkutils::tkumonthcanvas::setFontSize {size {family Arial}} {
    variable cellW
    variable cellH
    variable leftW
    variable topH
    variable font
    variable fontSmall
    
    set font "$family $size"
    set fontSmall "$family [expr {$size - 1}]"
    
    set cellW [expr {$size * 2.5}]
    set cellH [expr {$size * 2.0}]
    set leftW [expr {$cellW * 0.75}]
    set topH [expr {$cellH * 2.0}]
}

# ============================================================
# CALLBACKS
# ============================================================

proc tkutils::tkumonthcanvas::setCallback {type cmd} {
    variable onDayClick
    variable onWeekClick
    variable onMonthClick
    
    variable onSelect
    switch $type {
        day    { set onDayClick $cmd }
        week   { set onWeekClick $cmd }
        month  { set onMonthClick $cmd }
        select { set onSelect $cmd }
    }
}

proc tkutils::tkumonthcanvas::onDayClicked {w date {shift 0} {ctrl 0}} {
    variable onDayClick
    variable onSelect
    variable selectMode
    variable selected
    variable selAnchor
    if {$selectMode ne "none"} {
        if {$selectMode eq "single"} {
            set selected [dict create $date 1]
            set selAnchor $date
        } elseif {$shift && $selAnchor ne ""} {
            # Shift: Auswahl durch den Bereich ab dem Anker ersetzen
            set selected {}
            foreach d [dateRange $selAnchor $date] { dict set selected $d 1 }
        } elseif {$ctrl} {
            # Ctrl: einzelnen Tag dazu-/wegschalten
            if {[dict exists $selected $date]} {
                dict unset selected $date
            } else {
                dict set selected $date 1
            }
            set selAnchor $date
        } else {
            # Einfacher Klick: nur diesen Tag waehlen
            set selected [dict create $date 1]
            set selAnchor $date
        }
        redraw
        if {$onSelect ne ""} { uplevel #0 [list {*}$onSelect $w [getSelection]] }
    }
    if {$onDayClick ne ""} {
        uplevel #0 [list {*}$onDayClick $w $date]
    }
}

proc tkutils::tkumonthcanvas::onWeekClicked {w year weeknr} {
    variable onWeekClick
    if {$onWeekClick ne ""} {
        uplevel #0 [list {*}$onWeekClick $w $year $weeknr]
    }
}

proc tkutils::tkumonthcanvas::onMonthClicked {w year month} {
    variable onMonthClick
    if {$onMonthClick ne ""} {
        uplevel #0 [list {*}$onMonthClick $w $year $month]
    }
}

# ============================================================
# NOTIZEN
# ============================================================

proc tkutils::tkumonthcanvas::setNotes {notesDict} {
    variable notes
    set notes $notesDict
}

proc tkutils::tkumonthcanvas::addNote {date text} {
    variable notes
    dict set notes $date $text
}

proc tkutils::tkumonthcanvas::hasNote {date} {
    variable notes
    return [dict exists $notes $date]
}

# ============================================================
# ZEICHNEN: TAG-ZELLE
# ============================================================

proc tkutils::tkumonthcanvas::drawDayCell {w x y date daynum flags} {
    variable cellW
    variable cellH
    variable notes
    
    # Flags: isCurrent, isCurrentMonth, isHoliday, isWeekend
    set isCurrent [expr {"today" in $flags}]
    set isCurrentMonth [expr {"current" in $flags}]
    set isHoliday [expr {"holiday" in $flags}]
    set isWeekend [expr {"weekend" in $flags}]
    set hasNote [hasNote $date]
    
    # Farben basierend auf Status
    if {$isCurrent} {
        set bg [getThemeValue todayBg]
        set fg [getThemeValue todayFg]
        set outline [getThemeValue todayOutline]
    } elseif {$isHoliday} {
        set bg [getThemeValue holidayBg]
        set fg [getThemeValue holidayFg]
        set outline [getThemeValue holidayOutline]
    } elseif {$hasNote} {
        set bg [getThemeValue noteBg]
        set fg [getThemeValue noteFg]
        set outline [getThemeValue dayOutline]
    } elseif {!$isCurrentMonth} {
        set bg [getThemeValue otherMonthBg]
        set fg [getThemeValue otherMonthFg]
        set outline [getThemeValue dayOutline]
    } elseif {$isWeekend} {
        set bg [getThemeValue weekendBg]
        set fg [getThemeValue weekendFg]
        set outline [getThemeValue dayOutline]
    } else {
        set bg [getThemeValue dayBg]
        set fg [getThemeValue dayFg]
        set outline [getThemeValue dayOutline]
    }
    
    set tag "day-$date"
    set x2 [expr {$x + $cellW}]
    set y2 [expr {$y + $cellH}]

    # Auswahl-Hervorhebung (nutzt den bisher ungenutzten selectOutline)
    variable selected
    set selW 1
    if {[dict exists $selected $date]} {
        set outline [getThemeValue selectOutline]
        set selW 2
    }

    # Rechteck
    $w create rectangle $x $y $x2 $y2 \
        -fill $bg -outline $outline -width $selW -tags [list $tag daycell]
    
    # Text (Tagesnummer)
    set font [getThemeValue font]
    $w create text [expr {$x + $cellW/2}] [expr {$y + $cellH/2}] \
        -text $daynum -fill $fg -font $font -anchor center -tags [list $tag daycell]
    
    # Notiz-Marker
    if {$hasNote} {
        set mx [expr {$x + $cellW - 5}]
        set my [expr {$y + 5}]
        set markerColor [getThemeValue noteMarker]
        $w create oval [expr {$mx-3}] [expr {$my-3}] [expr {$mx+3}] [expr {$my+3}] \
            -fill $markerColor -outline "" -tags [list $tag notemarker]
    }
    
    # Bindings
    $w bind $tag <Button-1>         [list tkutils::tkumonthcanvas::onDayClicked $w $date 0 0]
    $w bind $tag <Shift-Button-1>   [list tkutils::tkumonthcanvas::onDayClicked $w $date 1 0]
    $w bind $tag <Control-Button-1> [list tkutils::tkumonthcanvas::onDayClicked $w $date 0 1]
    $w bind $tag <Enter> [list tkutils::tkumonthcanvas::highlightCell $w $tag]
    $w bind $tag <Leave> [list tkutils::tkumonthcanvas::unhighlightCell $w $tag $outline $selW]
    
    return $tag
}

proc tkutils::tkumonthcanvas::highlightCell {w tag} {
    set color [getThemeValue hoverOutline]
    foreach id [$w find withtag $tag] {
        if {[$w type $id] eq "rectangle"} {
            $w itemconfigure $id -outline $color -width 2
        }
    }
}

proc tkutils::tkumonthcanvas::unhighlightCell {w tag origOutline {origWidth 1}} {
    foreach id [$w find withtag $tag] {
        if {[$w type $id] eq "rectangle"} {
            $w itemconfigure $id -outline $origOutline -width $origWidth
        }
    }
}

# ============================================================
# ZEICHNEN: WOCHENNUMMER
# ============================================================

proc tkutils::tkumonthcanvas::drawWeekNumber {w x y year weeknr} {
    variable cellH
    variable leftW
    
    set bg [getThemeValue weeknrBg]
    set fg [getThemeValue weeknrFg]
    set font [getThemeValue fontSmall]
    
    set tag "weeknr-$year-$weeknr"
    set x2 [expr {$x + $leftW}]
    set y2 [expr {$y + $cellH}]
    
    # Rechteck
    $w create rectangle $x $y $x2 $y2 \
        -fill $bg -outline "" -tags [list $tag weeknrcell]
    
    # Text
    $w create text [expr {$x + $leftW/2}] [expr {$y + $cellH/2}] \
        -text [format "%02d" [scan $weeknr %d]] \
        -fill $fg -font $font -anchor center -tags [list $tag weeknrcell]
    
    # Binding fuer Wochen-Klick
    $w bind $tag <Button-1> [list tkutils::tkumonthcanvas::onWeekClicked $w $year $weeknr]
    $w bind $tag <Enter> [list $w configure -cursor hand2]
    $w bind $tag <Leave> [list $w configure -cursor ""]
    
    return $tag
}

# ============================================================
# ZEICHNEN: MONAT
# ============================================================

proc tkutils::tkumonthcanvas::drawMonth {w year month {x0 0} {y0 0}} {
    variable cellW
    variable cellH
    variable leftW
    variable topH
    variable today
    variable itemsets
    
    set year [scan $year %d]
    set month [scan $month %d]
    variable current; variable currentW; variable inComposite
    set currentW $w
    if {!$inComposite} {
        set current [list tkutils::tkumonthcanvas::drawMonth $w $year $month $x0 $y0]
    }
    
    # Feiertage laden
    set holidays [tkutils::tkumonthcanvas::_holidaysForYear $year]
    
    # Grid holen
    set grid [tkutils::tkumonthcanvas::_calendarGrid $year $month]
    
    # Monatstitel
    set monthName [tical::locale::getMonthName $month]
    set titleText "$monthName $year"
    set titleFont [getThemeValue fontTitle]
    set titleFg [getThemeValue titleFg]
    
    set titleX [expr {$x0 + $leftW + 3.5 * $cellW}]
    set titleY [expr {$y0 + $topH / 3}]
    set titleTag "title-$year-$month"
    
    $w create text $titleX $titleY -text $titleText \
        -font $titleFont -fill $titleFg -anchor center -tags [list $titleTag titlecell]
    
    # Monat-Klick auf Titel
    $w bind $titleTag <Button-1> [list tkutils::tkumonthcanvas::onMonthClicked $w $year $month]
    $w bind $titleTag <Enter> [list $w configure -cursor hand2]
    $w bind $titleTag <Leave> [list $w configure -cursor ""]
    
    # Wochentags-Header
    set weekdays [tical::locale::getWeekdaysShort]
    set headerBg [getThemeValue headerBg]
    set headerFg [getThemeValue headerFg]
    set fontSmall [getThemeValue fontSmall]
    
    for {set col 0} {$col < 7} {incr col} {
        set hx [expr {$x0 + $leftW + $col * $cellW}]
        set hy [expr {$y0 + $topH * 0.6}]
        
        $w create rectangle $hx $hy [expr {$hx + $cellW}] [expr {$hy + $cellH * 0.8}] \
            -fill $headerBg -outline "" -tags header
        
        $w create text [expr {$hx + $cellW/2}] [expr {$hy + $cellH * 0.4}] \
            -text [lindex $weekdays $col] \
            -fill $headerFg -font $fontSmall -anchor center -tags header
    }
    
    # KW-Header
    set kwX [expr {$x0 + $leftW/2}]
    set kwY [expr {$y0 + $topH * 0.6 + $cellH * 0.4}]
    $w create text $kwX $kwY -text "KW" \
        -fill $headerFg -font $fontSmall -anchor center -tags header
    
    # Tage zeichnen
    set row 0
    foreach week $grid {
        set col 0
        set weeknrDrawn 0
        
        foreach day $week {
            set date [dict get $day date]
            set daynum [dict get $day day]
            set weeknr [dict get $day weeknr]
            set weekday [dict get $day weekday]
            set isCurrent [dict get $day isCurrent]
            set isCurrentMonth [dict get $day isCurrentMonth]
            set isHoliday [dict exists $holidays $date]
            set isWeekend [expr {$weekday in {6 7}}]
            
            # Wochennummer (einmal pro Zeile)
            if {!$weeknrDrawn && $weeknr ne ""} {
                set wx $x0
                set wy [expr {$y0 + $topH + $row * $cellH}]
                drawWeekNumber $w $wx $wy $year $weeknr
                set weeknrDrawn 1
            }
            
            # Tag-Zelle
            set dx [expr {$x0 + $leftW + $col * $cellW}]
            set dy [expr {$y0 + $topH + $row * $cellH}]
            
            set flags {}
            if {$isCurrent} {lappend flags today}
            if {$isCurrentMonth} {lappend flags current}
            if {$isHoliday} {lappend flags holiday}
            if {$isWeekend} {lappend flags weekend}
            
            if {$date ne ""} {
                drawDayCell $w $dx $dy $date $daynum $flags
            }
            
            incr col
        }
        incr row
    }
    
    # Bounding-Box zurueckgeben
    set x1 [expr {$x0 + $leftW + 7 * $cellW}]
    set y1 [expr {$y0 + $topH + 6 * $cellH}]
    return [list $x0 $y0 $x1 $y1]
}

# ============================================================
# ZEICHNEN: QUARTAL (3 MONATE)
# ============================================================

proc tkutils::tkumonthcanvas::drawQuarter {w year month {x0 0} {y0 0}} {
    variable cellW
    variable cellH
    variable leftW
    variable topH
    
    set year [scan $year %d]
    set month [scan $month %d]
    variable current; variable currentW; variable inComposite
    set currentW $w
    set current [list tkutils::tkumonthcanvas::drawQuarter $w $year $month $x0 $y0]
    set inComposite 1
    
    # Breite eines Monats
    set monthWidth [expr {$leftW + 7 * $cellW + 10}]
    
    set boxes {}
    for {set i 0} {$i < 3} {incr i} {
        set m [expr {$month + $i}]
        set y $year
        
        # Jahreswechsel beruecksichtigen
        while {$m > 12} {
            incr m -12
            incr y
        }
        
        set mx [expr {$x0 + $i * $monthWidth}]
        lappend boxes [drawMonth $w $y $m $mx $y0]
    }
    
    set inComposite 0
    # Gesamt-Bounding-Box
    set x1 [expr {$x0 + 3 * $monthWidth}]
    set y1 [expr {$y0 + $topH + 6 * $cellH}]
    return [list $x0 $y0 $x1 $y1]
}

# ============================================================
# ZEICHNEN: JAHR (12 MONATE)
# ============================================================

proc tkutils::tkumonthcanvas::drawYear {w year {x0 0} {y0 0} {cols 4}} {
    variable cellW
    variable cellH
    variable leftW
    variable topH
    
    set year [scan $year %d]
    variable current; variable currentW; variable inComposite
    set currentW $w
    set current [list tkutils::tkumonthcanvas::drawYear $w $year $x0 $y0 $cols]
    set inComposite 1
    
    # Breite/Hoehe eines Monats
    set monthWidth [expr {$leftW + 7 * $cellW + 15}]
    set monthHeight [expr {$topH + 6 * $cellH + 15}]
    
    set rows [expr {12 / $cols}]
    
    for {set m 1} {$m <= 12} {incr m} {
        set col [expr {($m - 1) % $cols}]
        set row [expr {($m - 1) / $cols}]
        
        set mx [expr {$x0 + $col * $monthWidth}]
        set my [expr {$y0 + $row * $monthHeight}]
        
        drawMonth $w $year $m $mx $my
    }
    
    set inComposite 0
    # Gesamt-Bounding-Box
    set x1 [expr {$x0 + $cols * $monthWidth}]
    set y1 [expr {$y0 + $rows * $monthHeight}]
    return [list $x0 $y0 $x1 $y1]
}

# ============================================================
# HILFSFUNKTIONEN
# ============================================================

proc tkutils::tkumonthcanvas::clear {w} {
    $w delete all
}

proc tkutils::tkumonthcanvas::getMonthSize {} {
    variable cellW
    variable cellH
    variable leftW
    variable topH
    
    set width [expr {$leftW + 7 * $cellW}]
    set height [expr {$topH + 6 * $cellH}]
    return [list $width $height]
}

proc tkutils::tkumonthcanvas::getQuarterSize {} {
    lassign [getMonthSize] mw mh
    set width [expr {3 * $mw + 20}]
    return [list $width $mh]
}

proc tkutils::tkumonthcanvas::getYearSize {{cols 4}} {
    lassign [getMonthSize] mw mh
    set rows [expr {12 / $cols}]
    set width [expr {$cols * ($mw + 15)}]
    set height [expr {$rows * ($mh + 15)}]
    return [list $width $height]
}

# ============================================================
# WOCHEN-DATEN HOLEN
# ============================================================

proc tkutils::tkumonthcanvas::getWeekDates {year weeknr} {
    # Alle Tage einer ISO-Woche zurueckgeben
    set weeknr [scan $weeknr %d]
    
    # Ersten Montag der Woche finden
    # ISO-Woche 1 enthaelt den 4. Januar
    set jan4 [clock scan "$year-01-04" -format "%Y-%m-%d"]
    set dow [clock format $jan4 -format %u]
    set monday1 [clock add $jan4 [expr {1 - $dow}] days]
    
    # Zum gewuenschten Montag springen
    set targetMonday [clock add $monday1 [expr {($weeknr - 1) * 7}] days]
    
    set dates {}
    for {set i 0} {$i < 7} {incr i} {
        set d [clock add $targetMonday $i days]
        lappend dates [clock format $d -format "%Y-%m-%d"]
    }
    return $dates
}

proc tkutils::tkumonthcanvas::getMonthDates {year month} {
    set year [scan $year %d]
    set month [scan $month %d]
    
    set days [tkutils::tkumonthcanvas::_daysInMonth $year $month]
    set dates {}
    for {set d 1} {$d <= $days} {incr d} {
        lappend dates [format "%04d-%02d-%02d" $year $month $d]
    }
    return $dates
}

# ============================================================
# AUSWAHL (Mehrtagesauswahl)  --  selectmode none|single|multiple
# ============================================================

proc tkutils::tkumonthcanvas::dateRange {a b} {
    set ta [clock scan "$a 12:00:00" -format "%Y-%m-%d %H:%M:%S"]
    set tb [clock scan "$b 12:00:00" -format "%Y-%m-%d %H:%M:%S"]
    if {$tb < $ta} { set t $ta; set ta $tb; set tb $t }
    set out {}
    for {set t $ta} {$t <= $tb} {set t [clock add $t 1 day]} {
        lappend out [clock format $t -format "%Y-%m-%d"]
    }
    return $out
}

proc tkutils::tkumonthcanvas::expandSelection {spec} {
    set out {}
    foreach tok $spec {
        if {[regexp {^(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})$} $tok -> x y]} {
            foreach d [dateRange $x $y] { dict set out $d 1 }
        } elseif {[regexp {^\d{4}-\d{2}-\d{2}$} $tok]} {
            dict set out $tok 1
        } else {
            return -code error -errorcode {TKUTILS TKMONTHCANVAS SELECT} \
                "invalid selection entry: $tok"
        }
    }
    return [lsort [dict keys $out]]
}

proc tkutils::tkumonthcanvas::redraw {} {
    variable current
    variable currentW
    if {$current eq "" || $currentW eq ""} return
    clear $currentW
    uplevel #0 $current
}

proc tkutils::tkumonthcanvas::setSelectMode {mode} {
    variable selectMode
    variable selected
    if {$mode ni {none single multiple}} {
        return -code error -errorcode {TKUTILS TKMONTHCANVAS SELECTMODE} \
            "selectmode must be none|single|multiple"
    }
    set selectMode $mode
    if {$mode eq "none"} { set selected {}; redraw }
    return $mode
}

proc tkutils::tkumonthcanvas::getSelection {} {
    variable selected
    return [lsort [dict keys $selected]]
}

# Accepts ISO dates and YYYY-MM-DD..YYYY-MM-DD ranges.
proc tkutils::tkumonthcanvas::setSelection {dates} {
    variable selected
    set selected {}
    foreach d [expandSelection $dates] { dict set selected $d 1 }
    redraw
    return [getSelection]
}

proc tkutils::tkumonthcanvas::clearSelection {{refresh 1}} {
    variable selected
    set selected {}
    if {$refresh} { redraw }
}

# ============================================================
# TICAL-NATIVE ENGINE HELPERS (replace former gel::calendar calls)
# ============================================================

proc tkutils::tkumonthcanvas::_daysInMonth {year month} {
    set tz [tical::config::get timezone]
    set first [clock scan [format "%04d-%02d-01 12:00:00" $year $month] -timezone $tz]
    set last  [clock add [clock add $first 1 month -timezone $tz] -1 day -timezone $tz]
    return [scan [clock format $last -format %d -timezone $tz] %d]
}

proc tkutils::tkumonthcanvas::_holidaysForYear {year} {
    set cc [string toupper [lindex [split [tical::config::get locale] _-] end]]
    if {![info exists ::tical::holidays::plugins($cc)]} { return {} }
    return [{*}$::tical::holidays::plugins($cc) $year]
}

# date->day-dict grid (6 weeks x 7), gel-compatible field names, via tical.
proc tkutils::tkumonthcanvas::_calendarGrid {year month} {
    set tz    [tical::config::get timezone]
    set today [clock format [clock seconds] -format %Y-%m-%d -timezone $tz]
    set spec  [tical::view::month::getData -year $year -month $month -showAdjacentDays 1]
    set cells [dict get $spec cells]
    set grid {}; set week {}
    foreach cell $cells {
        set date [dict get $cell date]
        if {$date eq ""} {
            lappend week [dict create date "" day "" weeknr "" weekday "" \
                              isCurrent 0 isCurrentMonth 0]
        } else {
            set ts  [clock scan "$date 12:00:00" -timezone $tz]
            set day [scan [lindex [split $date -] 2] %d]
            lappend week [dict create \
                date           $date \
                day            $day \
                weeknr         [scan [clock format $ts -format %V -timezone $tz] %d] \
                weekday        [clock format $ts -format %u -timezone $tz] \
                isCurrent      [expr {$date eq $today ? 1 : 0}] \
                isCurrentMonth [dict get $cell inMonth]]
        }
        if {[llength $week] == 7} { lappend grid $week; set week {} }
    }
    if {[llength $week]} { lappend grid $week }
    return $grid
}
