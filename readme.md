# Návrh multiplatformní Tcl/Tk GUI aplikace pro QEMU

Tento dokument shrnuje klíčové spouštěcí parametry QEMU pro architektury x86 (i386/x86_64) a ARM (armv7/aarch64) a navrhuje desktopovou aplikaci v Tcl/Tk, která tyto možnosti zpřístupní přes grafické rozhraní napříč platformami (Linux, Windows, FreeBSD, NetBSD).

## Struktura repozitáře a MVP kostra
- **Entrypoint**: `qemu_gui.tcl` pouze načítá `src/app.tcl`.
- **UI** (`src/app.tcl`): ttk-first hlavní okno s toolbar, stromem připojení/VM a detailem (Summary/Logs), automatická volba tématu dle platformy a volitelný scaling přes `TK_SCALE`.
- **Core** (`src/core`): jednoduchý logger, exec wrapper (argv-first, dry-run), loader manifestů pluginů.
- **Drivery** (`src/drivers/mock`): manifest + TclOO třída `Driver` se statickou inventurou pro deterministické demo/CI.
- **Dokumentace**: kostry v `docs/` (architektura, backends, command-mapping, security, packaging, troubleshooting, dev-setup).
- **Balíčky**: šablony pro deb/rpm/arch/gentoo/FreeBSD/NetBSD/OpenBSD v `packaging/`.

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

## Spuštění referenční GUI aplikace

V kořenovém adresáři repo je přiložený prototyp `qemu_gui.tcl`, který pokrývá základ návrhu:

1. Spusťte Tcl/Tk (vyžaduje `tclsh` 8.6+ s Tk): `tclsh qemu_gui.tcl` (wrapper načte `src/app.tcl`).
2. Po startu se načte mock driver a strom připojení/VM zobrazí dvě vzorové VM. Toolbar obsahuje akce New/Start/Stop/Force/Delete/Open Console/Open SSH Terminal/Refresh/Preferences (nyní logují události a refreshují strom).
3. Detailní panel zobrazuje přehled vybrané položky, záložka Logs slouží pro budoucí výstup operací.
4. Volba tématu probíhá automaticky dle platformy (Win: vista/xpnative, macOS: aqua, Unix: yaru/arc/clam fallback), scaling lze nastavit proměnnou prostředí `TK_SCALE`.

Původní návrh formulářů/parametrů VM zůstává referenční pro další iterace: příkazová řádka QEMU se má generovat z konfigurace ( `-machine`, `-accel`, `-cpu`, `-smp`, `-m`, `-boot`, `-bios`/firmware, `-vga`, `-display`, `-snapshot`, `-drive` pro každé zařízení, `-cdrom` pokud je ISO, `-nic` pro každou síť a dodatečné parametry). 

## Spuštění a práce s Dockerem

Pro snadné vyzkoušení nebo oddělení závislostí lze GUI i QEMU spustit v kontejneru. Základní kroky:

1. **Build image** (příklad pro Debian/Ubuntu base s Tcl/Tk a QEMU):

   ```Dockerfile
   FROM debian:stable-slim
   RUN apt-get update && apt-get install -y \
       tcl tk qemu-system-x86 qemu-utils openssh-client && \
       apt-get clean && rm -rf /var/lib/apt/lists/*
   WORKDIR /opt/virt-tk
   COPY . /opt/virt-tk
   CMD ["tclsh", "/opt/virt-tk/qemu_gui.tcl"]
   ```

2. **Spuštění s přístupem k akceleraci a displeji**:

   ```bash
   docker run --rm -it \
     --device /dev/kvm \
     -e DISPLAY=$DISPLAY \
     -v /tmp/.X11-unix:/tmp/.X11-unix \
     -v "$HOME/.Xauthority:/root/.Xauthority:ro" \
     -v "$PWD/vms:/opt/virt-tk/vms" \
     --name virt-tk-gui \
     virt-tk-manager:local
   ```

   - `--device /dev/kvm` je volitelné, pokud chcete KVM; bez něj poběží QEMU bez akcelerace.
   - Pro Wayland/pipewire kompozitory použijte ekvivalentní přístup (např. `XDG_RUNTIME_DIR` a `wayland-0`).
   - Mapování `vms` adresáře zachová konfigurace a obrazy mezi běhy kontejneru.

3. **Síť a rozhraní**:
   - Pro bridged nebo TAP režimy je třeba předat příslušná rozhraní (`--network host` nebo `--cap-add NET_ADMIN` + `--device /dev/net/tun`).
   - U přesměrování portů z `-nic user,hostfwd` obvykle vystačí implicitní NAT Dockeru; pro VNC/SPICE se často hodí `--network host`.

4. **Bezpečnostní poznámky**:
   - Přístup k `/dev/kvm` a síťovým schopnostem zvyšuje privilegia kontejneru; používejte jen na důvěryhodných hostech.
   - Pokud potřebujete přístup k lokálnímu úložišti ISO/disků, přidejte odpovídající `-v` bind mounty.

5. **Debug a logy**:
   - Výstup `tclsh qemu_gui.tcl` jde do stdout/stderr kontejneru; pro per-VM logy zachovejte perzistentní bind mount do `vms/`.
   - Pro nenativní GUI (headless host) lze místo X11 použít VNC/SPICE z QEMU nebo předat Xvfb/XPRA podle potřeby.
