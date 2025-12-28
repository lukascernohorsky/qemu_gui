#!/usr/bin/env tclsh
package require Tcl 8.6
package require Tk
package require json

set ::virt::ROOT [file dirname [file normalize [info script]]]
lappend auto_path $::virt::ROOT

source [file join $::virt::ROOT core/logger.tcl]
source [file join $::virt::ROOT core/exec.tcl]
source [file join $::virt::ROOT core/plugin_loader.tcl]

namespace eval ::virt {
    variable appVersion "0.2.0"
}

namespace eval ::virt::state {
    variable drivers {}
    variable connections {}
}

proc ::virt::theme::select {} {
    set winSys [tk windowingsystem]
    set style [ttk::style theme use]
    if {$winSys eq "win32"} {
        foreach candidate {vista xpnative clam default} {
            if {[lsearch -exact [ttk::style theme names] $candidate] != -1} {
                ttk::style theme use $candidate
                return
            }
        }
    } elseif {$winSys eq "aqua"} {
        ttk::style theme use aqua
    } else {
        foreach candidate {yaru arc clearlooks clam default} {
            if {[lsearch -exact [ttk::style theme names] $candidate] != -1} {
                ttk::style theme use $candidate
                return
            }
        }
    }
    ttk::style theme use $style
}

proc ::virt::theme::setScaling {} {
    if {![info exists ::env(TK_SCALE)]} { return }
    catch {tk scaling $::env(TK_SCALE)}
}

proc ::virt::loadDrivers {} {
    variable ::virt::state::drivers
    set manifests [::virt::plugins::loadManifests [file join $::virt::ROOT drivers]]
    set ::virt::state::drivers {}
    foreach m $manifests {
        set driver [::virt::plugins::instantiate $m]
        lappend ::virt::state::drivers $driver
    }
}

proc ::virt::state::buildConnections {} {
    variable drivers
    variable connections
    set connections {}
    foreach drv $drivers {
        set connId "local-[${drv} id]"
        dict set conn id $connId
        dict set conn name "Localhost (${connId})"
        dict set conn driver $drv
        dict set conn host_ctx [dict create mode local]
        lappend connections $conn
    }
}

proc ::virt::ui::build {} {
    ::virt::theme::select
    ::virt::theme::setScaling
    wm title . "virt-tk-manager (prototype)"
    ttk::frame .container -padding 6
    pack .container -fill both -expand 1

    ttk::frame .container.toolbar
    foreach {key label} {
        new "New" start "Start" stop "Stop" force "Force" delete "Delete" console "Open Console" ssh "Open SSH Terminal" refresh "Refresh" prefs "Preferences"
    } {
        ttk::button .container.toolbar.$key -text $label -command [list ::virt::ui::handleAction $key]
        pack .container.toolbar.$key -side left -padx 2 -pady 2
    }
    pack .container.toolbar -fill x

    ttk::panedwindow .container.pw -orient horizontal
    pack .container.pw -fill both -expand 1 -pady 6

    ttk::frame .container.treePane
    set tree [ttk::treeview .container.tree -columns {type detail} -show tree headings -selectmode browse]
    .container.tree heading type -text "Type"
    .container.tree heading detail -text "Detail"
    bind .container.tree <<TreeviewSelect>> {::virt::ui::renderDetails}
    pack .container.tree -fill both -expand 1
    .container.pw add .container.tree -weight 1

    ttk::frame .container.detail
    set nb [ttk::notebook .container.detail.nb]
    ttk::frame $nb.summary
    text $nb.summary.text -height 15 -wrap word -state disabled
    pack $nb.summary.text -fill both -expand 1
    $nb add $nb.summary -text "Summary"
    ttk::frame $nb.logs
    text $nb.logs.text -height 8 -wrap word -state disabled
    pack $nb.logs.text -fill both -expand 1
    $nb add $nb.logs -text "Logs"
    pack $nb -fill both -expand 1
    .container.pw add .container.detail -weight 2

    ttk::label .container.status -text "Ready"
    pack .container.status -fill x -pady 4

    ::virt::ui::populateTree
}

proc ::virt::ui::populateTree {} {
    variable ::virt::state::connections
    set tree .container.tree
    $tree delete [$tree children {}]
    foreach conn $::virt::state::connections {
        set connId [dict get $conn id]
        set node [$tree insert {} end -id $connId -text [dict get $conn name] -values {connection {}}]
        set drv [dict get $conn driver]
        set inv [$drv inventory]
        foreach guest [dict get $inv guests] {
            set gid [dict get $guest id]
            set text "[dict get $guest name] ([dict get $guest state])"
            $tree insert $node end -id $gid -text $text -values [list guest [dict get $guest arch]]
        }
    }
    $tree selection set [$tree get_children {}]
}

proc ::virt::ui::renderDetails {} {
    set tree .container.tree
    set sel [$tree selection]
    set txt .container.detail.nb.summary.text
    $txt configure -state normal
    $txt delete 1.0 end
    if {$sel eq ""} {
        $txt insert end "Select an item to view details."
    } else {
        set id [lindex $sel 0]
        set kind [$tree set $id type]
        if {$kind eq "connection"} {
            $txt insert end "Connection: [$tree item $id -text]\n"
        } elseif {$kind eq "guest"} {
            $txt insert end "Guest: [$tree item $id -text]\n"
            $txt insert end "Arch: [$tree set $id detail]\n"
        } else {
            $txt insert end [$tree item $id -text]
        }
    }
    $txt configure -state disabled
}

proc ::virt::ui::handleAction {action} {
    ::virt::logger::log info "Action $action triggered"
    if {$action eq "refresh"} { ::virt::ui::populateTree }
}

::virt::loadDrivers
::virt::state::buildConnections
::virt::ui::build

bind . <Control-q> exit
