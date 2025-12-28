#!/usr/bin/env tclsh
##
## Multiplatform Tcl/Tk GUI for configuring and launching QEMU virtual machines.
## The tool manages simple per-VM configuration files and can generate or run
## QEMU command lines based on the options described in readme.md.
##

package require Tcl 8.6

namespace eval ::qemu {}

set ::qemu::headless [expr {[info exists ::env(QEMU_GUI_HEADLESS)] && $::env(QEMU_GUI_HEADLESS) eq "1"}]
if {!$::qemu::headless} {
    if {[catch {package require Tk} err]} {
        puts "Tk is required to run this GUI: $err"
        exit 1
    }
}

namespace eval ::qemu {
    variable appVersion "0.2"
    variable storageDir [file normalize [file join [pwd] "vms"]]
    variable vmList {}
    variable selectedVm ""
    variable qemuPathOverrides {
        x86_64 ""
        i386 ""
        aarch64 ""
        arm ""
    }
    variable jobQueue {}
    variable jobDetails {}
    variable runningJob ""
    variable jobSeq 0
    variable jobLogs {}
    variable statusMessage "Připraveno"
    variable statusProgress 0
    variable statusCode ""
    variable logFilter ""
    variable mockNewName ""
    variable mockNewCap ""
    variable mockCapabilities {
        compute {actions {start stop restart health-check} limits {maxMemory 8192 maxCPUs 8}}
        storage {actions {attach detach snapshot} limits {maxDisks 4 maxSnapshots 8}}
        network {actions {connect disconnect} limits {maxNICs 4}}
    }
    variable mockInventory {
        {id inv-001 name "Demo VM" capability compute state stopped}
    }
    variable mockTopics {
        {topic lifecycle scale medium}
        {topic performance scale high}
        {topic compliance scale low}
    }
}

proc ::qemu::ensureStorage {} {
    variable storageDir
    if {![file exists $storageDir]} {
        file mkdir $storageDir
    }
}

proc ::qemu::setStatus {message {progress ""} {code ""}} {
    variable statusMessage
    variable statusProgress
    variable statusCode
    set statusMessage $message
    if {$progress ne ""} {
        set statusProgress $progress
    }
    if {$code ne ""} {
        set statusCode $code
    }
    if {[info commands .main.status.label] ne ""} {
        .main.status.label configure -text "$statusMessage (kód: [expr {$statusCode eq \"\" ? \"OK\" : $statusCode}])"
    }
    if {[info commands .main.status.progress] ne ""} {
        .main.status.progress configure -value $statusProgress
    }
}

proc ::qemu::appendLogEntry {entry} {
    variable jobLogs
    lappend jobLogs $entry
}

proc ::qemu::getJob {id} {
    variable jobDetails
    if {[dict exists $jobDetails $id]} {
        return [dict get $jobDetails $id]
    }
    return ""
}

proc ::qemu::setJob {id jobDict} {
    variable jobDetails
    dict set jobDetails $id $jobDict
}

proc ::qemu::enqueueJob {kind data} {
    variable jobSeq
    variable jobQueue
    variable runningJob
    incr jobSeq
    set id "job-$jobSeq"
    set job [dict create id $id kind $kind data $data status queued progress 0 code "" message ""]
    dict set job start_ts [clock milliseconds]
    setJob $id $job
    lappend jobQueue $id
    appendLogEntry [dict create id $id kind $kind status queued message "Zařazen do fronty" code ""]
    setStatus "Fronta: $kind" 0
    ::qemu::startJobLoop
    return $id
}

proc ::qemu::startJobLoop {} {
    variable runningJob
    variable jobQueue
    if {$runningJob ne ""} { return }
    if {[llength $jobQueue] == 0} { return }
    set runningJob [lindex $jobQueue 0]
    set jobQueue [lrange $jobQueue 1 end]
    ::qemu::runJobAsync $runningJob
}

proc ::qemu::updateJobProgress {id progress} {
    set job [::qemu::getJob $id]
    if {$job eq ""} { return }
    dict set job progress $progress
    dict set job status running
    ::qemu::setJob $id $job
    ::qemu::setStatus "Job [dict get $job kind] běží" $progress
}

proc ::qemu::completeJob {id status message {code ""}} {
    variable runningJob
    set job [::qemu::getJob $id]
    if {$job eq ""} { return }
    dict set job status $status
    dict set job progress 100
    dict set job code $code
    dict set job message $message
    ::qemu::setJob $id $job
    ::qemu::appendLogEntry [dict create id $id kind [dict get $job kind] status $status message $message code [expr {$code eq "" ? "0" : $code}]]
    ::qemu::setStatus "Job [dict get $job kind]: $message" 100 [expr {$code eq "" ? "0" : $code}]
    if {[dict get $job kind] eq "mock_new_vm"} {
        if {[info commands .mock.tree] ne ""} {
            ::qemu::refreshMockInventoryUI .mock.tree .mock.detail
        }
    }
    set runningJob ""
    ::qemu::startJobLoop
}

proc ::qemu::executeJobWork {id} {
    set job [::qemu::getJob $id]
    if {$job eq ""} { return }
    set kind [dict get $job kind]
    set data [dict get $job data]
    switch -- $kind {
        start_vm {
            ::qemu::launchVmInteractive [dict get $data cfg]
            return [dict create status completed message "Spuštění zahájeno" code 0]
        }
        diagnostics_export {
            set dest [dict get $data dest]
            set diag [::qemu::collectDiagnosticsData]
            set archive [::qemu::writeDiagnosticsBundle $diag $dest]
            return [dict create status completed message "Diagnostika uložena do $archive" code 0]
        }
        mock_new_vm {
            set entry [::qemu::createMockEntry [dict get $data name] [dict get $data capability]]
            return [dict create status completed message "Přidán záznam [dict get $entry id]" code 0]
        }
        default {
            return [dict create status completed message "Hotovo" code 0]
        }
    }
}

