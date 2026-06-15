#!/usr/bin/env wish
# demo-tkuwheel -- mouse-wheel forwarding from embedded widgets to a text widget.
#
# The table-like frame embedded in the text widget would normally swallow the
# wheel; tkuwheel forwards it so scrolling keeps working over the frame.

set here [file dirname [file normalize [info script]]]
catch {tcl::tm::path add [file normalize [file join $here .. lib tm]]}
if {[info exists ::env(TKUTILS_TM)]} { catch {tcl::tm::path add $::env(TKUTILS_TM)} }
package require Tk
package require tkutils::tkuwheel

wm title . "tkuwheel demo"
text .t -wrap word -yscrollcommand {.sb set} -width 60 -height 20
ttk::scrollbar .sb -orient vertical -command {.t yview}
grid .t .sb -sticky nsew
grid columnconfigure . 0 -weight 1
grid rowconfigure    . 0 -weight 1

for {set i 1} {$i <= 8} {incr i} { .t insert end "Paragraph $i -- scroll with the wheel.\n\n" }

# An embedded frame (acts like a frame-mode table cell block)
frame .t.card -bg #cccccc -padx 1 -pady 1
foreach {r txt} {0 "Header A | Header B" 1 "row 1 a | row 1 b" 2 "row 2 a | row 2 b"} {
    label .t.card.l$r -text $txt -bg [expr {$r==0 ? "#e0e0e0" : "white"}] \
        -anchor w -padx 8 -pady 4
    grid .t.card.l$r -row $r -column 0 -sticky ew -padx 1 -pady 1
}
grid columnconfigure .t.card 0 -weight 1
.t window create end -window .t.card -padx 5 -pady 5
.t insert end "\n\n"
for {set i 9} {$i <= 20} {incr i} { .t insert end "Paragraph $i -- still scrolling.\n\n" }

# Without this line the wheel does nothing while the pointer is over the frame:
::tkutils::tkuwheel::redirect .t .t.card

label .info -text "Move the pointer over the grey table and use the wheel." \
    -anchor w -padx 6 -pady 4
grid .info -row 1 -column 0 -columnspan 2 -sticky ew
