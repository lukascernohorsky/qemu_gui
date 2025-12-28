package require Tcl 8.6
package require json

namespace eval ::virt::diagnostics {}

proc ::virt::diagnostics::collect {appVersion drivers connections jobs logsText} {
    set report [dict create]
    dict set report generated_at [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S%z"]
    dict set report app_version $appVersion
    set driverSummaries {}
    foreach drv $drivers {
        lappend driverSummaries [dict create id [$drv id] name [$drv name]]
    }
    dict set report drivers $driverSummaries
    dict set report connections $connections
    dict set report jobs $jobs
    dict set report logs $logsText
    return $report
}

proc ::virt::diagnostics::write {report path} {
    set jsonPayload [json::dict2json $report]
    set fh [open $path w]
    puts $fh $jsonPayload
    close $fh
    return $path
}
