# tkutils::tkutltools -- umbrella for the tablelist extension family. Loading
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
package require tablelist

package require tclutils::tunum 0.1

package require tkutils::tkutlsort   0.1
package require tkutils::tkutlfmt    0.1
package require tkutils::tkutlclip   0.1
package require tkutils::tkutlfooter 0.1
package require tkutils::tkutlfind   0.1
package require tkutils::tkutlstate  0.1
package require tkutils::tkutltree   0.1

package provide tkutils::tkutltools 0.1