proc ::qemu::runJobAsync {id} {
    set job [::qemu::getJob $id]
    if {$job eq ""} { return }
    ::qemu::updateJobProgress $id 5
    after 150 [list ::qemu::updateJobProgress $id 35]
    after 350 [list ::qemu::updateJobProgress $id 65]
    after 550 [list ::qemu::updateJobProgress $id 90]
    after 700 [list ::qemu::finishJob $id]
}

proc ::qemu::finishJob {id} {
    set result [::qemu::executeJobWork $id]
    set status [dict get $result status]
    set message [dict get $result message]
    set code [dict get $result code]
    ::qemu::completeJob $id $status $message $code
}

proc ::qemu::clearJobState {} {
    variable jobQueue
    variable runningJob
    variable jobDetails
    set jobQueue {}
    set runningJob ""
    set jobDetails {}
    setStatus "Fronta vyčištěna" 0
}

proc ::qemu::filterLogs {needle} {
    variable jobLogs
    if {$needle eq ""} { return $jobLogs }
    set filtered {}
    foreach log $jobLogs {
        if {[string match "*$needle*" [dict get $log message]] || [string match "*$needle*" [dict get $log kind]]} {
            lappend filtered $log
        }
    }
    return $filtered
}

proc ::qemu::sanitizeId {name} {
    set base [string map {{ } _} [string tolower $name]]
    regsub -all {[^a-zA-Z0-9_.-]} $base "_" base
    if {$base eq ""} { set base "vm" }
    set id "${base}_[clock format [clock seconds] -format %Y%m%d%H%M%S]"
    return $id
}

proc ::qemu::loadVmFile {path} {
    set config {}
    if {[catch {source $path} err]} {
        tk_messageBox -icon error -type ok -title "Chyba při načítání" \
            -message "Konfigurace $path nelze načíst:\n$err"
        return ""
    }
    if {![info exists config]} {
        return ""
    }
    return $config
}

proc ::qemu::loadAll {} {
    variable storageDir
    variable vmList
    set vmList {}
    foreach f [lsort [glob -nocomplain -types f [file join $storageDir "*.tcl"]]] {
        set cfg [loadVmFile $f]
        if {$cfg eq ""} { continue }
        set id [file rootname [file tail $f]]
        lappend vmList [list $id $cfg]
    }
}

proc ::qemu::saveVm {id config} {
    variable storageDir
    set path [file join $storageDir "${id}.tcl"]
    set fh [open $path w]
    puts $fh "# Autogenerated VM config"
    puts $fh "set config [list $config]"
    close $fh
}

proc ::qemu::renderVmSummary {cfg} {
    set name [dict get $cfg name]
    set arch [dict get $cfg arch]
    set mem [dict get $cfg memory]
    set cpus [dict get $cfg cpus]
    set machine [dict get $cfg machine]
    set accel [dict get $cfg accel]
    set display [dict get $cfg display]
    return "$name — $arch, ${cpus} CPU, ${mem} MB, machine $machine, accel $accel, display $display"
}

proc ::qemu::getDefaultConfig {} {
    return [dict create \
        name "New VM" \
        arch "x86_64" \
        machine "pc" \
        memory 2048 \
        cpus 2 \
        cpu_model "host" \
        accel "kvm" \
        boot_order "cd" \
        firmware "" \
        iso "" \
        vga "std" \
        display "sdl" \
        snapshot_mode 0 \
        extra_args "" \
        disks {} \
        net {} \
    ]
}

proc ::qemu::addDiskToConfig {cfg diskDict} {
    set disks [dict get $cfg disks]
    lappend disks $diskDict
    dict set cfg disks $disks
    return $cfg
}

proc ::qemu::addNetToConfig {cfg netDict} {
    set nets [dict get $cfg net]
    lappend nets $netDict
    dict set cfg net $nets
    return $cfg
}

proc ::qemu::buildQemuBinary {arch} {
    variable qemuPathOverrides
    set override [dict get $qemuPathOverrides $arch]
    if {$override ne ""} {
        return $override
    }
    switch -- $arch {
        x86_64 { return "qemu-system-x86_64" }
        i386 { return "qemu-system-i386" }
        aarch64 { return "qemu-system-aarch64" }
        arm { return "qemu-system-arm" }
        default { return "qemu-system-$arch" }
    }
}

