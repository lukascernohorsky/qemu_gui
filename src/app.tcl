#!/usr/bin/env tclsh
package require Tcl 8.6
package require Tk
package require json

set ::virt::ROOT [file dirname [file normalize [info script]]]
lappend auto_path $::virt::ROOT

source [file join $::virt::ROOT core/logger.tcl]
source [file join $::virt::ROOT core/exec.tcl]
source [file join $::virt::ROOT core/plugin_loader.tcl]
source [file join $::virt::ROOT core/commands.tcl]
source [file join $::virt::ROOT core/jobs.tcl]
source [file join $::virt::ROOT core/diagnostics.tcl]

namespace eval ::virt {
    variable appVersion "0.2.0"
}

namespace eval ::virt::state {
    variable drivers {}
    variable connections {}
    variable preferences [dict create terminal_template "xterm -e {cmd}" dry_run 1]
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
        new "New" start "Start" stop "Stop" force "Force" delete "Delete" console "Open Console" ssh "Open SSH Terminal" refresh "Refresh" prefs "Preferences" savelogs "Save Logs" diag "Export Diagnostics"
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
    ttk::frame $nb.history
    text $nb.history.text -height 8 -wrap word -state disabled
    pack $nb.history.text -fill both -expand 1
    $nb add $nb.logs -text "Logs"
    $nb add $nb.history -text "History"
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
            $txt insert end "Actions: [join [::virt::ui::guestActions $id] \", \"]\n"
        } else {
            $txt insert end [$tree item $id -text]
        }
    }
    $txt configure -state disabled
}

proc ::virt::ui::handleAction {action} {
    ::virt::logger::log info "Action $action triggered"
    if {$action eq "refresh"} { ::virt::ui::populateTree }
    if {$action eq "start"} { ::virt::ui::runGuestAction mock.start }
    if {$action eq "stop"} { ::virt::ui::runGuestAction mock.stop }
    if {$action eq "force"} { ::virt::ui::runGuestAction mock.force }
    if {$action eq "delete"} { ::virt::ui::runGuestAction mock.delete }
    if {$action eq "console"} { ::virt::ui::runConsole }
    if {$action eq "prefs"} { ::virt::ui::openPrefs }
    if {$action eq "ssh"} { ::virt::ui::openSshTemplate }
    if {$action eq "savelogs"} { ::virt::ui::saveLogs }
    if {$action eq "diag"} { ::virt::ui::exportDiagnostics }
}

proc ::virt::ui::guestActions {guestId} {
    set connNode [lindex [.container.tree parent $guestId] 0]
    set conn [lsearch -regexp -inline $::virt::state::connections [list .*]]
    foreach c $::virt::state::connections {
        if {[dict get $c id] eq $connNode} {
            set drv [dict get $c driver]
            set acts [$drv guest_actions $guestId]
            set labels {}
            foreach act $acts { lappend labels [dict get $act label] }
            return $labels
        }
    }
    return {}
}

proc ::virt::ui::runGuestAction {commandId} {
    set sel [.container.tree selection]
    if {$sel eq ""} { return }
    set guestId [lindex $sel 0]
    set connNode [.container.tree parent $guestId]
    foreach c $::virt::state::connections {
        if {[dict get $c id] eq $connNode} {
            set drv [dict get $c driver]
            set cmdId [$drv command_for_action $commandId $guestId]
            set res [::virt::jobs::runCommand $cmdId {}]
            ::virt::ui::appendLog $res
            ::virt::ui::renderDetails
            return
        }
    }
}

proc ::virt::ui::runConsole {} {
    set sel [.container.tree selection]
    if {$sel eq ""} { return }
    set guestId [lindex $sel 0]
    set connNode [.container.tree parent $guestId]
    foreach c $::virt::state::connections {
        if {[dict get $c id] eq $connNode} {
            set drv [dict get $c driver]
            set info [$drv console_info $guestId]
            set msg "Console type: [dict get $info type]\nHost: [dict get $info host]\nPort: [dict get $info port]\nViewer hint: [dict get $info viewer_hint]\nCommand: [join [dict get $info command] \" \"]\nURI: [dict get $info copyable_uri]"
            tk_messageBox -icon info -type ok -title "Console" -message $msg
            return
        }
    }
}

