# tkutils::tkuicon -- SVG icon loader / generator for toolbars (from uitoolkit)
# Description: SVG icon loader / generator for toolbars (from uitoolkit)
# Category: Tk · widgets
#
# Loads .svg/.png icons as Tk photo images and generates the built-in icon set
# on the fly from tclutils::tusvg. SVG needs tksvg (Tk 8.6) or native SVG
# (Tk 9.0+); without it the file loader still handles PNG/GIF and `create`
# reports {TKUTILS TKUICON NOSVG}. Results are cached. OPTIONAL module -- not
# loaded by the tkutils umbrella. Tcl/Tk 8.6+ / 9.x.
#
# Error codes: {TKUTILS TKUICON <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuicon {
    namespace export load create rescale available hassvg clearCache loadToolbarSet
    
    variable version 0.1
    variable cache
    array set cache {}
    
    variable hasTksvg 0
    variable hasNativeSvg 0
}

# ============================================================
# Initialisierung - SVG-Support pruefen
# ============================================================

proc ::tkutils::tkuicon::_init {} {
    variable hasTksvg
    variable hasNativeSvg
    
    # Tk 9.0+ has built-in SVG (TIP 507); 8.7 was never released as stable
    if {[package vsatisfies [package require Tk] 9-]} {
        set hasNativeSvg 1
        return
    }
    
    # Tk 8.6: tksvg Package versuchen
    if {![catch {package require tksvg}]} {
        set hasTksvg 1
    }
}

# Bei Package-Load initialisieren
::tkutils::tkuicon::_init

# ============================================================
# hassvg - SVG-Support pruefen
# ============================================================

proc ::tkutils::tkuicon::hassvg {} {
    variable hasTksvg
    variable hasNativeSvg
    return [expr {$hasTksvg || $hasNativeSvg}]
}

# ============================================================
# load - Icon aus Datei laden
# ============================================================
# Optionen:
#   -height  Zielhoehe in Pixel (optional)
#   -width   Zielbreite in Pixel (optional)
#   -name    Image-Name (optional, sonst automatisch)
#
proc ::tkutils::tkuicon::load {filename args} {
    variable cache
    variable hasTksvg
    variable hasNativeSvg
    
    array set opts {
        -height ""
        -width  ""
        -name   ""
    }
    array set opts $args
    
    # Cache-Key
    set cacheKey "$filename|$opts(-height)|$opts(-width)"
    if {[info exists cache($cacheKey)]} {
        return $cache($cacheKey)
    }
    
    # Image-Name
    if {$opts(-name) eq ""} {
        set opts(-name) "uiicon_[clock clicks]"
    }
    
    # Dateiendung pruefen
    set ext [string tolower [file extension $filename]]
    
    if {$ext eq ".svg"} {
        # SVG laden
        if {!$hasTksvg && !$hasNativeSvg} {
            return -code error -errorcode {TKUTILS TKUICON NOSVG} "no SVG support: install tksvg for Tk 8.6, or use Tk 9.0+"
        }
        
        # Format-String bauen
        set fmt "svg"
        if {$opts(-height) ne ""} {
            append fmt " -scaletoheight $opts(-height)"
        } elseif {$opts(-width) ne ""} {
            append fmt " -scaletowidth $opts(-width)"
        }
        
        set img [image create photo $opts(-name) -file $filename -format $fmt]
        
    } elseif {$ext in {.png .gif .ppm .pgm}} {
        # PNG/GIF direkt laden
        set img [image create photo $opts(-name) -file $filename]
        
        # Skalieren wenn gewuenscht (erfordert manuelles Resize)
        if {$opts(-height) ne "" || $opts(-width) ne ""} {
            set img [_scalePhoto $img $opts(-height) $opts(-width)]
        }
        
    } else {
        return -code error -errorcode {TKUTILS TKUICON FORMAT} "unsupported icon format: $ext"
    }
    
    # Cachen
    set cache($cacheKey) $img
    return $img
}