proc ::qemu::buildCommand {cfg} {
    set arch [dict get $cfg arch]
    set cmd [list [buildQemuBinary $arch]]
    dict with cfg {
        if {$name ne ""} { lappend cmd -name $name }
        if {$machine ne ""} { lappend cmd -machine $machine }
        if {$accel ne ""} { lappend cmd -accel $accel }
        if {$cpu_model ne ""} { lappend cmd -cpu $cpu_model }
        if {$cpus ne ""} { lappend cmd -smp $cpus }
        if {$memory ne ""} { lappend cmd -m $memory }
        if {$boot_order ne ""} { lappend cmd -boot "order=$boot_order" }
        if {$firmware ne ""} { lappend cmd -bios $firmware }
        if {$snapshot_mode} { lappend cmd -snapshot }
        if {$vga ne ""} { lappend cmd -vga $vga }
        if {$display ne ""} { lappend cmd -display $display }
    }
    foreach disk [dict get $cfg disks] {
        dict with disk {
            if {$media eq "cdrom"} {
                lappend cmd -drive "file=$file,format=$format,if=$if,media=cdrom"
            } else {
                set readonlyFlag ""
                if {$readonly} { set readonlyFlag ",snapshot=on" }
                lappend cmd -drive "file=$file,format=$format,if=$if,media=disk$readonlyFlag"
            }
            if {$boot} {
                # crude boot order hint: place bootable CD before disks
            }
        }
    }
    set iso [dict get $cfg iso]
    if {$iso ne ""} {
        lappend cmd -cdrom $iso
    }
    foreach net [dict get $cfg net] {
        dict with net {
            set nic "type=$type"
            if {$model ne ""} { append nic ",model=$model" }
            if {$hostfwd ne ""} { append nic ",hostfwd=$hostfwd" }
            if {$br ne ""} { append nic ",br=$br" }
            if {$tap ne ""} { append nic ",ifname=$tap" }
            if {$mac ne ""} { append nic ",mac=$mac" }
            lappend cmd -nic $nic
        }
    }
    set extra [dict get $cfg extra_args]
    if {$extra ne ""} {
        foreach token $extra { lappend cmd $token }
    }
    return $cmd
}

proc ::qemu::launchVmInteractive {cfg} {
    if {$::qemu::headless} {
        return
    }
    set cmd [buildCommand $cfg]
    set commandStr [join $cmd " "]
    set res [tk_messageBox -type yesno -icon question -title "Spustit VM" \
        -message "Spustit následující příkaz?\n$commandStr"]
    if {$res ne "yes"} { return }
    if {[catch {eval exec {*}$cmd &} err]} {
        tk_messageBox -icon error -type ok -title "Spuštění selhalo" \
            -message "Příkaz se nepodařilo spustit:\n$err"
    }
}

proc ::qemu::startVm {cfg} {
    ::qemu::enqueueJob start_vm [dict create cfg $cfg]
}

proc ::qemu::showCommand {cfg} {
    set cmd [buildCommand $cfg]
    set win [toplevel .cmd]
    wm title $win "Vygenerovaný příkaz"
    text $win.t -wrap word -width 80 -height 8
    $win.t insert end [join $cmd " "]
    $win.t configure -state disabled
    pack $win.t -fill both -expand 1
}

proc ::qemu::openVmForm {mode {id ""} {cfg ""}} {
    if {$cfg eq ""} {
        set cfg [getDefaultConfig]
    }
    set varName "::qemu::form_[string map {. _} [clock clicks]]"

    set win [toplevel .vmform]
    wm title $win [expr {$mode eq "edit" ? "Upravit VM" : "Nový VM"}]
    grid columnconfigure $win 0 -weight 1

    set nb [ttk::notebook $win.nb]
    grid $nb -row 0 -column 0 -sticky news -padx 6 -pady 6

    # Základní karta
    set general [ttk::frame $nb.general]
    set growCols {1}
    set row 0
    foreach {label key} {
        "Název" name
        "Architektura" arch
        "Machine" machine
        "RAM (MB)" memory
        "CPU (počet)" cpus
        "Model CPU" cpu_model
        "Akcelerace" accel
        "Firmware/BIOS" firmware
        "Boot order" boot_order
        "ISO (CD/DVD)" iso
    } {
        ttk::label $general.l$row -text $label
        ttk::entry $general.e$row -textvariable ${varName}($key)
        grid $general.l$row -row $row -column 0 -sticky w -padx 4 -pady 2
        grid $general.e$row -row $row -column 1 -sticky we -padx 4 -pady 2
        incr row
    }
    ttk::checkbutton $general.snapshot -text "Spustit v režimu snapshot (-snapshot)" \
        -variable ${varName}(snapshot_mode)
    grid $general.snapshot -row $row -column 0 -columnspan 2 -sticky w -padx 4 -pady 2
    grid columnconfigure $general 1 -weight 1

    # Úložiště
    set storage [ttk::frame $nb.storage]
    ttk::label $storage.lbl -text "Disky a optická média"
    listbox $storage.list -height 6 -exportselection 0
    ttk::frame $storage.btns
    ttk::button $storage.btns.add -text "Přidat" -command [list ::qemu::addDiskDialog $storage $varName]
    ttk::button $storage.btns.del -text "Odebrat" -command [list ::qemu::removeSelectedDisk $storage $varName]
    pack $storage.btns.add $storage.btns.del -side top -padx 3 -pady 2
    grid $storage.lbl -row 0 -column 0 -sticky w -padx 4 -pady 2
    grid $storage.list -row 1 -column 0 -sticky news -padx 4 -pady 2
    grid $storage.btns -row 1 -column 1 -sticky ns -padx 4 -pady 2
    grid rowconfigure $storage 1 -weight 1
    grid columnconfigure $storage 0 -weight 1

    # Síť
    set network [ttk::frame $nb.network]
    ttk::label $network.lbl -text "Síťová rozhraní"
    listbox $network.list -height 5 -exportselection 0
    ttk::frame $network.btns
    ttk::button $network.btns.add -text "Přidat" -command [list ::qemu::addNetDialog $network $varName]
    ttk::button $network.btns.del -text "Odebrat" -command [list ::qemu::removeSelectedNet $network $varName]
    pack $network.btns.add $network.btns.del -side top -padx 3 -pady 2
    grid $network.lbl -row 0 -column 0 -sticky w -padx 4 -pady 2
    grid $network.list -row 1 -column 0 -sticky news -padx 4 -pady 2
    grid $network.btns -row 1 -column 1 -sticky ns -padx 4 -pady 2
    grid rowconfigure $network 1 -weight 1
    grid columnconfigure $network 0 -weight 1

    # Zobrazení
    set display [ttk::frame $nb.display]
    set row 0
    foreach {label key} {
        "VGA" vga
        "Display backend" display
    } {
        ttk::label $display.l$row -text $label
        ttk::entry $display.e$row -textvariable ${varName}($key)
        grid $display.l$row -row $row -column 0 -sticky w -padx 4 -pady 2
        grid $display.e$row -row $row -column 1 -sticky we -padx 4 -pady 2
        incr row
    }
    grid columnconfigure $display 1 -weight 1

    # Pokročilé
    set advanced [ttk::frame $nb.adv]
    ttk::label $advanced.extraL -text "Dodatečné parametry (oddělené mezerou)"
    ttk::entry $advanced.extraE -textvariable ${varName}(extra_args)
    grid $advanced.extraL -row 0 -column 0 -sticky w -padx 4 -pady 2
    grid $advanced.extraE -row 1 -column 0 -sticky we -padx 4 -pady 2
    grid columnconfigure $advanced 0 -weight 1

    $nb add $general -text "Obecné"
    $nb add $storage -text "Úložiště"
    $nb add $network -text "Síť"
    $nb add $display -text "Zobrazení"
    $nb add $advanced -text "Pokročilé"

    ttk::frame $win.actions
    ttk::button $win.actions.ok -text "Uložit" -command [list ::qemu::saveVmFromForm $win $mode $id $varName]
    ttk::button $win.actions.cancel -text "Zavřít" -command [list destroy $win]
    pack $win.actions.ok $win.actions.cancel -side left -padx 4 -pady 4
    grid $win.actions -row 1 -column 0 -sticky e -padx 8 -pady 6

    # Populate entries with cfg dict via array
    array set $varName $cfg
    if {![info exists ${varName}(disks)]} { set ${varName}(disks) {} }
    if {![info exists ${varName}(net)]} { set ${varName}(net) {} }
    ::qemu::refreshDiskList $storage $varName
    ::qemu::refreshNetList $network $varName

    grid rowconfigure $win 0 -weight 1
    grid columnconfigure $win 0 -weight 1
}

