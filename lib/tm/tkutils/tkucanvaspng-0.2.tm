# tkutils::tkucanvaspng -- export a live Tk canvas widget to a PNG image, after
# the model of pdf4tcl's "$pdf canvas": walk the canvas items and translate each
# to drawing calls on a tclutils::tupngdraw image. Unlike the tclutils PNG
# modules this one REQUIRES Tk (it queries a real, rendered canvas widget); the
# actual rasterising is done by the Tk-free tupngdraw engine.
#
#   package require tkutils::tkucanvaspng
#   tkutils::tkucanvaspng::write out.png .c                 ;# whole canvas
#   tkutils::tkucanvaspng::write out.png .c -scale 2 -region [.c bbox all]
#
# Supported items: line (multi-point), rectangle, oval, polygon, arc, text.
# Not supported (skipped): image, bitmap, window, -stipple, -dash, -arrow,
# -smooth, gradients. Colours are resolved through the widget (winfo rgb), so
# any Tk colour name works. Plain tk::canvas text uses the bitmap font (ASCII);
# pass -textcmd to render real glyphs from a font (see tumonthpng's -textcmd).
# Elliptical arcs are approximated by a mean radius. The canvas must be realised
# and rendered (call `update idletasks` first), exactly as for pdf4tcl.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tupngdraw 0.12

namespace eval ::tkutils {}
namespace eval ::tkutils::tkucanvaspng {
    namespace export render write
    variable version 0.2
}

# top-left offset of a text box of size (w,h) for a given canvas anchor
proc ::tkutils::tkucanvaspng::_anchorOffset {anchor w h} {
    switch -- $anchor {
        nw     { return [list 0            0          ] }
        n      { return [list [expr {-$w/2}] 0         ] }
        ne     { return [list [expr {-$w}]   0         ] }
        w      { return [list 0            [expr {-$h/2}]] }
        e      { return [list [expr {-$w}]   [expr {-$h/2}]] }
        sw     { return [list 0            [expr {-$h}]] }
        s      { return [list [expr {-$w/2}] [expr {-$h}]] }
        se     { return [list [expr {-$w}]   [expr {-$h}]] }
        default { return [list [expr {-$w/2}] [expr {-$h/2}]] }
    }
}


proc ::tkutils::tkucanvaspng::_unit {dx dy} {
    set L [expr {hypot($dx, $dy)}]
    if {$L == 0} { return {0 0 0} }
    return [list [expr {$dx / $L}] [expr {$dy / $L}] $L]
}

# Fill a canvas-style arrowhead whose tip is (tx,ty), pointing away from
# (fx,fy). shape = {a b c}. Returns the notch point (new line endpoint).
proc ::tkutils::tkucanvaspng::_arrowhead {img tx ty fx fy shape color} {
    lassign $shape a b c
    lassign [_unit [expr {$tx - $fx}] [expr {$ty - $fy}]] ux uy L
    if {$L == 0} { return [list $tx $ty] }
    set px [expr {-$uy}]; set py [expr {$ux}]
    set bcx [expr {$tx - $ux * $b}]; set bcy [expr {$ty - $uy * $b}]
    set nx  [expr {$tx - $ux * $a}]; set ny  [expr {$ty - $uy * $a}]
    set p1x [expr {$bcx + $px * $c}]; set p1y [expr {$bcy + $py * $c}]
    set p2x [expr {$bcx - $px * $c}]; set p2y [expr {$bcy - $py * $c}]
    $img polygon [list $tx $ty $p1x $p1y $nx $ny $p2x $p2y] \
        -fill 1 -fillcolor $color -outline 0
    return [list $nx $ny]
}

