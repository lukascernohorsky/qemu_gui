# Návrh multiplatformní Tcl/Tk GUI aplikace pro QEMU

Tento dokument shrnuje klíčové spouštěcí parametry QEMU pro architektury x86 (i386/x86_64) a ARM (armv7/aarch64) a navrhuje desktopovou aplikaci v Tcl/Tk, která tyto možnosti zpřístupní přes grafické rozhraní napříč platformami (Linux, Windows, FreeBSD, NetBSD).

## Klíčové parametry QEMU (x86/ARM)

### Základní konfigurace VM
- **Binárka a typ stroje**: `qemu-system-x86_64`, `qemu-system-i386`, `qemu-system-aarch64`, `qemu-system-arm`; `-machine pc|q35|virt` (ARM obvykle `virt`).
- **Firmware**: integrovaný SeaBIOS, UEFI/OVMF přes `-bios` nebo `-drive if=pflash,...` (ARM vyžaduje firmware nebo `-kernel` + `-dtb`).
- **CPU a SMP**: `-cpu host|model`, `-smp <count>[,sockets=][,cores=][,threads=]`.
- **RAM**: `-m <size>` (výchozích 128 MiB je nedostatečných).
- **Akcelerace**: `-accel kvm|whpx|nvmm|hvf|xen` nebo zkratka `-enable-kvm` na Linuxu.
- **Boot**: `-boot order=c|d|n`, `-boot menu=on` pro BIOS menu.

### Disky a média
- **Formáty**: `raw` (výkon, pevná velikost) vs. `qcow2` (dynamika, snapshoty) + další (VDI, VMDK, VHDX).
- **Vytváření/konverze**: `qemu-img create -f qcow2 file.qcow2 20G`, `qemu-img convert`, `qemu-img resize`.
- **Připojení**: `-drive file=...,format=...,if=ide|virtio|scsi,media=disk|cdrom`; zkratka `-cdrom iso`. Virtio rozhraní pro výkon.
- **Install z ISO**: kombinace `-cdrom installer.iso` + `-boot order=d` + datový disk.

### Snapshoty
- **Dočasný**: `-snapshot` (změny v /tmp, možnost `commit` v monitoru).
- **Interní qcow2**: `savevm/loadvm/delvm` v monitoru, `info snapshots` pro seznam.
- **Externí**: overlay přes `qemu-img snapshot -c` nebo `blockdev-snapshot-sync`; sloučení `qemu-img commit`/`block-commit`.

### Síť
- **Režimy**: `-nic user` (NAT), `-nic bridge,br=...` nebo `-nic tap,...` pro bridged, více NIC opakováním parametru.
- **Modely karet**: `virtio-net-pci` (výchozí pro moderní OS), `e1000`, `rtl8139` aj.
- **Port forwarding**: `-nic user,hostfwd=tcp::2222-:22`.

### Grafika a zobrazení
- **Adaptéry**: `-vga std|virtio|qxl|cirrus|vmware|none`.
- **Zobrazení**: `-display sdl|gtk|curses|none`, `-nographic`, `-vnc :0`, `-spice ...`.
- **Headless**: kombinace `-display none`/`-nographic` + vzdálený přístup (VNC/SPICE/serial).

## Návrh funkcí GUI
1. **Předvolby VM**: šablony (např. „PC BIOS“, „PC UEFI/Q35“, „ARM virt UEFI“) předvyplňují stroj, firmware, grafiku, síť.
2. **Správa disků**: tvorba/konverze/resize přes `qemu-img`, přidání stávajících obrazů, volba formátu a rozhraní (IDE/SATA/Virtio/SCSI), readonly/snapshot režim.
3. **Instalace z ISO**: průvodce pro ISO + cílový disk, automatické nastavení boot order, volitelné přepnutí zpět na boot z disku.
4. **Snapshoty**: seznam snapshotů (interní qcow2, případně externí overlay), akce vytvořit/obnovit/smazat, checkbox „Spustit v režimu snapshot“ (`-snapshot`).
5. **Spouštění a ovládání**: tlačítka Start/Pause/Resume/Shutdown; ACPI shutdown přes monitor/QMP, nouzové ukončení procesu, log výstupu; volitelný QMP socket pro pokročilé příkazy.
6. **Multiplatformnost**: autodetekce OS a dostupných akcelerátorů (KVM/WHXP/NVMM/HVF); konfigurace cest k binárkám QEMU/qemu-img; omezení nepodporovaných voleb dle platformy (např. bridge na Windows).
7. **Pokročilé volby**: textové pole pro dodatečné parametry, nastavení monitoru/QMP, sériová konzole, výběr headless vs. grafické okno.