proc ::qemu::addDiskDialog {parent cfgVar} {
    set win [toplevel $parent.diskDialog]
    wm title $win "Přidat disk"
    set row 0
    foreach {label key default} {
        "Soubor" file ""
        "Formát" format "qcow2"
        "Rozhraní" if "virtio"
        "Typ média (disk/cdrom)" media "disk"
        "Bootovací (1/0)" boot 0
        "Pouze čtení (1/0)" readonly 0
    } {
        ttk::label $win.l$row -text $label
        ttk::entry $win.e$row -textvariable disk($key)
        grid $win.l$row -row $row -column 0 -sticky w -padx 4 -pady 2
        grid $win.e$row -row $row -column 1 -sticky we -padx 4 -pady 2
        incr row
    }
    ttk::frame $win.actions
    ttk::button $win.actions.ok -text "Přidat" -command [list ::qemu::confirmAddDisk $win $parent $cfgVar]
    ttk::button $win.actions.cancel -text "Zrušit" -command [list destroy $win]
    pack $win.actions.ok $win.actions.cancel -side left -padx 4 -pady 4
    grid $win.actions -row $row -column 0 -columnspan 2
    grid columnconfigure $win 1 -weight 1
}

proc ::qemu::confirmAddDisk {win parent cfgVar} {
    upvar $cfgVar cfg
    upvar $win::disk disk
    if {![info exists disk(file)] || $disk(file) eq ""} {
        tk_messageBox -icon warning -type ok -title "Chybí soubor" \
            -message "Zadejte cestu k souboru disku."
        return
    }
    set diskDict [dict create \
        file $disk(file) \
        format [expr {[info exists disk(format)] ? $disk(format) : "qcow2"}] \
        if [expr {[info exists disk(if)] ? $disk(if) : "virtio"}] \
        media [expr {[info exists disk(media)] ? $disk(media) : "disk"}] \
        boot [expr {[info exists disk(boot)] ? $disk(boot) : 0}] \
        readonly [expr {[info exists disk(readonly)] ? $disk(readonly) : 0}] \
    ]
    set disks $cfg(disks)
    lappend disks $diskDict
    set cfg(disks) $disks
    ::qemu::refreshDiskList $parent $cfgVar
    destroy $win
}

proc ::qemu::refreshDiskList {parent cfgVar} {
    upvar $cfgVar cfg
    $parent.disks delete 0 end
    foreach disk $cfg(disks) {
        dict with disk {
            $parent.disks insert end "$media: $file ($format, $if) [boot:$boot ro:$readonly]"
        }
    }
}

proc ::qemu::removeSelectedDisk {parent cfgVar} {
    upvar $cfgVar cfg
    set sel [$parent.disks curselection]
    if {$sel eq ""} { return }
    set disks $cfg(disks)
    set keep {}
    set i 0
    foreach disk $disks {
        if {[lsearch -exact $sel $i] == -1} {
            lappend keep $disk
        }
        incr i
    }
    set cfg(disks) $keep
    ::qemu::refreshDiskList $parent $cfgVar
}

