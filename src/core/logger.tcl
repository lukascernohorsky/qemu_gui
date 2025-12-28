namespace eval ::virt::logger {
    variable logLevel "info"
    variable logTarget "stdout"
    variable logFile ""

    proc init {{level "info"} {target "stdout"} {filePath ""}} {
        variable logLevel
        variable logTarget
        variable logFile
        set logLevel $level
        set logTarget $target
        set logFile $filePath
    }

    proc timestamp {} {
        return [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S%z"]
    }

    proc shouldLog {level} {
        set levels {debug info warn error}
        set idx [lsearch -exact $levels $level]
        set cur [lsearch -exact $levels $::virt::logger::logLevel]
        return [expr {$idx >= $cur}]
    }

    proc log {level message} {
        variable logTarget
        variable logFile
        if {![shouldLog $level]} {return}
        set line "[timestamp] [$level] $message"
        switch -- $logTarget {
            stdout { puts $line }
            stderr { puts stderr $line }
            file {
                if {$logFile eq ""} { return }
                set fh [open $logFile a]
                puts $fh $line
                close $fh
            }
            default { puts $line }
        }
    }
}
