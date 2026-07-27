#!/usr/bin/env wish
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require Tk
package require tkutils::tkupreview

wm title . "tkupreview demo"
wm geometry . 680x480

# A row of buttons, each showing a different preview KIND. The widget is
# policy-free: the demo (the "application") decides what content maps to what
# kind and hands it over.

set ::samples {
    text     {notes.txt}          {Plain text preview.\nLine two.\nLine three.}
    markdown {README.md}          {# Title\n\nSome **bold** and *italic* text, and a list:\n\n- one\n- two\n- three}
    json     {config.json}        {{"name":"demo","count":3,"tags":["a","b"]}}
    ini      {settings.ini}       {[main]\nname = demo\ncount = 3\n\n[paths]\nhome = /home/greg}
    csv      {data.csv}           {name,city,age\nAnna,Berlin,29\nBjoern,Hamburg,41}
    hex      {bytes}              {ABC\x00\x01\x02 hello}
    message  {}                   {Select a file to preview.}
}

ttk::frame .bar
foreach {kind title content} $::samples {
    set c [string map {\\n "\n"} $content]
    ttk::button .bar.b$kind -text $kind -command [list showKind $kind $title $c]
    pack .bar.b$kind -side left -padx 2 -pady 4
}

proc showKind {kind title content} {
    if {$kind eq "message"} {
        ::tkutils::tkupreview::message .pv $content
    } else {
        ::tkutils::tkupreview::$kind .pv $title $content
    }
    wm title . "tkupreview demo -- kind: [::tkutils::tkupreview::kind .pv]"
}

::tkutils::tkupreview::widget .pv

pack .bar -side top -fill x -padx 6 -pady {6 0}
pack .pv  -side top -fill both -expand 1 -padx 6 -pady 6

# start on the empty-state message
::tkutils::tkupreview::message .pv "Pick a preview kind above."
