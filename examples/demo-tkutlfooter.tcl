#!/usr/bin/env wish
# ===========================================================================
# Demo: tkutils::tkutlfooter -- a synced footer row for a tablelist, with
# auto-sums (numbers parsed via tclutils::tunum).
#
# Two examples:
#   1) the classic case: a stretched table, no scrollbars;
#   2) (new in 0.2) a wide table with its OWN horizontal scrollbar and frozen
#      columns (-titlecolumns). attach now *chains* the table's existing
#      -xscrollcommand (the scrollbar keeps working) and clones -titlecolumns,
#      so the footer totals stay under their columns while you scroll.
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir

# locate the tclutils dependency for in-tree/dev use
# (installed systems already have tclutils on the module path)
if {[info exists ::env(TCLUTILS_TM)]} {
    tcl::tm::path add $::env(TCLUTILS_TM)
} else {
    set _tkuRoot [file dirname [file dirname $tmDir]]
    foreach _c [lsort -decreasing [glob -nocomplain \
            [file join [file dirname $_tkuRoot] tclutils*/lib/tm]]] {
        tcl::tm::path add $_c
        break
    }
}

package require Tk
package require tablelist
package require tkutils::tkutlfooter

wm title . "tkutlfooter demo"
wm geometry . 560x460

# ===========================================================================
# Example 1 -- simple footer: a stretched table, no scrollbars.
# ===========================================================================
labelframe .e1 -text "1) Simple footer (autosum)" -padx 8 -pady 8
pack .e1 -side top -fill both -expand 1 -padx 8 -pady {8 4}

tablelist::tablelist .e1.t \
    -columns {0 "Article" left  0 "Qty" right  0 "Price" right} \
    -stretch all -stripebackground #eef -height 6
.e1.t insert end {Apple   3 "1,50"}
.e1.t insert end {Pear    5 "2,00"}
.e1.t insert end {Cherry 12 "4,20"}
.e1.t insert end {Plum    7 "3,10"}

tablelist::tablelist .e1.f -showlabels 0 -height 1 \
    -columns {0 {} left 0 {} right 0 {} right}

grid .e1.t -row 0 -column 0 -sticky nsew
grid .e1.f -row 1 -column 0 -sticky ew
grid rowconfigure    .e1 0 -weight 1
grid columnconfigure .e1 0 -weight 1

::tkutils::tkutlfooter::attach  .e1.t .e1.f
::tkutils::tkutlfooter::autosum .e1.t .e1.f -columns {1 2} -label "Sum:" -format "%.2f"
bind .e1.t <<TablelistCellUpdated>> {
    ::tkutils::tkutlfooter::autosum .e1.t .e1.f -columns {1 2} -label "Sum:" -format "%.2f"
}

# ===========================================================================
# Example 2 -- wide table with its OWN horizontal scrollbar and two frozen
# (title) columns. Scroll right: "Artikel-Nr." and "Bezeichnung" stay put, the
# footer follows, and the scrollbar keeps tracking -- because attach chains the
# table's -xscrollcommand and clones -titlecolumns onto the footer.
# ===========================================================================
labelframe .e2 -text \
    "2) Footer with horizontal scrollbar + frozen columns (-titlecolumns 2)" \
    -padx 8 -pady 8
pack .e2 -side top -fill both -expand 1 -padx 8 -pady {4 8}

set tbl  .e2.t
set foot .e2.f
# -stretch {} (no stretch) so columns keep their width and the table really
# scrolls horizontally when narrower than their total.
tablelist::tablelist $tbl \
    -columns {
        12 "Artikel-Nr." left  26 "Bezeichnung" left
         8 "Menge"       right  8 "Einheit"     center
        12 "Einzelpreis" right 12 "Gesamt"      right
    } \
    -titlecolumns 2 -stretch {} -stripebackground #eef -height 6 \
    -xscrollcommand [list .e2.xs set] -yscrollcommand [list .e2.ys set]
foreach {nr bez m e p g} {
    WP-1001 "Widget Pro - Standardausfuehrung"   5 Stk 49,99 249,95
    GP-2003 "Gadget Plus - Premium-Zubehoer"     3 Stk 29,50  88,50
    AD-7781 "Super-Adapter USB-C / HDMI"        10 Stk 12,95 129,50
    KB-0004 "Verbindungskabel 2 m"              12 m    3,80  45,60
    DOC-001 "Handbuch (gedruckt)"                1 Satz  0,00   0,00
} {
    $tbl insert end [list $nr $bez $m $e $p $g]
}

tablelist::tablelist $foot -showlabels 0 -height 1 -columns {} -background #eef1f6
ttk::scrollbar .e2.ys -orient vertical   -command [list $tbl yview]
ttk::scrollbar .e2.xs -orient horizontal -command [list $tbl xview]

# table + vertical scrollbar (row 0), footer (row 1), horizontal scrollbar (row 2)
grid $tbl   .e2.ys -sticky nsew
grid $foot  -row 1 -column 0 -sticky ew
grid .e2.xs -row 2 -column 0 -sticky ew
grid rowconfigure    .e2 0 -weight 1
grid columnconfigure .e2 0 -weight 1

# attach: chains .e2.xs's "set" (scrollbar keeps working) and clones the
# table's -titlecolumns/-width/-align/-hide onto the footer.
::tkutils::tkutlfooter::attach  $tbl $foot
# Totals under their columns: Menge (col 2) and Gesamt (col 5).
::tkutils::tkutlfooter::autosum $tbl $foot -columns {2 5} -label "Summe:" -format "%g"
bind $tbl <<TablelistCellUpdated>> {
    ::tkutils::tkutlfooter::autosum .e2.t .e2.f -columns {2 5} -label "Summe:" -format "%g"
}

ttk::label .hint -foreground gray40 -padding {8 0 8 6} -text \
    "Tip: make the window narrower and scroll example 2 horizontally --\
     the frozen columns and the footer totals stay aligned."
pack .hint -side bottom -fill x

# ---------------------------------------------------------------------------
# headless self-test: print both footer rows and exit
# ---------------------------------------------------------------------------
if {[lindex $argv 0] eq "--selftest"} {
    update idletasks
    puts "e1 footer: [.e1.f get 0]"
    puts "e2 footer: [.e2.f get 0]"
    puts "e2 foot titlecolumns: [.e2.f cget -titlecolumns]"
    exit 0
}
