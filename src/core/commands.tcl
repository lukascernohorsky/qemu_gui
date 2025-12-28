package require Tcl 8.6

namespace eval ::virt::commands {
    variable registry

    proc init {} {
        variable registry
        set registry {}
        # Mock command registry; real drivers will extend this table.
        foreach {cid argv timeout supports_dry_run} {
            mock.start  {echo "starting"} 120000 1
            mock.stop   {echo "stopping"} 120000 1
            mock.force  {echo "force kill"} 30000 1
            mock.delete {echo "delete"} 30000 1
            mock.console {echo "console open"} 10000 0
        } {
            dict set registry $cid [dict create \
                command-id $cid \
                timeout $timeout \
                privilege none \
                supports_dry_run $supports_dry_run \
                builder [dict create argv $argv] \
            ]
        }
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
