# tkico-0.1.tm -- create Windows .ico files from Tk images.
#
# Copyright (c) 2026 Gregor
# MIT licensed.
#
# Renders the individual icon sizes with Tk and hands the PNG payloads to
# tclutils::tuico, which assembles the container. Alpha is preserved, because
# the payloads are PNGs written by Tk itself.
#
# Three ways to produce a size, best first:
#
#   1. SVG source with Tk 9 (or tksvg under 8.6): each size is rendered from
#      the vector at its target resolution -- crisp at every step.
#   2. A raster source scaled with `image copy -zoom/-subsample`: integer
#      factors and nearest-neighbour sampling, so small sizes get ragged.
#   3. A caller-supplied photo per size: full control, no scaling here.
#
# Errors use errorCode {TKUTILS TKICO <REASON>}.

package require Tcl 8.6-
package require Tk 8.6-
package require tclutils::tuico 0.1

namespace eval ::tkutils::tkico {
    namespace export fromSvg fromPhoto fromPhotos defaultSizes
    namespace ensemble create

    variable defaultSizeList {256 128 64 48 32 16}
}

# throw --
#   Raise an error with the module's errorCode convention.
proc ::tkutils::tkico::throw {reason message} {
    return -code error -errorcode [list TKUTILS TKICO $reason] $message
}

# defaultSizes --
#   The size list used when none is given.
proc ::tkutils::tkico::defaultSizes {} {
    variable defaultSizeList
    return $defaultSizeList
}

# checkSizes --
#   Validate a size list and return it sorted, largest first.
proc ::tkutils::tkico::checkSizes {sizes} {
    if {[llength $sizes] == 0} {
        throw NOSIZES "no icon sizes given"
    }
    foreach size $sizes {
        if {![string is integer -strict $size] || $size < 1 || $size > 256} {
            throw BADSIZE "size must be an integer 1..256, got: $size"
        }
    }
    return [lsort -integer -decreasing -unique $sizes]
}

# photoToPng --
#   Write a photo image to a temporary PNG and return its bytes. Tk 8.6 and
#   later write PNG natively, so no Img package is required.
proc ::tkutils::tkico::photoToPng {image} {
    close [file tempfile path tkico]
    try {
        $image write $path -format png
        set channel [open $path rb]
        try {
            set data [read $channel]
        } finally {
            close $channel
        }
    } finally {
        file delete -force $path
    }
    if {$data eq ""} {
        throw PNGFAILED "Tk produced no PNG data for image $image"
    }
    return $data
}

# renderSvg --
#   Render an SVG file to a photo of exactly size x size pixels.
proc ::tkutils::tkico::renderSvg {svgFile size} {
    if {[catch {
        set image [image create photo -file $svgFile \
                       -format [list svg -scaletowidth $size]]
    } message]} {
        throw NOSVG "cannot render $svgFile at ${size}px: $message\
            (Tk 9 has SVG built in; under Tk 8.6 load the tksvg package first)"
    }
    return $image
}

# scalePhoto --
#   Scale a square photo to size x size using Tk's integer zoom/subsample.
proc ::tkutils::tkico::scalePhoto {source size} {
    set width [image width $source]
    if {$width == $size} {
        # Copy anyway, so the caller may delete its own image safely.
        set target [image create photo -width $size -height $size]
        $target copy $source
        return $target
    }
    set divisor [gcd $size $width]
    set zoom [expr {$size / $divisor}]
    set subsample [expr {$width / $divisor}]
    set target [image create photo -width $size -height $size]
    $target copy $source -zoom $zoom -subsample $subsample -shrink
    return $target
}

# gcd --
#   Greatest common divisor of two positive integers.
proc ::tkutils::tkico::gcd {a b} {
    while {$b != 0} {
        lassign [list $b [expr {$a % $b}]] a b
    }
    return $a
}

# fromSvg --
#   Build an .ico from an SVG file, rendering every size from the vector.
#
#   -sizes  list of pixel sizes; defaults to {256 128 64 48 32 16}
#
#   Returns the number of bytes written.
proc ::tkutils::tkico::fromSvg {svgFile outFile args} {
    set sizes [defaultSizes]
    foreach {option value} $args {
        switch -- $option {
            -sizes  { set sizes $value }
            default { throw BADOPTION "unknown option: $option" }
        }
    }
    set sizes [checkSizes $sizes]

    if {![file readable $svgFile]} {
        throw NOFILE "cannot read $svgFile"
    }

    set entries {}
    foreach size $sizes {
        set image [renderSvg $svgFile $size]
        try {
            lappend entries [list $size [photoToPng $image]]
        } finally {
            image delete $image
        }
    }
    return [::tclutils::tuico::write $outFile $entries]
}

# fromPhoto --
#   Build an .ico from one square photo image, scaling it to every size.
#
#   -sizes  list of pixel sizes; defaults to {256 128 64 48 32 16}
#
#   The scaling uses integer factors without interpolation. For good small
#   sizes prefer fromSvg, or render each size yourself and use fromPhotos.
proc ::tkutils::tkico::fromPhoto {photo outFile args} {
    set sizes [defaultSizes]
    foreach {option value} $args {
        switch -- $option {
            -sizes  { set sizes $value }
            default { throw BADOPTION "unknown option: $option" }
        }
    }
    set sizes [checkSizes $sizes]

    set width [image width $photo]
    set height [image height $photo]
    if {$width != $height} {
        throw NOTSQUARE "source image must be square, got ${width}x${height}"
    }

    set entries {}
    foreach size $sizes {
        set image [scalePhoto $photo $size]
        try {
            lappend entries [list $size [photoToPng $image]]
        } finally {
            image delete $image
        }
    }
    return [::tclutils::tuico::write $outFile $entries]
}

# fromPhotos --
#   Build an .ico from photos the caller rendered, one per size. Nothing is
#   scaled here; each image must already be square and of its nominal size.
#
#   photos  list of {size photoImage} pairs
proc ::tkutils::tkico::fromPhotos {photos outFile} {
    if {[llength $photos] == 0} {
        throw NOSIZES "no images given"
    }
    set entries {}
    foreach pair $photos {
        if {[llength $pair] != 2} {
            throw BADENTRY "entry must be a {size image} pair, got: $pair"
        }
        lassign $pair size photo
        set width [image width $photo]
        set height [image height $photo]
        if {$width != $size || $height != $size} {
            throw SIZEMISMATCH \
                "image for size $size is ${width}x${height}"
        }
        lappend entries [list $size [photoToPng $photo]]
    }
    return [::tclutils::tuico::write $outFile $entries]
}

package provide tkutils::tkico 0.1
