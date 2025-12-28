package require Tcl 8.6

namespace eval ::virt::exec {
    variable defaultTimeout 15000

    proc run {argv {options {}}} {
        if {[llength $argv] == 0} {
            error "argv must not be empty"
        }
        set dryRun [dict get $options -dryRun 0]
        set timeout [dict get $options -timeout $::virt::exec::defaultTimeout]
        set envVars [dict get $options -env {}]
        set result [dict create argv $argv timeout $timeout]
        if {$dryRun} {
            dict set result status "dry-run"
            return $result
        }
        set chan [open |[list {*}$argv] r+]
        fconfigure $chan -blocking 0
        set out ""
        set err ""
        set done 0
        set start [clock milliseconds]
        while {!$done} {
            if {[eof $chan]} { set done 1 }
            append out [read $chan]
            if {[expr {[clock milliseconds] - $start}] > $timeout} {
                catch {close $chan}
                error "command timed out"
            }
            after 10
        }
        set status [catch {close $chan} res]
        dict set result status [expr {$status ? "error" : "ok"}]
        dict set result stdout $out
        if {$status} { dict set result error $res }
        return $result
    }
}
