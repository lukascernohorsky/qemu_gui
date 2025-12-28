# Backends and Capabilities

## Mock Driver (implemented)
- Purpose: deterministic inventory for CI/demos without hypervisors.
- Detect: always available with version `mock-1.0`.
- Capabilities: guests, storage, networks, consoles all set to true.
- Inventory: two guests (stopped/running), one storage pool, one network.
- Actions: start, stop, force, delete, console (no side effects yet).

## Planned Drivers (per product brief)
- **QEMU/KVM**: detect qemu-system binaries, qemu-img, /dev/kvm access; inventory managed/unmanaged VMs from JSON definitions; actions include start/stop/force, snapshot via qemu-img, console via VNC/SPICE/serial.
- **Xen (xl)**: detect `xl`; inventory via `xl list`; start via `xl create`, shutdown/destroy; console via `xl console`.
- **LXC**: detect `lxc-*`; inventory via `lxc-ls`/`lxc-info`; start/stop/freeze; attach shell; import existing configs.
- **bhyve (FreeBSD)**: detect `/dev/vmm`, `bhyve`, `bhyvectl`, optional `vm-bhyve`; start/stop/destroy; serial/VNC console best-effort.
- **FreeBSD Jails**: detect `jail`/`jls`/`jexec`; list/start/stop; template-based creation; optional Bastille/iocage adapters.

Each driver will provide a manifest in `src/drivers/<name>/manifest.json` and a TclOO class implementing the core API. Capability keys align to: guests, storage, networks, consoles, snapshots, templates, import, performance.
