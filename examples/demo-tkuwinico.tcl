#!/usr/bin/env wish
# demo-tkuwinico.tcl -- build a Windows .ico from an SVG or PNG.
#
#   wish demo-tkuwinico.tcl logo.svg app.ico
#   wish demo-tkuwinico.tcl logo.png app.ico 32 16
#
# An SVG source gives the best result: every size is rendered from the vector.
# A raster source is scaled with Tk's integer zoom/subsample, which is coarse
# at small sizes.

package require Tk
package require tkutils::tkuwinico 0.1

wm withdraw .

proc usage {} {
    puts stderr "usage: wish demo-tkuwinico.tcl <in.svg|in.png> <out.ico> ?size ...?"
    exit 1
}

lassign $argv inFile outFile
if {$inFile eq "" || $outFile eq ""} {
    usage
}

set sizes [lrange $argv 2 end]
if {$sizes eq ""} {
    set sizes [::tkutils::tkuwinico::defaultSizes]
}

if {[string tolower [file extension $inFile]] eq ".svg"} {
    set bytes [::tkutils::tkuwinico::fromSvg $inFile $outFile -sizes $sizes]
} else {
    set photo [image create photo -file $inFile]
    try {
        set bytes [::tkutils::tkuwinico::fromPhoto $photo $outFile -sizes $sizes]
    } finally {
        image delete $photo
    }
}

puts "$outFile: $bytes bytes, sizes: $sizes"
exit 0
