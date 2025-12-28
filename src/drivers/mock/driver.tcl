package require Tcl 8.6

namespace eval ::virt::drivers::mock {}

oo::class create ::virt::drivers::mock::Driver {
    variable manifest

    constructor {m} {
        set manifest $m
    }

    method id {} { return [dict get $manifest id] }
    method name {} { return [dict get $manifest name] }

    method detect {hostCtx} {
        return [dict create available 1 reasons {} version_info [dict create version "mock-1.0" mode "deterministic"]]
    }

    method capabilities {hostCtx} {
        return [dict create guests 1 storage 1 networks 1 consoles 1]
    }

    method inventory {} {
        return [dict create \
            guests {
                {id "mockvm-1" name "Mock VM 1" state "stopped" arch "x86_64"}
                {id "mockvm-2" name "Mock VM 2" state "running" arch "aarch64"}
            } \
            storage {
                {id "diskpool" type "dir" path "/var/mock/disks"}
            } \
            networks {
                {id "default" type "user"}
            }]
    }

    method guest_actions {id} {
        return {start stop force delete console}
    }

    method console_info {id} {
        return [dict create type "vnc" host "127.0.0.1" port 5901 viewer_hint "vncviewer" command {vncviewer 127.0.0.1:5901} copyable_uri "vnc://127.0.0.1:5901"]
    }
}
