# kb-import.tcl -- import a consolidated wissen-*.md into the knowledge store.
#
# Each top-level "## <n>. <title>" section becomes one entry: the heading is the
# title, the section body is the markdown. A coarse category is derived from the
# heading, and inline-code terms (`like this`) in the body seed the tags -- those
# backtick spans are exactly the technical keywords worth indexing as tags. FTS
# already covers the full text; categories and tags are for browsing/filtering.

package require Tcl 8.6-

namespace eval ::kb::import {
    namespace export markdown file
    variable version 0.1
}

# markdown store mdText ?source? -- import all sections, return the count.
proc ::kb::import::markdown {store mdText {source ""}} {
    set sections [_split $mdText]
    set n 0
    foreach sec $sections {
        set title [dict get $sec title]
        set body  [dict get $sec body]
        if {$title eq ""} continue
        set catpath [dict get $sec cat]
        if {$catpath ne ""} {
            set cat [_categoryPath $store $catpath]
        } else {
            set cat [_categoryId $store [_area $title]]
        }
        set explicit [_extractTags body]
        set id  [::kb::store::entryAdd $store $title $body $cat $source]
        set tags [expr {[llength $explicit] ? $explicit : [_tags $title $body]}]
        foreach tag $tags { ::kb::store::entryTag $store $id $tag }
        incr n
    }
    return $n
}

# file store path ?source? -- convenience wrapper reading from a file.
proc ::kb::import::file {store path {source ""}} {
    set ch [open $path r]
    fconfigure $ch -encoding utf-8
    set md [read $ch]
    close $ch
    if {$source eq ""} { set source [::file tail $path] }
    return [markdown $store $md $source]
}

# --- parsing ----------------------------------------------------------------
# Split into sections at top-level "## " headings; drop the leading title/intro.
proc ::kb::import::_split {md} {
    set out {}
    set cur ""
    set inSection 0
    foreach line [split $md \n] {
        if {[regexp {^## +(.*)$} $line -> heading]} {
            if {$inSection} { lappend out $cur }
            set cat ""
            set h [string trim $heading]
            if {[regexp {^\[([^\]]+)\]\s*(.*)$} $h -> cat rest]} {
                set cat [string trim $cat]
                set h   [string trim $rest]
            }
            set cur [dict create title $h cat $cat bodyLines {}]
            set inSection 1
        } elseif {$inSection} {
            dict lappend cur bodyLines $line
        }
    }
    if {$inSection} { lappend out $cur }
    # join body lines, trim a trailing horizontal rule / blank lines
    set res {}
    foreach sec $out {
        set body [join [dict get $sec bodyLines] \n]
        set body [string trimright $body]
        set body [regsub {\n*-{3,}\s*$} $body ""]
        lappend res [dict create title [dict get $sec title] \
            cat [dict get $sec cat] body [string trim $body]]
    }
    return $res
}

# resolve/create a "Bereich / Thema / ..." category path, return the leaf id.
proc ::kb::import::_categoryPath {store path} {
    set parent ""
    foreach part [split $path /] {
        set part [string trim $part]
        if {$part eq ""} continue
        set id [_findChild $store $parent $part]
        if {$id eq ""} { set id [::kb::store::categoryAdd $store $part $parent] }
        set parent $id
    }
    return $parent
}
proc ::kb::import::_findChild {store parent name} {
    foreach c [::kb::store::categories $store] {
        set p [dict get $c parent_id]
        set match [expr {$parent eq "" ? ($p eq "") : ($p eq $parent)}]
        if {$match && [dict get $c name] eq $name} { return [dict get $c id] }
    }
    return ""
}

# --- coarse category from the heading ---------------------------------------
proc ::kb::import::_area {heading} {
    set h [string tolower $heading]
    foreach {pattern area} {
        {docir|mdstack|\yir\y|diag|flow|diagramm|math|tabelle}  "docir/mdstack"
        {\ytk\y|widget|rendering|monospace|canvas|treeview}      "Tk"
        {deployment|modul-laden|discovery|pkgindex|\ytm\y|deploy} "Deployment"
        {registry|repo|sandbox|tuflow|hygiene|check-modules}     "Tools"
        {tcl|sqlite|syntax|auswertung|encoding|errorcode|namespace} "Tcl Core"
    } {
        if {[regexp $pattern $h]} { return $area }
    }
    return "Sonstiges"
}

# category id for a name, creating it on first use (cached per store call)
proc ::kb::import::_categoryId {store name} {
    foreach c [::kb::store::categories $store] {
        if {[dict get $c name] eq $name} { return [dict get $c id] }
    }
    return [::kb::store::categoryAdd $store $name]
}

# Pull an explicit "Tags: a, b, c" (or "Schlagworte:") line out of the body,
# returning the tag list and removing the line from the body. Empty if none.
proc ::kb::import::_extractTags {bodyVar} {
    upvar 1 $bodyVar body
    set tags {}
    set kept {}
    foreach ln [split $body \n] {
        if {[regexp -nocase {^\s*(?:tags|schlagworte|schlagwoerter)\s*:\s*(.+)$} $ln -> rest]} {
            foreach t [split $rest ,] {
                set t [string trim $t]
                if {$t ne ""} { lappend tags $t }
            }
        } else {
            lappend kept $ln
        }
    }
    set body [string trim [join $kept \n]]
    return $tags
}

# --- tags from inline-code spans --------------------------------------------
proc ::kb::import::_tags {title body} {
    set seen [dict create]
    set tags {}
    foreach {full inner} [regexp -all -inline {`([^`\n]+)`} "$title\n$body"] {
        set t [string trim $inner]
        # keep short, identifier-ish keywords: no spaces, reasonable length
        if {[string length $t] < 2 || [string length $t] > 32} continue
        if {[regexp {\s} $t]} continue
        if {![regexp {[A-Za-z]} $t]} continue   ;# skip pure symbol/number junk
        set key [string tolower $t]
        if {[dict exists $seen $key]} continue
        dict set seen $key 1
        lappend tags $t
        if {[llength $tags] >= 8} break   ;# cap tags per entry
    }
    return $tags
}

package provide kb::import 0.1
