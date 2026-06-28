# Headless smoke test for the notes app. Requires Tk and tclutils::tunotes
# (constraint "notes"); skips cleanly otherwise. No Tablelist needed.
#   export TCLUTILS_TM=.../tclutils-0.35.0/lib/tm
#   export TKUTILS_TM=.../tkutils-0.26.0/lib/tm
#   xvfb-run -a tclsh notes-app/tests/smoke.tcl
package require Tcl 8.6-
package require tcltest
namespace import ::tcltest::*

set here [file dirname [file normalize [info script]]]
source [file join [file dirname [file normalize [info script]]] .. .. _lib paths.tcl]
source [file join $here .. notes_app.tcl]

set haveTk [expr {![catch {package require Tk 8.6-}]}]
set haveEng [expr {$haveTk && ![catch {package require tclutils::tunotes 0.1}]}]
testConstraint notes $haveEng
if {$haveEng} { ::notesapp::buildApp . }

proc W {} { return $::notesapp::S(w) }
proc selectRoot {} {
    set store [::tkutils::tkunotes::store [W]]
    set rid [lindex [::tclutils::tunotes::roots $store] 0]
    ::tkutils::tkunotes::select [W] $rid
}

test notes-1.1 {new root increases the count} -constraints notes -setup {::notesapp::clearDirty} -body {
    ::notesapp::cmdNew
    ::notesapp::cmdNewRoot
    ::tkutils::tkunotes::count [W]
} -result 1

test notes-1.2 {new child under the selected note} -constraints notes -setup {::notesapp::clearDirty} -body {
    ::notesapp::cmdNew
    ::notesapp::cmdNewRoot
    selectRoot
    ::notesapp::cmdNewChild
    ::tkutils::tkunotes::count [W]
} -result 2

test notes-1.3 {save / new / open round-trip} -constraints notes -setup {::notesapp::clearDirty} -body {
    ::notesapp::cmdNew
    ::notesapp::cmdNewRoot
    ::notesapp::cmdNewRoot
    set f [file join [makeDirectory notesd] notes.json]
    ::notesapp::cmdSaveAs $f
    ::notesapp::cmdNew
    set empty [::tkutils::tkunotes::count [W]]
    ::notesapp::cmdOpen $f
    list $empty [::tkutils::tkunotes::count [W]]
} -result {0 2}

test notes-1.4 {expand / collapse run without error} -constraints notes -setup {::notesapp::clearDirty} -body {
    ::notesapp::cmdNew
    ::notesapp::cmdNewRoot
    selectRoot
    ::notesapp::cmdNewChild
    ::notesapp::cmdExpand 0
    ::notesapp::cmdExpand 1
    expr {[::tkutils::tkunotes::count [W]] == 2}
} -result 1

cleanupTests
