# Architecture Overview

This repository scaffolds a Tcl/Tk application named **virt-tk-manager** that follows a virt-manager-like UX while keeping a plugin-based backend model.

## Layers
- **UI layer (`src/app.tcl`)**: ttk-first layout with toolbar, tree/detail panes, notebooks for summary/logs. Theme selection favors native look per platform.
- **Core modules (`src/core`)**:
  - `logger.tcl`: lightweight logger with leveled output and optional file target.
  - `exec.tcl`: argv-first command runner with dry-run support and timeout placeholder.
  - `plugin_loader.tcl`: manifest loader + driver instantiation helper.
- **Drivers (`src/drivers/*`)**: each backend has a `manifest.json` and `driver.tcl` implementing required methods (`detect`, `capabilities`, `inventory`, `guest_actions`, `console_info`). A deterministic `mock` driver seeds the UI for CI and offline demos.

## Plugin API Skeleton
- Manifest keys: `id`, `name`, `entrypoint`, `class`, `os_support`, `binaries`, `devices`, `services`, `capabilities_keys`, `priority`, `supports_import`, `supports_templates`, `supported_install_media`.
- Driver class is expected to expose:
  - `detect hostCtx -> {available bool reasons {} version_info {...}}`
  - `capabilities hostCtx -> dict`
  - `inventory -> dict guests/storage/networks`
  - `guest_actions id -> list`
  - `console_info id -> dict {type host port viewer_hint command copyable_uri}`

## UI Model
- **Connections**: derived from loaded drivers; each driver maps to a local connection (placeholder until SSH transport is added).
- **Objects**: guests, storage pools, and networks rendered in a tree. Detail panel shows summary and logs.
- **Actions**: toolbar buttons emit audit-friendly log messages; wiring to real operations is staged.

## Job/Task and Operations Queue (planned)
- Future modules will add a job controller for async operations, per the acceptance criteria (dry-run, rollback hooks, diagnostics bundle). Current scaffold logs intent only.

## Theme and Scaling
- Native theme preference per windowing system (Win32: vista/xpnative, macOS: aqua, Unix: yaru/arc/clam fallback).
- Optional scaling via `TK_SCALE` environment variable.

## Testing and CI (planned)
- `mock` driver provides deterministic data for tcltest-based suites (parsers, command builders, privilege gating, port allocator). CI wiring will build on top of this structure.
