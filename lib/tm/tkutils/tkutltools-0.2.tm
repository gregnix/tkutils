# tkutils::tkutltools -- umbrella for the tablelist extension family. Loading
# Description: umbrella for the tablelist extension family.
# Category: Tk · tablelist
# this pulls in tablelist (external) plus all tkutl* helpers and their shared
# tclutils::tunum number backend. It is kept separate from the main tkutils
# umbrella, which by design loads only modules with pure-Tk/tclutils deps;
# tablelist is an external dependency, so require this only where tablelist is
# present.
#
# Family:
#   tkutls ort / clip / fmt / footer / find / state / tree
#
# Tcl 8.6-
package require Tcl 8.6-
package require Tk
# tablelist_tile is the Tablelist variant of tkutils (as in tkutablelist).
# Tablelist forbids loading tablelist and tablelist_tile in one process; both
# provide the same ::tablelist:: commands, so an application that already has
# the classic one keeps it. Up to 2026-10-20 this module required the classic
# "tablelist", and tkutils followed by this module failed with
# "usingTile ... not supported".
if {[catch {package present tablelist}] && [catch {package present tablelist_tile}]} {
    package require tablelist_tile
}

package require tclutils::tunum 0.1

package require tkutils::tkutlsort   0.2
package require tkutils::tkutlfmt    0.1
package require tkutils::tkutlclip   0.2
package require tkutils::tkutlfooter 0.3
package require tkutils::tkutlfind   0.2
package require tkutils::tkutlstate  0.1
package require tkutils::tkutltree   0.2

package provide tkutils::tkutltools 0.2
