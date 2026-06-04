# tkutils::tkuimage -- image helpers and a scrollable/zoomable viewer widget for
# Tk. Scaling uses the imgtools extension when present and falls back to Tk's
# built-in photo subsample/zoom otherwise (imgtools is optional). Tk 8.6+/9.x.
#
#   tkuimage::fit 1920 1080 800 600          ;# -> {800 450 0.41666} (contain math)
#   set thumb [tkuimage::thumbnail $photo 96]
#   set v [tkuimage::view .v]; pack $v -fill both -expand 1
#   tkuimage::openFile .v photo.png          ;# load + fit to the widget
#   tkuimage::zoomIn .v ; tkuimage::zoomOut .v ; tkuimage::zoom1 .v ; tkuimage::fitView .v

package require Tk 8.6-

namespace eval ::tkutils {}
namespace eval ::tkutils::tkuimage {
    namespace export fit scale thumbnail load fromData view openFile \
        zoomIn zoomOut zoom1 fitView getImage
    variable state
    array set state {}
    variable haveImgtools [expr {![catch {package require imgtools}]}]
    variable version 0.1
}

# --- pure fit math (no Tk needed) --------------------------------------
# Return {newW newH scale} fitting imgW x imgH into boxW x boxH.
# mode: contain (fit inside), cover (fill, may overflow), none (1:1).
proc ::tkutils::tkuimage::fit {imgW imgH boxW boxH {mode contain}} {
    if {$imgW <= 0 || $imgH <= 0} {
        return -code error -errorcode {TKUTILS TKIMAGE SIZE} "image size must be positive"
    }
    switch -- $mode {
        none  { return [list $imgW $imgH 1.0] }
        cover { set s [expr {max(double($boxW)/$imgW, double($boxH)/$imgH)}] }
        default { set s [expr {min(double($boxW)/$imgW, double($boxH)/$imgH)}] }
    }
    return [list [expr {int($imgW * $s)}] [expr {int($imgH * $s)}] $s]
}

# --- Tk-dependent helpers ----------------------------------------------

# Load an image file into a photo image (PNG/GIF native; others need Img/tkimg).
proc ::tkutils::tkuimage::load {file {dst ""}} {
    if {$dst eq ""} { return [image create photo -file $file] }
    $dst configure -file $file
    return $dst
}

# Create a photo image from raw image bytes (PNG/GIF; JPEG needs Img/tkimg).
# Uses Tk's -data option with base64. Returns $dst (created if empty).
proc ::tkutils::tkuimage::fromData {bytes {dst ""}} {
    set b64 [binary encode base64 $bytes]
    if {$dst eq ""} { return [image create photo -data $b64] }
    $dst configure -data $b64
    return $dst
}

# Scale $src to w x h into $dst (created if empty). Uses imgtools if available,
# otherwise Tk integer subsample/zoom. Returns $dst.
proc ::tkutils::tkuimage::scale {src w h {dst ""}} {
    variable haveImgtools
    if {$dst eq ""} { set dst [image create photo] }
    set ow [image width $src]
    set oh [image height $src]
    if {$ow <= 0 || $oh <= 0 || $w <= 0 || $h <= 0} { return $dst }
    if {$haveImgtools && ![catch {imgtools::scale $src ${w}x${h} $dst}]} {
        return $dst
    }
    # Tk fallback: integer factors only.
    $dst blank
    if {$w < $ow || $h < $oh} {
        set fx [expr {int(ceil(double($ow) / $w))}]
        set fy [expr {int(ceil(double($oh) / $h))}]
        set f [expr {max($fx, $fy, 1)}]
        $dst copy $src -subsample $f $f
    } elseif {$w > $ow || $h > $oh} {
        set f [expr {max(min(int(double($w) / $ow), int(double($h) / $oh)), 1)}]
        $dst copy $src -zoom $f $f
    } else {
        $dst copy $src
    }
    return $dst
}

