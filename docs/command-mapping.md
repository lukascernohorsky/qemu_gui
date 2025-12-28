# Command Mapping (skeleton)

## Principles
- argv-first invocation, no shell concatenation.
- Default timeout and rc mapping per command id.
- Dry-run returns structured argv without execution.

## Mock Driver
- No external commands; returns deterministic data.

## Planned Command Registry Examples
- `qemu.start`: argv builder from VM definition -> `qemu-system-<arch> ...`, timeout 120s, dry-run supported, privilege optional (pkexec/sudo fallback).
- `qemu.stop`: prefer QMP powerdown, fallback `kill -TERM`, timeout 30s.
- `lxc.list`: `lxc-ls --fancy` parse to inventory.
- `xen.list`: `xl list` parse to guest list; rc!=0 -> `Unsupported` or `PermissionDenied` depending on stderr pattern.
- `jail.list`: `jls -n` parse to dict rows; rc!=0 -> error taxonomy.

## Error Taxonomy (planned)
- PermissionDenied, NotFound, InvalidConfig, Busy, Timeout, Unsupported, ParseError.
