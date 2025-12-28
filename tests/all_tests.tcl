package require tcltest

set here [file dirname [info script]]
set root [file normalize [file join $here ".."]]
set libFile [file join $root "lib" "qemu_utils.tcl"]
if {![file exists $libFile]} {
    error "Missing helper library at $libFile"
}
source $libFile

tcltest::configure -testdir $here -file *.test -verbose b -loadfile $libFile -singleproc 1
tcltest::runAllTests