proc ::qemu::addNetDialog {parent cfgVar} {
    set win [toplevel $parent.netDialog]
    wm title $win "Přidat síť"
    set row 0
    foreach {label key default} {
        "Typ (user/bridge/tap/none)" type "user"
        "Model" model "virtio-net-pci"
        "Hostfwd (např. tcp::2222-:22)" hostfwd ""
        "Bridge jméno" br ""
        "TAP jméno" tap ""
        "MAC adresa" mac ""
    } {
        ttk::label $win.l$row -text $label
        ttk::entry $win.e$row -textvariable net($key)
        grid $win.l$row -row $row -column 0 -sticky w -padx 4 -pady 2
        grid $win.e$row -row $row -column 1 -sticky we -padx 4 -pady 2
        incr row
    }
    ttk::frame $win.actions
    ttk::button $win.actions.ok -text "Přidat" -command [list ::qemu::confirmAddNet $win $parent $cfgVar]
    ttk::button $win.actions.cancel -text "Zrušit" -command [list destroy $win]
    pack $win.actions.ok $win.actions.cancel -side left -padx 4 -pady 4
    grid $win.actions -row $row -column 0 -columnspan 2
    grid columnconfigure $win 1 -weight 1
}

proc ::qemu::confirmAddNet {win parent cfgVar} {
    upvar $cfgVar cfg
    upvar $win::net net
    set netDict [dict create \
        type [expr {[info exists net(type)] ? $net(type) : "user"}] \
        model [expr {[info exists net(model)] ? $net(model) : "virtio-net-pci"}] \
        hostfwd [expr {[info exists net(hostfwd)] ? $net(hostfwd) : ""}] \
        br [expr {[info exists net(br)] ? $net(br) : ""}] \
        tap [expr {[info exists net(tap)] ? $net(tap) : ""}] \
        mac [expr {[info exists net(mac)] ? $net(mac) : ""}] \
    ]
    set nets $cfg(net)
    lappend nets $netDict
    set cfg(net) $nets
    ::qemu::refreshNetList $parent $cfgVar
    destroy $win
}

proc ::qemu::refreshNetList {parent cfgVar} {
    upvar $cfgVar cfg
    $parent.nets delete 0 end
    foreach net $cfg(net) {
        dict with net {
            $parent.nets insert end "$type/$model hostfwd:$hostfwd br:$br tap:$tap mac:$mac"
        }
    }
}

proc ::qemu::removeSelectedNet {parent cfgVar} {
    upvar $cfgVar cfg
    set sel [$parent.nets curselection]
    if {$sel eq ""} { return }
    set nets $cfg(net)
    set keep {}
    set i 0
    foreach net $nets {
        if {[lsearch -exact $sel $i] == -1} {
            lappend keep $net
        }
        incr i
    }
    set cfg(net) $keep
    ::qemu::refreshNetList $parent $cfgVar
}

proc ::qemu::createMockEntry {name capability} {
    variable mockInventory
    set id "inv-[clock format [clock seconds] -format %H%M%S]"
    set entry [dict create id $id name $name capability $capability state new]
    lappend mockInventory $entry
    ::qemu::appendLogEntry [dict create id $id kind "mock_new_vm" status created message "Mock VM $name přidán" code 0]
    return $entry
}

proc ::qemu::renderCapabilitySummary {capability} {
    variable mockCapabilities
    if {![dict exists $mockCapabilities $capability]} {
        return "Capability $capability: n/a"
    }
    set cap [dict get $mockCapabilities $capability]
    set actions [dict get $cap actions]
    set limits [dict get $cap limits]
    set limitLines {}
    dict for {k v} $limits {
        lappend limitLines "$k=$v"
    }
    return "$capability → akce: [join $actions , ]; limity: [join $limitLines , ]"
}

proc ::qemu::collectDiagnosticsData {} {
    variable vmList
    variable jobLogs
    variable mockCapabilities
    variable mockInventory
    variable mockTopics
    set sanitizedVMs {}
    foreach vm $vmList {
        lassign $vm id cfg
        dict set cfg iso "<redacted>"
        if {[dict exists $cfg firmware]} { dict set cfg firmware "<redacted>" }
        set disks {}
        foreach d [dict get $cfg disks] {
            dict set d file "<redacted>"
            lappend disks $d
        }
        dict set cfg disks $disks
        lappend sanitizedVMs [list $id $cfg]
    }
    return [dict create \
        generated_at [clock format [clock seconds]] \
        vm_inventory $sanitizedVMs \
        job_logs $jobLogs \
        capability_report $mockCapabilities \
        mock_inventory $mockInventory \
        topics $mockTopics \
    ]
}

proc ::qemu::toJson {value} {
    # Prefer dictionary serialization first.
    if {[catch {dict size $value} size] == 0} {
        set parts {}
        dict for {k v} $value {
            lappend parts "\"$k\": [::qemu::toJson $v]"
        }
        return "{[join $parts , ]}"
    }
    # Lists with more than one element are encoded as JSON arrays.
    if {[string is list -strict $value] && [llength $value] > 1} {
        set parts {}
        foreach v $value { lappend parts [::qemu::toJson $v] }
        return "\[[join $parts , ]\]"
    }
    if {[string is integer -strict $value] || [string is double -strict $value]} {
        return $value
    }
    if {$value eq ""} {
        return "\"\""
    }
    set escaped [string map {"\\" "\\\\" "\"" "\\\""} $value]
    set escaped [string map {\n "\\n"} $escaped]
    return "\"$escaped\""
}

