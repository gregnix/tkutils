#!/usr/bin/env wish
# Quick standalone runner for just the render-core / loader module tests.
# (Your existing tests/all.tcl already includes them via its *.test glob;
#  this file only exists for running the two in isolation. It does NOT
#  replace all.tcl.)
#   wish tests/run-module-tests.tcl          (needs a display; headless: Xvfb)
package require tcltest
namespace import ::tcltest::*
set here [file dirname [file normalize [info script]]]
set repotm [file normalize [file join $here .. lib tm]]
if {[file isdirectory $repotm]} { ::tcl::tm::path add $repotm }
foreach v {TCLUTILS_TM TKUTILS_TM} {
    if {[info exists ::env($v)]} { catch {::tcl::tm::path add $::env($v)} }
}
configure -singleproc 1 -testdir $here -file {tkurender.test tkuload.test}
configure {*}$argv
runAllTests
