# OpenMPTCProuter Development Guide

Quick reference for developers working on the codebase.

## Build System Overview

### Quick Start

```bash
# Basic x86_64 build (default)
./build.sh

# Build for specific target
OMR_TARGET=rpi4 OMR_KERNEL=6.6 ./build.sh

# List all available targets
ls config-* | sed 's/config-//'
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OMR_TARGET` | `x86_64` | Hardware target (see `config-*` files) |
| `OMR_KERNEL` | `5.4` | Kernel version (5.4, 6.1, 6.6, 6.10, 6.12) |
| `OMR_PACKAGES` | `full` | Package set (`full` or `minimal`) |
| `OMR_KEEPBIN` | `no` | Keep binary output between builds |
| `OMR_IMG` | `yes` | Generate firmware images |

### Build Flow

```
build.sh
  |
  +-- 1. Validate dependencies (git, curl, make, etc.)
  +-- 2. Check disk space (30GB minimum)
  +-- 3. Map target -> architecture (OMR_REAL_TARGET)
  +-- 4. Clone/update OpenWrt sources (version-specific commit)
  +-- 5. Clone/update feeds (packages, luci, routing)
  +-- 6. Copy overlays:
  |       common/* -> source/
  |       ${OMR_KERNEL}/* -> source/
  +-- 7. Apply patches from patches/
  +-- 8. Configure feeds.conf
  +-- 9. Run OpenWrt build
  +-- 10. Output to: ${OMR_TARGET}/${OMR_KERNEL}/source/bin/
```

## Directory Structure

```
openmptcprouter/
├── build.sh              # Main build entry point
├── config-*              # Target configs (31 platforms)
├── common/               # Files shared across all kernel versions
│   ├── files/            # Root filesystem overlay
│   └── package/          # Custom packages
├── 5.4/, 6.1/, 6.6/, 6.12/  # Kernel-specific overrides
├── patches/              # System patches (BBR2, UEFI, etc.)
├── scripts/              # Build/setup helper scripts
└── vps-scripts/          # VPS installation scripts
```

## Key Files

- **`scripts/omr-lib.sh`**: Shared shell library with logging, validation, UI helpers
- **`common/files/etc/uci-defaults/`**: First-boot initialization scripts
- **`common/files/usr/bin/`**: Utility scripts deployed to router
- **`common/package/modems/`**: USB modem device profiles

## Adding a New Target

1. Create `config-<target>` in repo root with OpenWrt Kconfig
2. Add target to architecture mapping in `build.sh` (lines ~103-122)
3. Add any target-specific files in `common/target/` or kernel directories
4. Test build: `OMR_TARGET=<target> ./build.sh`

## Adding a New Script

Use `omr-lib.sh` for consistent UI:

```bash
#!/bin/sh
# Source the library
. "$(dirname "$0")/omr-lib.sh" || . /usr/share/omr/omr-lib.sh

# Use provided functions
omr_log_header "My Script"
omr_log_info "Starting..."

if omr_ask_yes_no "Continue?"; then
    omr_progress_start "Doing work"
    # ... do work ...
    omr_progress_done
fi
```

## Testing

```bash
# Validate scripts for syntax errors
./scripts/validate-scripts.sh

# Run health check
./scripts/omr-health-check.sh

# Smoke test (requires built firmware)
./scripts/smoke-test.sh
```

## Common Tasks

### Updating OpenWrt Base

Edit commit hashes in `build.sh` (lines ~127-143) for the appropriate kernel version.

### Adding a Patch

1. Create patch file in `patches/`
2. Add patch application logic in `build.sh` (around line ~520+)
3. Use `patch -N -p1 -s` for silent, non-failing application

### Modifying UCI Defaults

Edit files in `common/files/etc/uci-defaults/`:
- Files run in numeric order (05, 10, 15...)
- Must be executable and return 0 on success
- Return non-zero to be re-run on next boot

## Coding Standards

- Shell scripts: POSIX sh compatible where possible
- Use `set -e` for fail-fast behavior
- Quote all variables: `"$VAR"` not `$VAR`
- Validate inputs before use
- Use `omr-lib.sh` functions for user interaction

## Resources

- [README.md](README.md) - User documentation
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Setup instructions
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