# ============================================================
# create - generate an icon on the fly via tclutils::tusvg
# ============================================================
# Builds the named icon and loads it straight into a Tk photo image
#
proc ::tkutils::tkuicon::create {iconName size args} {
    variable cache
    variable hasTksvg
    variable hasNativeSvg
    
    array set opts {
        -color "#333333"
        -strokeWidth 2
        -name ""
    }
    array set opts $args
    
    if {!$hasTksvg && !$hasNativeSvg} {
        return -code error -errorcode {TKUTILS TKUICON NOSVG} "no SVG support: install tksvg for Tk 8.6, or use Tk 9.0+"
    }
    
    # Cache-Key
    set cacheKey "gen|$iconName|$size|$opts(-color)|$opts(-strokeWidth)"
    if {[info exists cache($cacheKey)]} {
        return $cache($cacheKey)
    }
    
    # the SVG generator lives in tclutils (lazy require: only needed here)
    if {[catch {package require tclutils::tusvg}]} {
        return -code error -errorcode {TKUTILS TKUICON NOGEN} \
            "tclutils::tusvg is required to generate icons"
    }
    
    # SVG erzeugen
    set svg [tclutils::tusvg::icon $iconName $size \
        -color $opts(-color) \
        -strokeWidth $opts(-strokeWidth)]
    
    set svgData [tclutils::tusvg::toString $svg]
    
    # Image-Name
    if {$opts(-name) eq ""} {
        set opts(-name) "uiicon_${iconName}_${size}"
    }
    
    # Als Tk photo image laden
    set img [image create photo $opts(-name) -data $svgData -format "svg"]
    
    # Cachen
    set cache($cacheKey) $img
    return $img
}

# ============================================================
# scale - Bestehendes Icon skalieren
# ============================================================

proc ::tkutils::tkuicon::rescale {imgName newHeight} {
    variable hasTksvg
    variable hasNativeSvg
    
    if {!$hasTksvg && !$hasNativeSvg} {
        return -code error -errorcode {TKUTILS TKUICON NOSVG} "SVG scaling unavailable without tksvg / Tk 9.0+"
    }
    
    # SVG-Images koennen direkt rekonfiguriert werden
    if {[catch {$imgName configure -format "svg -scaletoheight $newHeight"} err]} {
        # Fallback: Manuelles Skalieren
        return [_scalePhoto $imgName $newHeight ""]
    }
    
    return $imgName
}

# ============================================================
# available - Liste verfuegbarer vordefinierter Icons
# ============================================================

proc ::tkutils::tkuicon::available {} {
    return {
        file folder save open
        plus minus x close check
        search settings gear edit pencil
        trash delete copy
        undo redo
        zoom-in zoom-out
        arrow-left arrow-right arrow-up arrow-down
        chevron-left chevron-right chevron-up chevron-down
        play pause stop
        menu hamburger home info help question
        refresh download upload print mail
        calendar user users
        star heart bookmark clock
    }
}

# ============================================================
# clearCache - Icon-Cache leeren
# ============================================================

proc ::tkutils::tkuicon::clearCache {} {
    variable cache
    foreach key [array names cache] {
        catch {image delete $cache($key)}
    }
    array unset cache
    array set cache {}
}

# ============================================================
# Interne Hilfsfunktionen
# ============================================================

proc ::tkutils::tkuicon::_scalePhoto {img targetH targetW} {
    # Einfache Photo-Skalierung (Nearest-Neighbor)
    # Fuer bessere Qualitaet: imgtools verwenden
    
    set srcW [image width $img]
    set srcH [image height $img]
    
    if {$targetH eq "" && $targetW eq ""} {
        return $img
    }
    
    if {$targetH ne "" && $targetW eq ""} {
        set scale [expr {double($targetH) / $srcH}]
        set targetW [expr {int($srcW * $scale)}]
    } elseif {$targetW ne "" && $targetH eq ""} {
        set scale [expr {double($targetW) / $srcW}]
        set targetH [expr {int($srcH * $scale)}]
    }
    
    # Neues Image erstellen
    set newImg [image create photo]
    $newImg copy $img -zoom [expr {$targetW / $srcW}] [expr {$targetH / $srcH}]
    
    return $newImg
}

# ============================================================
# Convenience: Icon-Set fuer Toolbar laden
# ============================================================

proc ::tkutils::tkuicon::loadToolbarSet {size args} {
    array set opts {
        -color "#333333"
        -icons {file folder save open plus minus search settings edit trash copy undo redo}
    }
    array set opts $args
    
    set result [dict create]
    
    foreach iconName $opts(-icons) {
        if {![catch {create $iconName $size -color $opts(-color)} img]} {
            dict set result $iconName $img
        }
    }
    
    return $result
}

package provide tkutils::tkuicon $::tkutils::tkuicon::version