proc ::qemu::writeDiagnosticsBundle {data destPath} {
    set baseDir [file normalize [file join [pwd] "diagnostics"]]
    if {![file exists $baseDir]} { file mkdir $baseDir }
    if {$destPath eq ""} {
        set destPath [file join $baseDir "bundle_[clock format [clock seconds] -format %Y%m%d%H%M%S].tar.gz"]
    }
    set tempDir [file join $baseDir "tmp_[clock clicks]"]
    file mkdir $tempDir
    set jsonFile [file join $tempDir "diagnostics.json"]
    set fh [open $jsonFile w]
    puts $fh [::qemu::toJson $data]
    close $fh
    set capFile [file join $tempDir "capability_report.txt"]
    set fh [open $capFile w]
    dict for {k v} [dict get $data capability_report] {
        puts $fh [::qemu::renderCapabilitySummary $k]
    }
    close $fh
    set topicFile [file join $tempDir "topics.txt"]
    set fh [open $topicFile w]
    foreach t [dict get $data topics] {
        puts $fh "topic: [dict get $t topic], scale: [dict get $t scale]"
    }
    close $fh
    exec tar -czf $destPath -C $tempDir .
    file delete -force $tempDir
    return $destPath
}

proc ::qemu::saveVmFromForm {win mode id cfgVar} {
    upvar $cfgVar cfg
    set configDict [dict create]
    foreach key {
        name arch machine memory cpus cpu_model accel firmware boot_order iso
        vga display snapshot_mode extra_args
    } {
        if {[info exists cfg($key)]} {
            dict set configDict $key $cfg($key)
        } else {
            dict set configDict $key ""
        }
    }
    if {![info exists cfg(disks)]} { set cfg(disks) {} }
    if {![info exists cfg(net)]} { set cfg(net) {} }
    dict set configDict disks $cfg(disks)
    dict set configDict net $cfg(net)
    if {$mode eq "new"} {
        set id [sanitizeId [dict get $configDict name]]
    }
    saveVm $id $configDict
    loadAll
    refreshVmList
    destroy $win
}

proc ::qemu::deleteVm {id} {
    variable storageDir
    if {$id eq ""} { return }
    set path [file join $storageDir "${id}.tcl"]
    if {[file exists $path]} {
        file delete $path
    }
    loadAll
    refreshVmList
}

proc ::qemu::refreshVmList {} {
    variable vmList
    .main.list delete [.main.list children {}]
    foreach vm $vmList {
        lassign $vm id cfg
        set summary [renderVmSummary $cfg]
        .main.list insert "" end -id $id -values [list [dict get $cfg name] [dict get $cfg arch] [dict get $cfg cpus] [dict get $cfg memory] [dict get $cfg accel] [dict get $cfg display]]
    }
    ::qemu::renderDetails ""
}

proc ::qemu::selectVm {} {
    variable vmList
    variable selectedVm
    set sel [.main.list selection]
    if {$sel eq ""} {
        set selectedVm ""
        ::qemu::renderDetails ""
        return
    }
    set selectedVm [lindex $sel 0]
    ::qemu::renderDetails $selectedVm
}

proc ::qemu::getVmById {id} {
    variable vmList
    foreach vm $vmList {
        if {[lindex $vm 0] eq $id} {
            return [lindex $vm 1]
        }
    }
    return ""
}

proc ::qemu::renderDetails {id} {
    if {![winfo exists .main.detail.text]} { return }
    set txt .main.detail.text
    $txt configure -state normal
    $txt delete 1.0 end
    if {$id eq ""} {
        $txt insert end "Vyberte VM pro zobrazení detailů."
        $txt configure -state disabled
        return
    }
    set cfg [::qemu::getVmById $id]
    if {$cfg eq ""} {
        $txt insert end "Konfigurace nenalezena."
        $txt configure -state disabled
        return
    }
    $txt insert end "[dict get $cfg name]\n"
    $txt insert end "Arch: [dict get $cfg arch]\n"
    $txt insert end "Machine: [dict get $cfg machine]\n"
    $txt insert end "CPU: [dict get $cfg cpus], Model: [dict get $cfg cpu_model], Accel: [dict get $cfg accel]\n"
    $txt insert end "RAM: [dict get $cfg memory] MB\n"
    $txt insert end "Boot order: [dict get $cfg boot_order]\n"
    if {[dict get $cfg firmware] ne ""} {
        $txt insert end "Firmware: [dict get $cfg firmware]\n"
    }
    if {[dict get $cfg iso] ne ""} {
        $txt insert end "ISO: [dict get $cfg iso]\n"
    }
    if {[dict get $cfg disks] ne {}} {
        $txt insert end "Disky:\n"
        foreach d [dict get $cfg disks] {
            dict with d {
                $txt insert end "  - $media $file ($format, $if) boot:$boot ro:$readonly\n"
            }
        }
    }
    if {[dict get $cfg net] ne {}} {
        $txt insert end "Síť:\n"
        foreach n [dict get $cfg net] {
            dict with n {
                $txt insert end "  - $type $model hostfwd:$hostfwd br:$br tap:$tap mac:$mac\n"
            }
        }
    }
    $txt insert end "\nCapability přehled:\n"
    dict for {cap data} $::qemu::mockCapabilities {
        $txt insert end "  - [::qemu::renderCapabilitySummary $cap]\n"
    }
    set cmd [join [buildCommand $cfg] " "]
    $txt insert end "\nPříkaz:\n$cmd\n"
    $txt configure -state disabled
}

