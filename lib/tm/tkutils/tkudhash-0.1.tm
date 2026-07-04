# tkudhash-0.1.tm -- image-file front end for the perceptual dHash.
#
# Decodes an image with Tk's photo image (plus the `Img` package for
# JPEG/TIFF/... when available) and hands the pixels to the Tk-free core
# tclutils::tudhash. This is the "loader" that tudhash deliberately leaves out.
#
# API:
#   ::tkutils::tkudhash::fromFile path ?-sample N?   -> 16 hex chars
#   ::tkutils::tkudhash::distance  a b               -> 0..64   (from tudhash)
#   ::tkutils::tkudhash::similar   a b ?maxDist?     -> bool     (from tudhash)
#   ::tkutils::tkudhash::similarFiles pathA pathB ?maxDist?  -> bool
#
# For speed on large scans the image is first subsampled so its long side is at
# most ~2*N pixels (default N=48); the core box-averages that down to 9x8. The
# result is deterministic. Errors use errorCode {TKUTILS TKUDHASH <REASON>}.
# MIT.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tudhash

namespace eval ::tkutils::tkudhash {
    namespace export fromFile similar similarFiles distance
}

proc ::tkutils::tkudhash::_err {reason msg} {
    return -code error -errorcode [list TKUTILS TKUDHASH $reason] $msg
}

# best-effort broad format support; harmless if Img is absent (PNG/GIF/PPM work
# with plain Tk).
proc ::tkutils::tkudhash::_haveImg {} {
    variable _img
    if {![info exists _img]} { set _img [expr {![catch {package require Img}]}] }
    return $_img
}

proc ::tkutils::tkudhash::fromFile {path args} {
    set sample 48
    foreach {k v} $args {
        switch -- $k {
            -sample { set sample $v }
            default { _err OPTION "unknown option \"$k\"" }
        }
    }
    _haveImg
    if {[catch {image create photo -file $path} src]} {
        _err LOAD "cannot load image \"$path\": $src"
    }
    set w [image width $src]; set h [image height $src]
    if {$w < 1 || $h < 1} { image delete $src; _err EMPTY "image has zero size" }

    # subsample so the read is cheap; the core still downscales to 9x8
    set sx [expr {$w > 2*$sample ? $w / (2*$sample) : 1}]
    set sy [expr {$h > 2*$sample ? $h / (2*$sample) : 1}]
    if {$sx > 1 || $sy > 1} {
        set small [image create photo]
        $small copy $src -subsample $sx $sy
        image delete $src
    } else {
        set small $src
    }
    set sw [image width $small]; set sh [image height $small]

    set gray {}
    for {set y 0} {$y < $sh} {incr y} {
        for {set x 0} {$x < $sw} {incr x} {
            lassign [$small get $x $y] r g b
            lappend gray [expr {(77*$r + 150*$g + 29*$b) >> 8}]
        }
    }
    image delete $small
    return [::tclutils::tudhash::fromGray $sw $sh $gray]
}

proc ::tkutils::tkudhash::distance {a b} {
    return [::tclutils::tudhash::distance $a $b]
}
proc ::tkutils::tkudhash::similar {a b {maxDist 10}} {
    return [::tclutils::tudhash::similar $a $b $maxDist]
}
proc ::tkutils::tkudhash::similarFiles {pathA pathB {maxDist 10}} {
    return [similar [fromFile $pathA] [fromFile $pathB] $maxDist]
}

package provide tkutils::tkudhash 0.1
