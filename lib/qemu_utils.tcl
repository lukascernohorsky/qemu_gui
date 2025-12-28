# Utility helpers and lightweight logic that can be reused without the Tk GUI.
# This file intentionally avoids loading Tk so it can be sourced from tests and
# headless tooling.

package require Tcl 8.6

namespace eval ::qemu {
    namespace eval jobs {}
    namespace eval diagnostics {}
    namespace eval manifest {}
}

# -- Job runner ---------------------------------------------------------------
#
# A minimal queue that can execute shell commands synchronously, record their
# outcome, and be reset from tests or other callers.

proc ::qemu::jobs::create {} {
    return [dict create state idle queue {} history {} current ""]
}

proc ::qemu::jobs::enqueue {runnerVar cmd} {
    upvar 1 $runnerVar runner
    set queue [dict get $runner queue]
    lappend queue $cmd
    dict set runner queue $queue
}

proc ::qemu::jobs::runNext {runnerVar} {
    upvar 1 $runnerVar runner
    set queue [dict get $runner queue]
    if {[llength $queue] == 0} {
        return [dict create status idle message "no jobs pending"]
    }

    set cmd [lindex $queue 0]
    dict set runner state running
    dict set runner current $cmd

    if {[catch {eval exec $cmd} result opts]} {
        set exitCode 1
        if {[dict exists $opts -errorcode]} {
            set ec [dict get $opts -errorcode]
            if {[llength $ec] >= 3 && [lindex $ec 0] eq "CHILDSTATUS"} {
                set exitCode [lindex $ec 2]
            }
        }
        set statusDict [dict create status failure exitCode $exitCode output $result]
    } else {
        set statusDict [dict create status success exitCode 0 output $result]
    }

    # Remove the job from the queue and record history; reset state to idle.
    set queue [lrange $queue 1 end]
    dict set runner queue $queue
    dict set runner state idle
    dict set runner current ""

    set history [dict get $runner history]
    lappend history $statusDict
    dict set runner history $history

    return $statusDict
}

proc ::qemu::jobs::stop {runnerVar} {
    upvar 1 $runnerVar runner
    dict set runner queue {}
    dict set runner state idle
    dict set runner current ""
    return $runner
}

# -- Diagnostics --------------------------------------------------------------
#
# Build a small JSON diagnostic payload from a VM-like config and ensure
# sensitive networking fields are redacted.

proc ::qemu::diagnostics::escape {value} {
    return [string map {\\ \\\\ \" \\\"} $value]
}

proc ::qemu::diagnostics::redacted {value} {
    if {$value eq ""} { return "" }
    return "***"
}

proc ::qemu::diagnostics::report {cfg {topics {"vm"}} {scale "config"}} {
    set topicJson {}
    foreach t $topics {
        lappend topicJson "\"[escape $t]\""
    }

    set netJson {}
    if {[dict exists $cfg net]} {
        foreach net [dict get $cfg net] {
            dict with net {
                set hostfwdSafe [redacted $hostfwd]
                set macSafe [redacted $mac]
                lappend netJson [format {{"type":"%s","model":"%s","hostfwd":"%s","mac":"%s"}} \
                    [escape $type] [escape $model] [escape $hostfwdSafe] [escape $macSafe]]
            }
        }
    }

    set networksJoined [join $netJson ","]
    set topicsJoined [join $topicJson ","]
    return [format {{"topics":[%s],"scale":"%s","networks":[%s]}} \
        $topicsJoined [escape $scale] $networksJoined]
}

# -- Manifest validation ------------------------------------------------------
#
# Validate that numeric constraint values inside a manifest JSON match expected
# values. Uses Tcllib json if available, otherwise falls back to a simple
# regex-based extractor for key/value pairs.

proc ::qemu::manifest::extractConstraints {jsonStr expectedKeys} {
    if {![catch {package require json}]} {
        set parsed [json::json2dict $jsonStr]
        if {[dict exists $parsed constraints]} {
            return [dict get $parsed constraints]
        }
        # fall through to regex extraction if constraints key is absent
    }

    # Basic structural check to avoid accepting arbitrary input when a JSON
    # parser is unavailable.
    if {![regexp {^\s*\{.*\}\s*$} $jsonStr]} {
        error "Invalid JSON structure"
    }

    set constraints {}
    set keySet {}
    foreach key $expectedKeys { dict set keySet $key 1 }

    set matches [regexp -all -inline {"([A-Za-z0-9_]+)"\s*:\s*([0-9]+)} $jsonStr]
    for {set i 0} {$i < [llength $matches]} {incr i 3} {
        set key [lindex $matches [expr {$i + 1}]]
        set value [lindex $matches [expr {$i + 2}]]
        if {[dict exists $keySet $key]} {
            dict set constraints $key $value
        }
    }
    return $constraints
}

proc ::qemu::manifest::validate {jsonStr expectedConstraints} {
    set expectedKeys [dict keys $expectedConstraints]
    if {[catch {set parsedConstraints [extractConstraints $jsonStr $expectedKeys]} errMsg]} {
        return [dict create ok 0 errors [list $errMsg] parsed {}]
    }

    set errors {}
    foreach key $expectedKeys {
        if {![dict exists $parsedConstraints $key]} {
            lappend errors "Missing constraint $key"
            continue
        }
        set actual [dict get $parsedConstraints $key]
        set expected [dict get $expectedConstraints $key]
        if {$actual != $expected} {
            lappend errors "Constraint $key expected $expected got $actual"
        }
    }

    return [dict create ok [expr {[llength $errors] == 0}] errors $errors parsed $parsedConstraints]
}
