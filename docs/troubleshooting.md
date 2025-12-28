# Troubleshooting

- **Tk not available**: ensure `tk` package is installed; on headless hosts use X11 forwarding or VNC/SPICE output from guests.
- **No drivers visible**: verify manifests exist under `src/drivers` and JSON parses; check console logs for load errors.
- **No KVM acceleration**: confirm `/dev/kvm` exists and user is in the appropriate group; containers need `--device /dev/kvm`.
- **Display issues**: on Wayland, export `XDG_RUNTIME_DIR` and pass `-v /run/user/<uid>/wayland-0` to Docker; on X11 set `DISPLAY` and share `~/.Xauthority`.
- **Networking problems**: for TAP/bridge inside containers, add `--cap-add NET_ADMIN` and `--device /dev/net/tun` or use host networking.
- **Dry-run expected**: future commands will honor `-dryRun`; current scaffold logs intent only.
