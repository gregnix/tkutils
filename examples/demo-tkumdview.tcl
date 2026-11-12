#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
# locate the tclutils dependency for in-tree/dev use
# (installed systems already have tclutils on the module path)
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}
package require Tk
package require tkutils::tkumdview

set sample {# mdview

A Markdown viewer widget built on **tumd**: a heading outline on the left and a
rendered preview on the right.

## Inline formatting

Supports **bold**, *italic*, ***both***, ~~struck~~, `inline code`,
[links](https://example.com), bare URLs like https://www.tcl-lang.org and
footnotes[^1]. Links to [a heading](#tables) scroll the preview.

## Code blocks

```tcl
proc greet {who} {
    puts "hello $who"
}
```

## Lists

- bullet one
  continued on the next line
  - nested
- bullet two

* [x] task done
* [ ] task open

1. step one
2. step two

> Block quotes are rendered with an indent.

## Tables

| Module | Version | Lines |
|:-------|:-------:|------:|
| **tkumdview** | `0.2` | 474 |
| tkuballoon | `0.1` | 165 |
| tumd | `0.3` | 990 |

---

Select a heading on the left to jump to it. Ctrl+F searches, Ctrl+plus
and Ctrl+minus change the font size.

[^1]: A footnote, shown at the end and linked both ways.
}

wm title . "tkumdview demo"
set w [::tkutils::tkumdview::widget .w -width 72 -height 30]
pack $w -fill both -expand 1

if {[llength $argv] > 0} {
    ::tkutils::tkumdview::loadFile $w [lindex $argv 0]
} else {
    ::tkutils::tkumdview::setMarkdown $w $sample
}

vwait forever
