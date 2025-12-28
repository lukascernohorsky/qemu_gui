package require json

namespace eval ::virt::plugins {
    variable registry {}

    proc loadManifests {driversRoot} {
        variable registry
        set registry {}
        foreach manifest [glob -nocomplain [file join $driversRoot * manifest.json]] {
            set dir [file dirname $manifest]
            set fh [open $manifest r]
            set payload [read $fh]
            close $fh
            set data [json::json2dict $payload]
            dict set data dir $dir
            lappend registry $data
        }
        return $registry
    }

    proc instantiate {manifest} {
        set entry [file join [dict get $manifest dir] [dict get $manifest entrypoint]]
        source $entry
        set className [dict get $manifest class]
        return [${className} new $manifest]
    }
}