proc ::qemu::openLogViewer {} {
    variable logFilter
    if {[info exists logFilter] == 0} { set logFilter "" }
    if {[winfo exists .logs]} { destroy .logs }
    set win [toplevel .logs]
    wm title $win "Job logy"
    grid columnconfigure $win 0 -weight 1
    ttk::frame $win.controls
    ttk::label $win.controls.l -text "Filtr:"
    ttk::entry $win.controls.e -textvariable ::qemu::logFilter
    ttk::button $win.controls.apply -text "Použít filtr" -command [list ::qemu::renderLogViewer $win]
    ttk::button $win.controls.replay -text "Přehrát" -command [list ::qemu::renderLogViewer $win]
    pack $win.controls.l $win.controls.e $win.controls.apply $win.controls.replay -side left -padx 3 -pady 3
    grid $win.controls -row 0 -column 0 -sticky we
    text $win.txt -height 12 -wrap none
    grid $win.txt -row 1 -column 0 -sticky news
    grid rowconfigure $win 1 -weight 1
    grid columnconfigure $win 0 -weight 1
    ::qemu::renderLogViewer $win
}

proc ::qemu::renderLogViewer {win} {
    variable logFilter
    set logs [::qemu::filterLogs [expr {[info exists logFilter] ? $logFilter : ""}]]
    $win.txt configure -state normal
    $win.txt delete 1.0 end
    foreach log $logs {
        set line "#[dict get $log id] [dict get $log kind] → [dict get $log status], kód [dict get $log code]: [dict get $log message]\n"
        $win.txt insert end $line
    }
    $win.txt configure -state disabled
}

proc ::qemu::openMockNewDialog {parent tree detail} {
    variable mockCapabilities
    set win [toplevel $parent.new]
    wm title $win "Mock: New VM"
    ttk::label $win.nameL -text "Název"
    ttk::entry $win.nameE -textvariable ::qemu::mockNewName
    ttk::label $win.capL -text "Capability"
    set caps [dict keys $mockCapabilities]
    if {![info exists ::qemu::mockNewCap]} { set ::qemu::mockNewCap [lindex $caps 0] }
    ttk::combobox $win.capE -values $caps -textvariable ::qemu::mockNewCap -state readonly
    ttk::button $win.ok -text "Vytvořit" -command [list ::qemu::confirmMockNew $win $tree $detail]
    ttk::button $win.cancel -text "Zavřít" -command [list destroy $win]
    grid $win.nameL -row 0 -column 0 -sticky w -padx 4 -pady 2
    grid $win.nameE -row 0 -column 1 -sticky we -padx 4 -pady 2
    grid $win.capL -row 1 -column 0 -sticky w -padx 4 -pady 2
    grid $win.capE -row 1 -column 1 -sticky we -padx 4 -pady 2
    grid $win.ok -row 2 -column 0 -padx 4 -pady 4
    grid $win.cancel -row 2 -column 1 -padx 4 -pady 4
    grid columnconfigure $win 1 -weight 1
}

proc ::qemu::confirmMockNew {win tree detail} {
    variable mockNewName
    variable mockNewCap
    if {$mockNewName eq ""} {
        tk_messageBox -icon warning -title "Chybí jméno" -message "Zadejte jméno."
        return
    }
    ::qemu::enqueueJob mock_new_vm [dict create name $mockNewName capability $mockNewCap]
    destroy $win
    ::qemu::refreshMockInventoryUI $tree $detail
}

proc ::qemu::refreshMockInventoryUI {tree detail} {
    variable mockInventory
    $tree delete [$tree children {}]
    foreach item $mockInventory {
        $tree insert "" end -id [dict get $item id] -values [list [dict get $item name] [dict get $item capability] [dict get $item state]]
    }
    $detail configure -state normal
    $detail delete 1.0 end
    $detail insert end "Vyberte položku pro detaily capability.\n"
    $detail configure -state disabled
}

proc ::qemu::showMockDetail {tree detail} {
    variable mockCapabilities
    set sel [$tree selection]
    if {$sel eq ""} { return }
    set id [lindex $sel 0]
    variable mockInventory
    foreach item $mockInventory {
        if {[dict get $item id] eq $id} {
            set cap [dict get $item capability]
            $detail configure -state normal
            $detail delete 1.0 end
            $detail insert end "Capability: $cap\n"
            $detail insert end "[::qemu::renderCapabilitySummary $cap]\n"
            $detail insert end "Akce: [join [dict get [dict get $mockCapabilities $cap] actions] , ]\n"
            $detail configure -state disabled
            break
        }
    }
}

proc ::qemu::openMockBackendWindow {} {
    variable mockInventory
    if {[winfo exists .mock]} { destroy .mock }
    set win [toplevel .mock]
    wm title $win "Mock backend inventář"
    grid columnconfigure $win 0 -weight 1
    ttk::frame $win.toolbar
    ttk::button $win.toolbar.new -text "New VM (mock)" -command [list ::qemu::openMockNewDialog $win.tree $win.detail]
    ttk::button $win.toolbar.refresh -text "Obnovit" -command [list ::qemu::refreshMockInventoryUI $win.tree $win.detail]
    pack $win.toolbar.new $win.toolbar.refresh -side left -padx 3 -pady 3
    grid $win.toolbar -row 0 -column 0 -sticky w
    set tree [ttk::treeview $win.tree -columns {name capability state} -show headings -selectmode browse]
    $tree heading name -text "Název"
    $tree heading capability -text "Capability"
    $tree heading state -text "Stav"
    $tree column name -width 160
    $tree column capability -width 120
    $tree column state -width 80
    text $win.detail -height 6 -wrap word -state disabled
    bind $tree <<TreeviewSelect>> [list ::qemu::showMockDetail $tree $win.detail]
    grid $tree -row 1 -column 0 -sticky news -padx 4 -pady 4
    grid $win.detail -row 2 -column 0 -sticky news -padx 4 -pady 4
    grid rowconfigure $win 1 -weight 1
    grid rowconfigure $win 2 -weight 1
    grid columnconfigure $win 0 -weight 1
    ::qemu::refreshMockInventoryUI $tree $win.detail
}

