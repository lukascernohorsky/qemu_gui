#!/usr/bin/env tclsh
#
# Entry point for virt-tk-manager prototype. This wrapper simply forwards to
# src/app.tcl so that running `tclsh qemu_gui.tcl` continues to work from the
# repo root.
#
package require Tcl 8.6
set scriptDir [file dirname [file normalize [info script]]]
source [file join $scriptDir src app.tcl]
