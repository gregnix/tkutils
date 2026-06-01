package require Tcl 8.6-

# Run every *.test in this directory, each in its own interpreter process.
# Each test file is self-contained (sets up the module path, locates tclutils,
# and declares the haveTk constraint), so this works headless under Xvfb too.
set here [file dirname [file normalize [info script]]]
set failures 0
foreach f [lsort [glob -nocomplain -directory $here *.test]] {
    if {[catch {exec [info nameofexecutable] $f >@ stdout 2>@ stderr} _]} {
        incr failures
    }
}
exit [expr {$failures > 0 ? 1 : 0}]
