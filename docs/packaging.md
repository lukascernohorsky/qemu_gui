# Packaging & Release (overview)

## Runtime Dependencies
- Tcl 8.6+, Tk/ttk
- tcllib (json/http for future downloader)
- tcltls (planned for HTTPS with TLS)
- openssh-client (for planned SSH transport)

Optional: vncviewer/remote-viewer/screen for consoles; gpg/minisign for signature verification.

## Build/Release Steps
1. Tag release: `git tag -a v0.2.0 -m "virt-tk-manager v0.2.0" && git push --tags`.
2. Create source tarball: `git archive --format=tar.gz -o virt-tk-manager-v0.2.0.tar.gz HEAD`.
3. Build desired packages using templates below.

## Debian/Ubuntu
- Files: `packaging/debian/control`, `packaging/debian/rules`, `packaging/debian/compat`.
- Build deps: `debhelper`, `dh-exec`.
- Build: `dpkg-buildpackage -us -uc` from repo root.

## RHEL/Fedora/openSUSE
- Spec template: `packaging/rpm/virt-tk-manager.spec`.
- Build: `rpmbuild -ba packaging/rpm/virt-tk-manager.spec` (set `%_sourcedir` to repo root).
- OBS: use same spec with service file to pull tarball.

## Arch Linux
- `packaging/arch/PKGBUILD`; build via `makepkg -si`.

## Gentoo
- `packaging/gentoo/virt-tk-manager.ebuild`; install with `ebuild virt-tk-manager.ebuild manifest` then `emerge --ask =virt-tk-manager-0.2.0`.

## FreeBSD
- Ports skeleton under `packaging/freebsd/ports`; build with `make install clean` inside the port directory; poudriere uses same files.

## NetBSD pkgsrc
- `packaging/netbsd/pkgsrc/Makefile` with distinfo placeholders; build via `bmake install`.

## OpenBSD ports
- Skeleton under `packaging/openbsd/ports`; build via `make install` from the port directory.

## Post-install Notes
- Users running KVM need access to `/dev/kvm` (group membership or udev rules).
- When enabling remote privilege escalation, configure sudo/doas/pkexec policies explicitly; the app will not auto-escalate.
- Desktop integration: future releases will install a `.desktop` file and icon into the appropriate prefix (`/usr/share` on Linux, `/usr/local/share` on BSDs).