# Scale $src to fit a maxSize x maxSize box (contain). Returns $dst photo.
proc ::tkutils::tkuimage::thumbnail {src maxSize {dst ""}} {
    lassign [fit [image width $src] [image height $src] $maxSize $maxSize contain] w h
    return [scale $src $w $h $dst]
}

# --- viewer widget -----------------------------------------------------
proc ::tkutils::tkuimage::view {path args} {
    variable state
    set fitmode contain
    foreach {k v} $args {
        if {$k eq "-fitmode"} { set fitmode $v }
    }
    frame $path
    set c $path.c
    canvas $c -highlightthickness 0
    scrollbar $path.x -orient horizontal -command [list $c xview]
    scrollbar $path.y -orient vertical   -command [list $c yview]
    $c configure -xscrollcommand [list $path.x set] -yscrollcommand [list $path.y set]
    grid $c      -row 0 -column 0 -sticky nsew
    grid $path.y -row 0 -column 1 -sticky ns
    grid $path.x -row 1 -column 0 -sticky ew
    grid columnconfigure $path 0 -weight 1
    grid rowconfigure    $path 0 -weight 1

    set disp [image create photo]
    set item [$c create image 0 0 -anchor nw -image $disp]
    set state($path,canvas)  $c
    set state($path,disp)    $disp
    set state($path,item)    $item
    set state($path,orig)    ""
    set state($path,zoom)    1.0
    set state($path,fitmode) $fitmode

    bind $c    <Configure> [list ::tkutils::tkuimage::_onResize $path]
    bind $path <Destroy>   [list ::tkutils::tkuimage::_cleanup $path %W]
    return $path
}

proc ::tkutils::tkuimage::openFile {path file} {
    variable state
    if {$state($path,orig) ne ""} { catch {image delete $state($path,orig)} }
    set state($path,orig)    [load $file]
    set state($path,zoom)    1.0
    set state($path,fitmode) contain
    _redraw $path
}

proc ::tkutils::tkuimage::getImage {path} {
    variable state
    return $state($path,orig)
}

proc ::tkutils::tkuimage::zoomIn  {path} { _setZoom $path 1.25 }
proc ::tkutils::tkuimage::zoomOut {path} { _setZoom $path 0.8 }
proc ::tkutils::tkuimage::zoom1   {path} {
    variable state
    set state($path,zoom) 1.0
    set state($path,fitmode) actual
    _redraw $path
}
proc ::tkutils::tkuimage::fitView {path} {
    variable state
    set state($path,fitmode) contain
    _redraw $path
}
proc ::tkutils::tkuimage::_setZoom {path factor} {
    variable state
    set state($path,zoom) [expr {$state($path,zoom) * $factor}]
    set state($path,fitmode) actual
    _redraw $path
}
proc ::tkutils::tkuimage::_onResize {path} {
    variable state
    if {[info exists state($path,fitmode)] && $state($path,fitmode) eq "contain"} {
        _redraw $path
    }
}
proc ::tkutils::tkuimage::_redraw {path} {
    variable state
    set orig $state($path,orig)
    if {$orig eq ""} { return }
    set c $state($path,canvas)
    set cw [winfo width $c]
    set ch [winfo height $c]
    if {$cw <= 1 || $ch <= 1} { return }
    set ow [image width $orig]
    set oh [image height $orig]
    if {$state($path,fitmode) eq "contain"} {
        lassign [fit $ow $oh $cw $ch contain] nw nh
    } else {
        set z $state($path,zoom)
        set nw [expr {int($ow * $z)}]
        set nh [expr {int($oh * $z)}]
    }
    scale $orig $nw $nh $state($path,disp)
    $c coords $state($path,item) 0 0
    $c configure -scrollregion \
        [list 0 0 [image width $state($path,disp)] [image height $state($path,disp)]]
}
proc ::tkutils::tkuimage::_cleanup {path w} {
    variable state
    if {$w ne $path} { return }
    catch {image delete $state($path,orig)}
    catch {image delete $state($path,disp)}
    array unset state $path,*
}

package provide tkutils::tkuimage 0.1
