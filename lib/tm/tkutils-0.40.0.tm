# tkutils umbrella package
#
# Loads all widgets that depend only on tclutils (or pure Tk). The optional
# widgets tkutils::tkuxml (needs tDOM), tkutils::tkusqlite (needs sqlite3) and
# tkutils::tkuicon (needs tksvg / Tk 8.7+ for SVG) are NOT loaded here -- require
# them directly once their external package is present.
package require Tcl 8.6-
package require tkutils::tkuhexedit 0.1
package require tkutils::tkucsv 0.1
package require tkutils::tkudiff 0.1
package require tkutils::tkumd 0.1
package require tkutils::tkujson 0.1
package require tkutils::tkucal 0.1
package require tkutils::tkueditor 0.1
package require tkutils::tkuzip 0.1
package require tkutils::tkufuzzy 0.1
package require tkutils::tkudialog 0.1
package require tkutils::tkubase64 0.1
package require tkutils::tkustrings 0.1
package require tkutils::tkutoolbar 0.1
package require tkutils::tkustatus 0.1
package require tkutils::tkunotes 0.1
package require tkutils::tkuform 0.1
package require tkutils::tkuical 0.1
package require tkutils::tkuldif 0.1
package require tkutils::tkuini 0.1
package require tkutils::tkuvcard 0.1
package require tkutils::tkudateentry 0.1
package require tkutils::tkutags 0.1
package require tkutils::tkusearchbar 0.1
package require tkutils::tkufilterbar 0.1
package require tkutils::tkutimeentry 0.1
package require tkutils::tkunumentry 0.1
package require tkutils::tkutree 0.1
package require tkutils::tkudavaccount 0.1
package require tkutils::tkuimage 0.1
package require tkutils::tkutodo 0.1
package require tkutils::tkudavbrowser 0.1
package require tkutils::tkuballoon 0.1
package require tkutils::tkubind 0.1
package require tkutils::tkucontextmenu 0.1
package provide tkutils 0.40.0