## Uživatelské rozhraní
- **Hlavní okno**: seznam VM (jméno, stav, CPU/RAM/poznámka), akce Nový/Upravit/Smazat/Start/Stop.
- **Dialog VM** (záložky nebo sekce):
  - Základní: jméno, architektura, profil, RAM, CPU.
  - CPU/Akcelerace: volba modelu CPU, přepínač akcelerace (mapuje na `-accel` dle OS).
  - Disky: seznam zařízení, přidání/odebrání, tvorba nového obrazu, volba boot pořadí, readonly.
  - ISO/Boot: výběr ISO, nastavení boot order, možnost boot menu.
  - Síť: režim (user/bridge/tap/none), model NIC, port forwarding, MAC.
  - Grafika: VGA typ, výstup (SDL/GTK/VNC/SPICE), headless mód.
  - Pokročilé: extra parametry, monitor/QMP, sériová konzole.
- **Dialog diskového obrazu**: cesta, formát (raw/qcow2/…), velikost, specifické volby formátu (např. preallocation u qcow2).
- **Okno snapshotů**: tabulka jméno/čas/popis, tlačítka vytvořit/obnovit/smazat, indikace aktivního snapshotu.

## Ukládání konfigurace
- **Per-VM soubor** (JSON/YAML/Tcl dict): obsahuje název, arch, machine, RAM/CPU, akceleraci, seznam disků (cesta/format/if/boot/readonly), ISO, boot order, síť (režim, model, hostfwd), grafiku (vga/display), snapshot režim, volitelné poznámky.
- **Adresářová struktura**: doporučený kořen (např. `~/QEMU/` nebo `C:\Users\Name\QEMU\`); každé VM má podadresář s konfigurací, disky, logy.
- **Relativní cesty**: ukládat cesty relativně k adresáři VM pro snadnější přesun mezi stroji.
- **Snapshot metadata**: dynamicky načítat (`qemu-img snapshot -l`, `query-snapshots` přes QMP); do konfigurace ukládat jen uživatelské popisy.

## Spouštění procesů
- **Generování příkazové řádky**: sestavení seznamu argumentů dle konfigurace (správné escapování cest, uvozovky pro Windows), zobrazení výsledného příkazu pro diagnostiku.
- **Spuštění QEMU**: `exec` na pozadí, zachytávání stdout/stderr do logu; indikace běhu, návratového kódu, případně automatické otevření VNC/okna.
- **Ovládání za běhu**: QMP socket (`-qmp unix:...` nebo `-qmp tcp:...,server,nowait`) pro příkazy stop/cont/system_powerdown/savevm/loadvm; fallback nouzového kill.
- **qemu-img operace**: synchronní volání create/convert/resize/info s progress (parametr `-p`), zobrazení chybových hlášek.
- **Validace dostupnosti binárek**: při startu nebo před akcí ověřit existenci a spustitelnost QEMU/qemu-img, nabídnout nastavení cesty.

## Kompatibilita a UX
- Respektovat rozdíly platforem (akcelerátory, síťový bridge, dostupnost SPICE/VNC).
- Vstupní validace (neprázdné jméno, velikost disku > 0, existující cesty), uživatelsky srozumitelná hlášení.
- Logování a možnost zapnout verbose mód (zobrazit příkaz + výstup QEMU/qemu-img).
- Distribuce: Tcl/Tk skript s volitelným starpackem pro Windows; na Unix/BSD očekává QEMU v PATH nebo ručně zadanou cestu.
