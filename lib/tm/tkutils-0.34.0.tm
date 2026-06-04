# tkutils umbrella package
#
# Loads all widgets that depend only on tclutils (or pure Tk). The optional
# widgets tkutils::tkxml (needs tDOM) and tkutils::tksqlite (needs sqlite3) are
# NOT loaded here -- require them directly once their external package is present.
package require Tcl 8.6-
package require tkutils::tkhexedit 0.1
package require tkutils::tkcsv 0.1
package require tkutils::tkdiff 0.1
package require tkutils::tkmd 0.1
package require tkutils::tkjson 0.1
package require tkutils::tkcal 0.1
package require tkutils::tkeditor 0.1
package require tkutils::tkzip 0.1
package require tkutils::tkfuzzy 0.1
package require tkutils::tkdialog 0.1
package require tkutils::tkbase64 0.1
package require tkutils::tkstrings 0.1
package require tkutils::tktoolbar 0.1
package require tkutils::tkstatus 0.1
package require tkutils::tknotes 0.1
package require tkutils::tkform 0.1
package require tkutils::tkical 0.1
package require tkutils::tkldif 0.1
package require tkutils::tkini 0.1
package require tkutils::tkvcard 0.1
package require tkutils::tkdateentry 0.1
package require tkutils::tktags 0.1
package require tkutils::tksearchbar 0.1
package require tkutils::tktimeentry 0.1
package require tkutils::tknumentry 0.1
package require tkutils::tktree 0.1
package require tkutils::tkdavaccount 0.1
package require tkutils::tkimage 0.1
package require tkutils::tktodo 0.1
package require tkutils::tkdavbrowser 0.1
package provide tkutils 0.34.0