proc ::qemu::openSettingsDialog {} {
    variable qemuPathOverrides
    set win [toplevel .settings]
    wm title $win "Cesty k QEMU binárkám"
    set row 0
    foreach arch {x86_64 i386 aarch64 arm} {
        ttk::label $win.l$row -text "qemu-system-$arch"
        ttk::entry $win.e$row -textvariable ::qemu::qemuPathOverrides($arch)
        grid $win.l$row -row $row -column 0 -sticky w -padx 4 -pady 2
        grid $win.e$row -row $row -column 1 -sticky we -padx 4 -pady 2
        incr row
    }
    ttk::button $win.close -text "Zavřít" -command [list destroy $win]
    grid $win.close -row $row -column 0 -columnspan 2 -pady 6
    grid columnconfigure $win 1 -weight 1
}

proc ::qemu::mainUi {} {
    ensureStorage
    loadAll
    ttk::frame .main -padding 6
    pack .main -fill both -expand 1
    ttk::label .main.title -text "QEMU Správce VM" -font "TkDefaultFont 12 bold"
    pack .main.title -anchor w -pady 4

    ttk::frame .main.toolbar
    ttk::button .main.toolbar.new -text "Nový" -command [list ::qemu::openVmForm new]
    ttk::button .main.toolbar.edit -text "Upravit" -command {
        set sel [.main.list selection]
        if {$sel eq ""} { return }
        set vm [::qemu::getVmById [lindex $sel 0]]
        ::qemu::openVmForm edit [lindex $sel 0] $vm
    }
    ttk::button .main.toolbar.del -text "Smazat" -command {
        set sel [.main.list selection]
        if {$sel eq ""} { return }
        set vm [::qemu::getVmById [lindex $sel 0]]
        if {[tk_messageBox -type yesno -icon question -title "Smazat VM" \
            -message "Opravdu smazat VM [dict get $vm name]?"] eq "yes"} {
            ::qemu::deleteVm [lindex $sel 0]
        }
    }
    ttk::button .main.toolbar.start -text "Start" -command {
        set sel [.main.list selection]
        if {$sel eq ""} { return }
        set vm [::qemu::getVmById [lindex $sel 0]]
        ::qemu::startVm $vm
    }
    ttk::button .main.toolbar.cmd -text "Příkaz" -command {
        set sel [.main.list selection]
        if {$sel eq ""} { return }
        set vm [::qemu::getVmById [lindex $sel 0]]
        ::qemu::showCommand $vm
    }
    ttk::button .main.toolbar.settings -text "Nastavení QEMU cest" -command ::qemu::openSettingsDialog
    ttk::button .main.toolbar.logs -text "Logy" -command ::qemu::openLogViewer
    ttk::button .main.toolbar.mock -text "Mock backend" -command ::qemu::openMockBackendWindow
    ttk::button .main.toolbar.diag -text "Export diagnostiky" -command {
        ::qemu::enqueueJob diagnostics_export [dict create dest ""]
    }
    pack .main.toolbar.new .main.toolbar.edit .main.toolbar.del \
        .main.toolbar.start .main.toolbar.cmd .main.toolbar.settings \
        .main.toolbar.logs .main.toolbar.mock .main.toolbar.diag \
        -side left -padx 3
    pack .main.toolbar -fill x -pady 4

    ttk::panedwindow .main.pw -orient vertical
    pack .main.pw -fill both -expand 1

    ttk::frame .main.listFrame
    set tree [ttk::treeview .main.list -columns {name arch cpu ram accel display} -show headings -selectmode browse]
    .main.list heading name -text "Název"
    .main.list heading arch -text "Arch"
    .main.list heading cpu -text "CPU"
    .main.list heading ram -text "RAM (MB)"
    .main.list heading accel -text "Accel"
    .main.list heading display -text "Display"
    .main.list column name -width 180
    .main.list column arch -width 70
    .main.list column cpu -width 60
    .main.list column ram -width 90
    .main.list column accel -width 90
    .main.list column display -width 90
    bind .main.list <<TreeviewSelect>> ::qemu::selectVm
    pack .main.list -fill both -expand 1
    .main.pw add .main.list -weight 3

    ttk::frame .main.detail
    ttk::label .main.detail.label -text "Detaily VM"
    text .main.detail.text -height 8 -wrap word -state disabled
    pack .main.detail.label -anchor w
    pack .main.detail.text -fill both -expand 1
    .main.pw add .main.detail -weight 2

    ttk::frame .main.status -padding {4 2}
    ttk::label .main.status.label -text $::qemu::statusMessage
    ttk::progressbar .main.status.progress -length 200 -mode determinate -maximum 100 -value $::qemu::statusProgress
    pack .main.status.label .main.status.progress -side left -padx 3
    pack .main.status -fill x

    refreshVmList
}

if {!$::qemu::headless} {
    ::qemu::mainUi
}
