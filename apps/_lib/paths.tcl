# tkutils / tclutils module-path bootstrap for the bundled apps.
#
# The resolver itself lives in <repo>/tools/setup.tcl -- the single source of
# truth, also usable on its own as `source .../tools/setup.tcl`. This wrapper
# only locates and sources it, so every app keeps the familiar one-liner
#     source [file join [file dirname [info script]] .. _lib paths.tcl]
# and the ::tkupaths::add resolver ends up defined and run.

source [file join [file dirname [file normalize [info script]]] .. .. tools setup.tcl]