proc ::virt::ui::appendLog {result} {
    set txt .container.detail.nb.logs.text
    $txt configure -state normal
    $txt insert end "[clock format [clock seconds] -format \"%Y-%m-%d %H:%M:%S\"] :: [dict get $result command-id] :: status=[dict get $result status] dry-run=[dict get $result dry-run]\n"
    if {[dict exists $result stdout]} {
        $txt insert end "stdout: [dict get $result stdout]\n"
    }
    if {[dict exists $result error]} {
        $txt insert end "error: [dict get $result error]\n"
    }
    if {[dict exists $result privilege]} {
        $txt insert end "privilege: [dict get $result privilege]\n"
    }
    $txt insert end "\n"
    $txt see end
    $txt configure -state disabled
    ::virt::ui::renderHistory
}

proc ::virt::ui::openPrefs {} {
    variable ::virt::state::preferences
    set win [toplevel .prefs]
    wm title $win "Preferences"
    ttk::label $win.l1 -text "Terminal command template (use {cmd} placeholder)"
    ttk::entry $win.e1 -textvariable ::virt::state::preferences(terminal_template)
    ttk::checkbutton $win.cb -text "Dry-run mode (do not execute commands)" -variable ::virt::state::preferences(dry_run)
    ttk::button $win.ok -text "Save" -command [list ::virt::ui::applyPrefs $win]
    grid $win.l1 -row 0 -column 0 -sticky w -padx 4 -pady 4
    grid $win.e1 -row 1 -column 0 -sticky we -padx 4 -pady 2
    grid $win.cb -row 2 -column 0 -sticky w -padx 4 -pady 2
    grid $win.ok -row 3 -column 0 -sticky e -padx 4 -pady 6
    grid columnconfigure $win 0 -weight 1
}

proc ::virt::ui::applyPrefs {win} {
    variable ::virt::state::preferences
    ::virt::jobs::setDryRun $::virt::state::preferences(dry_run)
    destroy $win
}

proc ::virt::ui::openSshTemplate {} {
    variable ::virt::state::preferences
    set template [dict get $::virt::state::preferences terminal_template]
    tk_messageBox -icon info -type ok -title "SSH Command Template" -message "Template: $template\n\nSSH execution is planned; this is a placeholder."
}

proc ::virt::ui::saveLogs {} {
    set path [tk_getSaveFile -title "Save Logs" -defaultextension ".log"]
    if {$path eq ""} { return }
    set txt .container.detail.nb.logs.text
    set content [$txt get 1.0 end]
    set fh [open $path w]
    puts $fh $content
    close $fh
    tk_messageBox -icon info -type ok -title "Logs saved" -message "Logs saved to $path"
}

proc ::virt::ui::exportDiagnostics {} {
    set path [tk_getSaveFile -title "Export Diagnostics" -defaultextension ".json"]
    if {$path eq ""} { return }
    set logsTxt [.container.detail.nb.logs.text get 1.0 end]
    set report [::virt::diagnostics::collect $::virt::appVersion $::virt::state::drivers $::virt::state::connections [::virt::jobs::recent] $logsTxt]
    ::virt::diagnostics::write $report $path
    tk_messageBox -icon info -type ok -title "Diagnostics exported" -message "Diagnostics written to $path"
}

proc ::virt::ui::renderHistory {} {
    set txt .container.detail.nb.history.text
    $txt configure -state normal
    $txt delete 1.0 end
    foreach entry [::virt::jobs::recent] {
        set ts [dict get $entry ts]
        set res [dict get $entry result]
        $txt insert end "[clock format $ts -format \"%Y-%m-%d %H:%M:%S\"] :: [dict get $res command-id] :: status=[dict get $res status] dry-run=[dict get $res dry-run]\n"
    }
    $txt configure -state disabled
}

::virt::commands::init
::virt::loadDrivers
::virt::state::buildConnections
::virt::jobs::setDryRun [dict get $::virt::state::preferences dry_run]
::virt::ui::build

bind . <Control-q> exit
