package require Tcl 8.6
source [file join [file dirname [file normalize [info script]]] exec.tcl]
source [file join [file dirname [file normalize [info script]]] commands.tcl]

namespace eval ::virt::jobs {
    variable history {}
    variable dryRun 0

    proc setDryRun {flag} {
        variable dryRun
        set dryRun $flag
    }

    proc runCommand {commandId ctx} {
        variable dryRun
        set spec [::virt::commands::resolve $commandId]
        set builder [dict get $spec builder]
        set argv {}
        if {[dict exists $builder argv]} {
            set argv [dict get $builder argv]
        }
        set opts [dict create -timeout [dict get $spec timeout] -dryRun $dryRun]
        set res [::virt::exec::run $argv $opts]
        dict set res command-id $commandId
        dict set res dry-run $dryRun
        ::virt::jobs::record $res
        return $res
    }

    proc record {result} {
        variable history
        lappend history [dict create ts [clock seconds] result $result]
    }

    proc recent {} {
        variable history
        return $history
    }
}