# Draw a polyline, solid or dashed. pattern = list of px run-lengths (on,off,..)
# or "" for solid.
proc ::tkutils::tkucanvaspng::_dashedPath {img pts pattern color width} {
    set np [llength $pts]
    if {$pattern eq ""} {
        for {set i 0} {$i + 3 < $np} {incr i 2} {
            lassign [lrange $pts $i [expr {$i + 3}]] x1 y1 x2 y2
            $img line $x1 $y1 $x2 $y2 -color $color -width $width -caps round
        }
        return
    }
    set plen [llength $pattern]
    set ci 0
    set rem [lindex $pattern 0]
    set on 1
    for {set i 0} {$i + 3 < $np} {incr i 2} {
        lassign [lrange $pts $i [expr {$i + 3}]] x1 y1 x2 y2
        lassign [_unit [expr {$x2 - $x1}] [expr {$y2 - $y1}]] ux uy seglen
        set pos 0.0
        while {$pos < $seglen} {
            set step [expr {min($rem, $seglen - $pos)}]
            if {$on} {
                set ax [expr {$x1 + $ux * $pos}];          set ay [expr {$y1 + $uy * $pos}]
                set bx [expr {$x1 + $ux * ($pos + $step)}]; set by [expr {$y1 + $uy * ($pos + $step)}]
                $img line $ax $ay $bx $by -color $color -width $width -caps butt
            }
            set pos [expr {$pos + $step}]
            set rem [expr {$rem - $step}]
            if {$rem <= 1e-6} {
                set ci [expr {($ci + 1) % $plen}]
                set rem [lindex $pattern $ci]
                set on [expr {!$on}]
            }
        }
    }
}

# --- Tk-FREE mapper -----------------------------------------------------------
# Draw one canvas item on a tupngdraw image. All coordinates are already in
# pixel space; colours are hex (#rrggbb) or "" (none). opts dict keys:
#   fill outline width                (all items)
#   start extent style                (arc; style = arc|pie|chord)
#   text anchor scale                 (text)
proc ::tkutils::tkucanvaspng::_drawItem {img type coords opts} {
    set opts [dict merge {fill {} outline {} width 1 \
        start 0 extent 90 style pie text {} anchor center scale 1 \
        arrow none arrowshape {8 10 3} dash {}} $opts]
    set fill    [dict get $opts fill]
    set outline [dict get $opts outline]
    set width   [dict get $opts width]
    if {$width < 1} { set width 1 }
    $img setlinewidth $width

    switch -- $type {
        line {
            if {$fill eq ""} return
            set pts   $coords
            set arrow [dict get $opts arrow]
            set shape [dict get $opts arrowshape]
            set dash  [dict get $opts dash]
            if {$arrow in {last both} && [llength $pts] >= 4} {
                lassign [lrange $pts end-3 end] fx fy tx ty
                lassign [_arrowhead $img $tx $ty $fx $fy $shape $fill] nx ny
                set pts [lreplace $pts end-1 end $nx $ny]
            }
            if {$arrow in {first both} && [llength $pts] >= 4} {
                lassign [lrange $pts 0 3] tx ty fx fy
                lassign [_arrowhead $img $tx $ty $fx $fy $shape $fill] nx ny
                set pts [lreplace $pts 0 1 $nx $ny]
            }
            _dashedPath $img $pts $dash $fill $width
        }
        rectangle {
            lassign $coords x1 y1 x2 y2
            set a [list $x1 $y1 $x2 $y2 \
                -fill [expr {$fill ne ""}] -outline [expr {$outline ne ""}]]
            if {$fill ne ""}    { lappend a -fillcolor $fill }
            if {$outline ne ""} { lappend a -color $outline }
            $img rect {*}$a
        }
        oval {
            lassign $coords x1 y1 x2 y2
            set cx [expr {($x1 + $x2) / 2.0}]
            set cy [expr {($y1 + $y2) / 2.0}]
            set rx [expr {abs($x2 - $x1) / 2.0}]
            set ry [expr {abs($y2 - $y1) / 2.0}]
            set a [list $cx $cy $rx $ry \
                -fill [expr {$fill ne ""}] -outline [expr {$outline ne ""}]]
            if {$fill ne ""}    { lappend a -fillcolor $fill }
            if {$outline ne ""} { lappend a -color $outline }
            $img ellipse {*}$a
        }
        polygon {
            set a [list $coords \
                -fill [expr {$fill ne ""}] -outline [expr {$outline ne ""}]]
            if {$fill ne ""}    { lappend a -fillcolor $fill }
            if {$outline ne ""} { lappend a -color $outline }
            $img polygon {*}$a
        }
        arc {
            lassign $coords x1 y1 x2 y2
            set cx [expr {($x1 + $x2) / 2.0}]
            set cy [expr {($y1 + $y2) / 2.0}]
            set rx [expr {abs($x2 - $x1) / 2.0}]
            set ry [expr {abs($y2 - $y1) / 2.0}]
            set a0 [dict get $opts start]
            set ext [dict get $opts extent]
            set style [dict get $opts style]
            set steps [expr {max(8, int(abs($ext) / 3.0))}]
            set deg2rad [expr {acos(-1) / 180.0}]
            set pts {}
            for {set i 0} {$i <= $steps} {incr i} {
                set th [expr {($a0 + $ext * $i / double($steps)) * $deg2rad}]
                lappend pts [expr {$cx + $rx * cos($th)}] [expr {$cy - $ry * sin($th)}]
            }
            if {$style eq "arc"} {
                if {$outline ne ""} { _dashedPath $img $pts {} $outline $width }
            } else {
                set poly [expr {$style eq "pie" ? [concat [list $cx $cy] $pts] : $pts}]
                set a [list $poly -fill [expr {$fill ne ""}] -outline [expr {$outline ne ""}]]
                if {$fill ne ""}    { lappend a -fillcolor $fill }
                if {$outline ne ""} { lappend a -color $outline }
                $img polygon {*}$a
            }
        }
        text {
            if {$fill eq ""} { set fill "#000000" }
            set scale [dict get $opts scale]
            lassign $coords x y
            set txt [dict get $opts text]
            set tw [expr {[string length $txt] * 6 * $scale}]
            set th [expr {8 * $scale}]
            lassign [_anchorOffset [dict get $opts anchor] $tw $th] ox oy
            $img text [expr {int($x + $ox)}] [expr {int($y + $oy)}] \
                $txt -color $fill -scale $scale
        }
    }
    return
}

