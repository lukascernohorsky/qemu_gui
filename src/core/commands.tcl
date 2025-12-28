package require Tcl 8.6

namespace eval ::virt::commands {
    variable registry

    proc init {} {
        variable registry
        set registry {}
        # Mock command registry; real drivers will extend this table.
        dict set registry mock.start [dict create command-id mock.start timeout 120000 privilege none builder {argv {echo "starting"}}]
        dict set registry mock.stop  [dict create command-id mock.stop timeout 120000 privilege none builder {argv {echo "stopping"}}]
        dict set registry mock.force [dict create command-id mock.force timeout 30000 privilege none builder {argv {echo "force kill"}}]
        dict set registry mock.delete [dict create command-id mock.delete timeout 30000 privilege none builder {argv {echo "delete"}}]
    }

    proc resolve {commandId args} {
        variable registry
        if {![info exists registry]} { init }
        if {![dict exists $registry $commandId]} {
            error "Unknown command-id: $commandId"
        }
        return [dict get $registry $commandId]
    }
}
