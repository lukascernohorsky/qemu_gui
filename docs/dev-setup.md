# Developer Setup

1. Install Tcl/Tk 8.6+ and tcllib.
2. Clone the repo and run from root:
   ```bash
   tclsh qemu_gui.tcl
   ```
3. Modules live under `src/`:
   - UI entrypoint: `src/app.tcl`
   - Core helpers: `src/core/*.tcl` (logger, exec, command registry, jobs, plugin loader)
   - Drivers: `src/drivers/<name>/manifest.json` + `driver.tcl`
4. Add a new driver:
   - Create `src/drivers/<id>/manifest.json` with metadata and class name.
   - Implement a TclOO class exposing `detect`, `capabilities`, `inventory`, `guest_actions`, `console_info`, `command_for_action`.
   - Ensure deterministic outputs for CI and add tcltest cases (planned under `tests/`).
5. Packaging:
   - Use templates under `packaging/`; update version and checksum fields before builds.
6. Docker run (example):
   ```bash
   docker build -t virt-tk-manager:local .
   docker run --rm -it \
     --device /dev/kvm \
     -e DISPLAY=$DISPLAY \
     -v /tmp/.X11-unix:/tmp/.X11-unix \
     -v "$HOME/.Xauthority:/root/.Xauthority:ro" \
     -v "$PWD/vms:/opt/virt-tk/vms" \
     virt-tk-manager:local
   ```
