# kb-export.tcl -- export the knowledge store back to a wissen-*.md file.
#
# Produces the same format kb-import reads: one "## [Bereich/Thema] Titel"
# section per entry (the category path as a prefix), the markdown body, and an
# explicit "Tags: ..." line. Export -> import therefore round-trips: the DB is
# the source of truth, the markdown a regenerable view.

package require Tcl 8.6-

namespace eval ::kb::export {
    namespace export markdown file
    variable version 0.1
}

# markdown store ?title? -> the whole store as a wissen-md string.
# Entries are grouped by category path and sorted (path, then title).
proc ::kb::export::markdown {store {title "Wissensbasis"}} {
    set stamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]
    set out "# $title\n\nExport $stamp\n\n---\n"

    set rows {}
    foreach e [::kb::store::entriesAll $store] {
        set id   [dict get $e id]
        set full [::kb::store::entryGet $store $id]
        set path [::kb::store::categoryPath $store [dict get $full category_id]]
        lappend rows [list $path [dict get $full title] $id [dict get $full body]]
    }
    # stable sort: by title first (secondary), then by path (primary)
    set rows [lsort -index 1 -dictionary $rows]
    set rows [lsort -index 0 -dictionary $rows]

    foreach r $rows {
        lassign $r path etitle id body
        set head [expr {$path ne "" ? "## \[$path\] $etitle" : "## $etitle"}]
        append out "\n$head\n\n$body\n"
        set tags [::kb::store::entryTags $store $id]
        if {[llength $tags]} { append out "\nTags: [join $tags {, }]\n" }
        append out "\n---\n"
    }
    return $out
}

# file store path ?title? -> write the export to a file (utf-8), return its size.
proc ::kb::export::file {store path {title "Wissensbasis"}} {
    set md [markdown $store $title]
    set ch [open $path w]
    fconfigure $ch -encoding utf-8
    puts -nonewline $ch $md
    close $ch
    return [string length $md]
}

package provide kb::export 0.1