# --- Tk layer -----------------------------------------------------------------
proc ::tkutils::tkucanvaspng::_hex {w color} {
    if {$color eq ""} { return "" }
    lassign [winfo rgb $w $color] r g b
    return [format #%02x%02x%02x [expr {$r / 256}] [expr {$g / 256}] [expr {$b / 256}]]
}

# normalise a Tk -dash value to a list of pixel run-lengths (scaled), or "".
proc ::tkutils::tkucanvaspng::_dashpx {dash scale} {
    if {$dash eq ""} { return "" }
    if {[string is list $dash] && [llength $dash] >= 1 &&         [string is integer -strict [lindex $dash 0]]} {
        return [lmap v $dash {expr {max(1, int($v * $scale))}}]
    }
    # character forms: . , - _
    set map {. {2 4} , {4 4} - {6 4} _ {8 4}}
    set pat {6 4}
    set k [string index [string trim $dash] 0]
    if {[dict exists $map $k]} { set pat [dict get $map $k] }
    return [lmap v $pat {expr {max(1, int($v * $scale))}}]
}

# Render real-font text via Glyphs outlines + fillcontours, matching the Tk
# font metrics. tx,ty is the (scaled) anchor point. Requires a Glyphs font obj.
proc ::tkutils::tkucanvaspng::_glyphText {img canvas scale tx ty anchor text colorhex font fontobj} {
    set asc  [expr {[font metrics $font -ascent]  * $scale}]
    set desc [expr {[font metrics $font -descent] * $scale}]
    set h [expr {$asc + $desc}]
    set w [expr {[font measure $font $text] * $scale}]
    lassign [_anchorOffset $anchor [expr {int($w)}] [expr {int($h)}]] ox oy
    set bx [expr {$tx + $ox}]
    set baseline [expr {$ty + $oy + $asc}]
    set upm [$fontobj get unitsPerEm]
    set sc  [expr {$h / double($upm)}]
    set penx $bx
    foreach ch [split $text ""] {
        set gi [$fontobj unicode2glyphIndex $ch]
        set aw [$fontobj gget $gi advanceWidth]
        if {$gi != 0} {
            set contours {}
            set g [$fontobj glyph $gi]
            foreach c [$g onUniformSteps 5 "at"] {
                set flat {}
                foreach pt $c {
                    lassign $pt fx fy
                    lappend flat [expr {$penx + $fx * $sc}] [expr {$baseline - $fy * $sc}]
                }
                if {[llength $flat] >= 6} { lappend contours $flat }
            }
            if {[llength $contours]} { $img fillcontours $contours -color $colorhex -rule nonzero }
            $g destroy
        }
        set penx [expr {$penx + $aw * $sc}]
    }
}

# resolve a Tk font to a TTF path via the fontmap (family match, then "*")
proc ::tkutils::tkucanvaspng::_resolveTtf {fontmap font} {
    if {$font eq ""} { set font TkDefaultFont }
    set fam ""
    catch {set fam [string tolower [font actual $font -family]]}
    foreach {k v} $fontmap {
        if {$k eq "*"} continue
        if {[string tolower $k] eq $fam} { return $v }
    }
    if {[dict exists $fontmap *]} { return [dict get $fontmap *] }
    return ""
}

# read a Tk photo image into a packed-RGBA byte string (opaque)
proc ::tkutils::tkucanvaspng::_photoRGBA {photo} {
    set w [image width $photo]
    set h [image height $photo]
    set bytes {}
    foreach row [$photo data] {
        foreach c $row {
            if {[scan $c "#%2x%2x%2x" r g b] == 3} {
                lappend bytes $r $g $b 255
            } else {
                lappend bytes 0 0 0 0
            }
        }
    }
    return [list [binary format cu* $bytes] $w $h]
}

proc ::tkutils::tkucanvaspng::render {canvas args} {
    package require Tk
    if {![winfo exists $canvas]} {
        return -code error -errorcode {TKUTILS TKCANVASPNG WINDOW} \
            "not a canvas window: $canvas"
    }
    set o [::tclutils::common::parseOptions {
        -region {} -scale 1 -background {} -textcmd {} -fontmap {}
    } {*}$args]
    set scale [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]

    set region [dict get $o -region]
    if {[llength $region] != 4} { set region [$canvas bbox all] }
    if {[llength $region] != 4} {
        return -code error -errorcode {TKUTILS TKCANVASPNG EMPTY} "canvas is empty"
    }
    lassign $region rx1 ry1 rx2 ry2

    set bg [dict get $o -background]
    if {$bg eq ""} { catch {set bg [$canvas cget -background]} }
    if {$bg eq ""} { set bg white }
    set bg [_hex $canvas $bg]

    set W [expr {int(ceil(($rx2 - $rx1) * $scale))}]
    set H [expr {int(ceil(($ry2 - $ry1) * $scale))}]
    if {$W < 1} { set W 1 }
    if {$H < 1} { set H 1 }
    set img [::tclutils::tupngdraw::new -width $W -height $H -background $bg]
    set tcmd [dict get $o -textcmd]
    set fontmap [dict get $o -fontmap]
    set fcache {}
    if {$fontmap ne ""} { package require Glyphs }

    foreach id [$canvas find all] {
        set type [$canvas type $id]
        if {$type in {bitmap window}} { continue }
        set raw [$canvas coords $id]
        if {[llength $raw] == 0} { continue }
        set pc {}
        foreach {x y} $raw {
            lappend pc [expr {($x - $rx1) * $scale}] [expr {($y - $ry1) * $scale}]
        }
        set fill ""; set outline ""; set width 1
        catch {set width [$canvas itemcget $id -width]}
        set width [expr {max(1, int(round($width * $scale)))}]

        set d [dict create width $width fill "" outline ""]
        switch -- $type {
            line {
                catch {set fill [$canvas itemcget $id -fill]}
                dict set d fill [_hex $canvas $fill]
                set arrow none
                catch {set arrow [$canvas itemcget $id -arrow]}
                dict set d arrow $arrow
                set shape {8 10 3}
                catch {set shape [$canvas itemcget $id -arrowshape]}
                dict set d arrowshape [lmap v $shape {expr {$v * $scale}}]
                set dash {}
                catch {set dash [$canvas itemcget $id -dash]}
                dict set d dash [_dashpx $dash $scale]
            }
            rectangle - oval - polygon {
                catch {set fill    [$canvas itemcget $id -fill]}
                catch {set outline [$canvas itemcget $id -outline]}
                dict set d fill    [_hex $canvas $fill]
                dict set d outline [_hex $canvas $outline]
            }
            arc {
                catch {set fill    [$canvas itemcget $id -fill]}
                catch {set outline [$canvas itemcget $id -outline]}
                dict set d fill    [_hex $canvas $fill]
                dict set d outline [_hex $canvas $outline]
                dict set d start  [$canvas itemcget $id -start]
                dict set d extent [$canvas itemcget $id -extent]
                set st [$canvas itemcget $id -style]
                dict set d style [expr {$st eq "pieslice" ? "pie" : $st}]
            }
            text {
                catch {set fill [$canvas itemcget $id -fill]}
                dict set d fill [_hex $canvas $fill]
                dict set d text   [$canvas itemcget $id -text]
                dict set d anchor [$canvas itemcget $id -anchor]
                set gs 1
                catch {
                    set f [$canvas itemcget $id -font]
                    set ls [font metrics $f -linespace]
                    set gs [expr {max(1, int(round($ls * $scale / 10.0)))}]
                }
                dict set d scale $gs
                # real-font via fontmap (Glyphs) -- highest priority
                if {$fontmap ne ""} {
                    set fnt [$canvas itemcget $id -font]
                    set ttf [_resolveTtf $fontmap $fnt]
                    if {$ttf ne "" && [file exists $ttf]} {
                        if {![dict exists $fcache $ttf]} {
                            dict set fcache $ttf [Glyphs::new $ttf]
                        }
                        lassign $pc tx ty
                        _glyphText $img $canvas $scale $tx $ty [dict get $d anchor]                             [dict get $d text] [dict get $d fill]                             [expr {$fnt eq "" ? "TkDefaultFont" : $fnt}] [dict get $fcache $ttf]
                        continue
                    }
                }
                # real-font delegation for the whole text, if requested
                if {$tcmd ne ""} {
                    lassign $pc tx ty
                    set tw [expr {[string length [dict get $d text]] * 6 * $gs}]
                    set th [expr {8 * $gs}]
                    lassign [_anchorOffset [dict get $d anchor] $tw $th] ox oy
                    {*}$tcmd $img [expr {int($tx+$ox)}] [expr {int($ty+$oy)}] \
                        $tw $th [dict get $d text] [dict get $d fill]
                    continue
                }
            }
            image {
                set photo ""
                catch {set photo [$canvas itemcget $id -image]}
                if {$photo eq "" || [catch {image type $photo} t] || $t ne "photo"} { continue }
                lassign [_photoRGBA $photo] packed iw ih
                set anchor center
                catch {set anchor [$canvas itemcget $id -anchor]}
                lassign $pc cxp cyp
                lassign [_anchorOffset $anchor [expr {$iw * $scale}] [expr {$ih * $scale}]] ox oy
                $img paste [expr {$cxp + $ox}] [expr {$cyp + $oy}] $packed $iw $ih -scale $scale
                continue
            }
            default { continue }
        }
        _drawItem $img $type $pc $d
    }

    set png [$img data]
    $img destroy
    dict for {k obj} $fcache { catch {$obj destroy} }
    return $png
}

proc ::tkutils::tkucanvaspng::write {file canvas args} {
    set png [render $canvas {*}$args]
    set fid [open $file w]
    fconfigure $fid -translation binary
    puts -nonewline $fid $png
    close $fid
    return $file
}

package provide tkutils::tkucanvaspng 0.2
