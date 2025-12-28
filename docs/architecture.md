# Architecture Overview

This repository scaffolds a Tcl/Tk application named **virt-tk-manager** that follows a virt-manager-like UX while keeping a plugin-based backend model.

## Layers
- **UI layer (`src/app.tcl`)**: ttk-first layout with toolbar, tree/detail panes, notebooks for summary/logs/history. Theme selection favors native look per platform. Toolbar actions are wired to job execution (currently against the mock backend).
- **Core modules (`src/core`)**:
  - `logger.tcl`: lightweight logger with leveled output and optional file target.
  - `exec.tcl`: argv-first command runner with dry-run support, timeout, and temporary env overrides.
  - `commands.tcl`: command registry for backend operations, including privilege and `supports_dry_run` flags (mock commands seeded).
  - `jobs.tcl`: minimal job runner/history that honors dry-run support per command and records results for UI logs.
  - `plugin_loader.tcl`: manifest loader + driver instantiation helper.
  - `diagnostics.tcl`: collects app/drivers/connections/jobs/logs into a JSON bundle for export.
- **Drivers (`src/drivers/*`)**: each backend has a `manifest.json` and `driver.tcl` implementing required methods (`detect`, `capabilities`, `inventory`, `guest_actions`, `console_info`, `command_for_action`). A deterministic `mock` driver seeds the UI for CI and offline demos.

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
- **Actions**: toolbar buttons call `runGuestAction` which resolves driver action -> command-id -> job run (dry-run toggle in Preferences). Console action shows viewer hints; Logs tab shows recent command outcomes, History tab shows persisted job records, logs can be saved to a file, and diagnostics export produces a JSON report.

## Job/Task and Operations Queue (planned)
- Future modules will add a job controller for async operations, per the acceptance criteria (dry-run, rollback hooks, diagnostics bundle). Current scaffold logs intent only.

## Theme and Scaling
- Native theme preference per windowing system (Win32: vista/xpnative, macOS: aqua, Unix: yaru/arc/clam fallback).
- Optional scaling via `TK_SCALE` environment variable.

## Testing and CI (planned)
- `mock` driver provides deterministic data for tcltest-based suites (parsers, command builders, privilege gating, port allocator). CI wiring will build on top of this structure.
