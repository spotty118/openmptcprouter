# OpenMPTCProuter Optimized - Comprehensive Codebase Analysis

**Generated**: 2025-11-18  
**Repository**: /home/user/openmptcprouter  
**Current Branch**: claude/investigate-wan-bonding-016naqeb3SXTai5FAMt4JjGY  
**Git Status**: Clean (no uncommitted changes)

---

## TABLE OF CONTENTS

1. [Overall Directory Structure](#1-overall-directory-structure)
2. [Key Configuration Files](#2-key-configuration-files)
3. [Scripts & Daemons](#3-scripts--daemons)
4. [Kernel & MPTCP Configuration](#4-kernel--mptcp-configuration)
5. [VPN/Tunnel Configuration](#5-vpntunnel-configuration)
6. [VPS-Side vs Client-Side Code](#6-vps-side-vs-client-side-code-separation)
7. [Testing & Documentation](#7-testing--documentation)
8. [Known Issues & Patterns](#8-known-issues--patterns)

---

## 1. OVERALL DIRECTORY STRUCTURE

### Root-Level Organization

```
/home/user/openmptcprouter/
├── common/                          # Shared files for all kernel versions
│   ├── files/                       # Runtime files (configs, scripts)
│   ├── package/                     # Package definitions and patches
│   ├── scripts/                     # Build-time scripts
│   ├── target/                      # Device-specific configs
│   └── tools/                       # Build tools
│
├── 5.4/, 6.1/, 6.6/, 6.10/, 6.12/  # Kernel version directories
│   ├── package/                     # Version-specific packages
│   ├── target/                      # Device-specific builds
│   └── toolchain/                   # Kernel-specific toolchain
│
├── patches/                         # Kernel and package patches
├── scripts/                         # Setup and deployment scripts
├── vps-scripts/                     # VPS installation and configuration
├── build.sh (1,157 lines)          # Main build orchestration
├── quick-setup.sh (241 lines)      # Quick setup utility
├── sign.sh                          # Release signing
│
└── [Extensive documentation]        # Multiple audit reports and guides
    ├── CODEBASE_MAPPING.md
    ├── AUDIT_FINDINGS.md
    ├── BONDING_FIX_PROPOSAL.md
    ├── KERNEL_USERSPACE_INTEGRATION_REPORT.md
    ├── COMPREHENSIVE_AUDIT_SUMMARY.md
    └── [20+ other analysis documents]
```

### Device Configuration Files (35+ supported devices)

Root level contains device-specific build configs:
- **ARM Boards**: config-bpi-r1/r2/r3/r4, config-r2s/r4s/r5s, config-rpi2/3/4/5
- **x86 Systems**: config-x86, config-x86_64
- **Commercial Routers**: config-rutx, config-wrt32x, config-z8109ax_512m
- **IoT/Special**: config-espressobin, config-ubnt-erx

Each config file contains OpenWrt package selections and kernel features for that device.

---

## 2. KEY CONFIGURATION FILES

### 2.1 SYSTEM INITIALIZATION & DEFAULTS

| File | Size | Purpose |
|------|------|---------|
| `/common/files/etc/openmptcprouter/defaults.conf` | 185 lines | Global defaults (ports, MPTCP settings, WiFi config) |
| `/common/files/etc/uci-defaults/10-omr-network-defaults` | 72 lines | Initialize LAN static IP (192.168.2.1), DHCP server |
| `/common/files/etc/uci-defaults/15-omr-autoconfig-init` | 92 lines | Start network monitors, set file permissions |
| `/common/files/etc/uci-defaults/05-omr-detect-ram-buffers` | 50 lines | Auto-detect RAM and optimize network buffers |
| `/common/files/etc/uci-defaults/90-omr-first-boot-wizard` | 647 lines | Web-based setup wizard interface |

**Key Configuration Variables**:
```bash
OMR_SHADOWSOCKS_PORT=65500
OMR_GLORYTUN_TCP_PORT=65510
OMR_GLORYTUN_UDP_PORT=65520
OMR_WEB_UI_PORT=8080
OMR_PAIRING_PORT=9999
OMR_LAN_IP=192.168.2.1
OMR_MPTCP_PATH_MANAGER=fullmesh
OMR_MPTCP_SCHEDULER=default (should be 'blest')
OMR_CREDENTIAL_PERMISSIONS=600
```

### 2.2 KERNEL PARAMETER OPTIMIZATION

**File**: `/common/files/etc/sysctl.d/99-omr-mptcp-5g-optimization.conf` (212 lines)

**Critical Parameters**:

```bash
# MPTCP Core
net.mptcp.enabled = 1
net.ipv4.tcp_congestion_control = bbr2
net.mptcp.mptcp_scheduler = blest        # FIX: Better than default RTT-only
net.mptcp.mptcp_path_manager = fullmesh
net.mptcp.mptcp_checksum = 0

# TCP Keepalive - AGGRESSIVE for WAN bonding failover
# FIX 1.1: Reduced from 300/5/15 (6.25min) to 20/3/10 (50s)
net.ipv4.tcp_keepalive_time = 20          # Initial idle timeout
net.ipv4.tcp_keepalive_probes = 3         # Number of probes
net.ipv4.tcp_keepalive_intvl = 10         # Interval between probes
# Total failover time: ~50 seconds (vs 6.25 minutes default)

# TCP Retry Timeouts - FIX 1.2
net.ipv4.tcp_retries1 = 3                 # Unreachable threshold
net.ipv4.tcp_retries2 = 8                 # Connection timeout (faster failover)

# Network Buffers (balanced for multi-WAN)
net.core.rmem_max = 33554432              # 32MB max receive buffer
net.core.wmem_max = 33554432              # 32MB max send buffer
net.ipv4.tcp_rmem = 4096 87380 33554432   # Min/default/max
net.ipv4.tcp_wmem = 4096 65536 33554432

# Connection Tracking (critical for multi-WAN)
net.netfilter.nf_conntrack_max = 524288   # Support ~500k connections
net.netfilter.nf_conntrack_tcp_timeout_established = 432000  # 5 days

# RP Filter - CRUCIAL FOR MPTCP
net.ipv4.conf.default.rp_filter = 2       # Loose mode required for multi-WAN
net.ipv4.conf.all.rp_filter = 2           # (Security trade-off documented)

# Queue Discipline & UDP
net.core.default_qdisc = fq               # Pair with BBR
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# Multipath Routing
net.ipv4.fib_multipath_hash_policy = 1    # Layer 4 hashing
net.ipv6.fib_multipath_hash_policy = 1

# IP Forwarding (router mode)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
```

**CRITICAL SECURITY NOTE**:
- RP filter set to loose mode (2) instead of strict (1) to support MPTCP
- This weakens protection against IP spoofing but is required for multi-WAN
- Mitigated by firewall rules and connection tracking

### 2.3 NETWORK INTERFACE CONFIGURATION

**Location**: UCI (Unified Configuration Interface) configuration handled by:
- `/common/files/etc/uci-defaults/10-omr-network-defaults`
- Web UI at `http://192.168.2.1`

**Key UCI Paths**:
```bash
network.lan.proto=static
network.lan.ipaddr=192.168.2.1
network.lan.netmask=255.255.255.0
dhcp.lan.start=100
dhcp.lan.limit=150
dhcp.@dnsmasq[0].cachesize=1000
```

---

## 3. SCRIPTS & DAEMONS

### 3.1 ROUTER-SIDE MONITORING DAEMONS

| File | Lines | Executable | Purpose |
|------|-------|-----------|---------|
| `/common/files/etc/init.d/mptcp-manager` | 37 | ✓ | Init script starting metrics exporter & path manager |
| `/common/files/usr/bin/mptcp-path-manager` | 318 | ✓ | Intelligent path state management with hysteresis |
| `/common/files/usr/bin/mptcp-metrics-exporter` | 150+ | ✓ | Collect link quality metrics (loss, signal, latency) |
| `/common/files/usr/bin/network-monitor.sh` | 114 | ✓ | Health check for DHCP & network connectivity |
| `/common/files/usr/bin/network-safety-monitor.sh` | 314 | ✓ | Prevents user lockout via misconfiguration |
| `/common/files/usr/bin/omr-status` | 360+ | ✓ | Status dashboard for all WAN connections |
| `/common/files/usr/bin/omr-diagnostics` | 150+ | ✓ | Comprehensive network diagnostics |
| `/common/files/usr/bin/omr-recovery` | 100+ | ✓ | Emergency recovery utility |

**Key Daemon Responsibilities**:

**mptcp-manager** (init.d script):
- START=99, STOP=10 (late startup, early shutdown)
- Manages two instances:
  1. `mptcp-metrics-exporter` - collects interface metrics
  2. `mptcp-path-manager` - manages path health state

**mptcp-path-manager** (main daemon):
```
HYSTERESIS_TIME=30s        # Require 30s stability before marking healthy
CHECK_INTERVAL=5s          # Check every 5 seconds
BLACKLIST_THRESHOLD=5      # 5 failures triggers blacklist
BLACKLIST_WINDOW=300s      # 5-minute observation window
BLACKLIST_DURATION=300s    # Blacklist for 5 minutes
DEGRADED_THRESHOLD=500     # 5% packet loss threshold
```

**Implementation Details**:
- Monitors `/sys/class/net/*/operstate` for interface state
- Tracks path state in `/var/run/mptcp-paths/`
- Applies metric penalties via UCI to degrade unreliable paths
- Implements 3 fix layers:
  1. Path Recovery (FIX 2.1) - hysteresis to prevent flapping
  2. Path Blacklisting (FIX 2.2) - permanent exclusion of chronic failures
  3. Path Degradation (FIX 3.2) - temporary penalty for lossy links

**network-safety-monitor.sh**:
- Detects APIPA (169.254.x.x) addresses - indicates failed DHCP
- Validates LAN has at least one physical port
- Checks LAN accessibility every 30 seconds
- Triggers emergency recovery if misconfigured
- Restores to default br-lan configuration as fallback

**omr-status**:
- Queries UCI for all WAN interfaces
- Detects connection type (Ethernet, USB Modem, Cellular QMI/MBIM)
- Gets signal strength for cellular modems via uqmi/umbim
- Shows link speed, traffic stats
- Color-coded terminal output
- Caches UCI data to reduce 3x→1x calls (40-100ms optimization)

### 3.2 ROUTER SETUP & CONFIGURATION SCRIPTS

**Location**: `/scripts/` directory (4,734 lines total)

| File | Lines | Purpose |
|------|-------|---------|
| `vps-scripts/wizard.sh` | 39,532 | Self-contained VPS installation wizard (interactive) |
| `vps-scripts/omr-vps-install.sh` | 18,728 | Full VPS installation script |
| `vps-scripts/install.sh` | 2,935 | Simple VPS installer wrapper |
| `scripts/easy-install.sh` | 480 | Easy web-based installer |
| `scripts/auto-pair.sh` | 453 | Auto-pairing code generator |
| `scripts/client-auto-setup-improved.sh` | 525 | Enhanced client setup script |
| `scripts/client-auto-setup.sh` | 347 | Basic client setup |
| `scripts/omr-lib.sh` | 592 | Shared library functions (validation, logging) |
| `scripts/omr-config-manager.sh` | 381 | Configuration management utilities |
| `scripts/omr-clean.sh` | 458 | Build environment cleanup |
| `scripts/omr-health-check.sh` | 325 | Health check utilities |
| `scripts/verify-setup.sh` | 367 | Post-setup verification |
| `scripts/omr-select-platform.sh` | 316 | Device selection for builds |
| `scripts/omr-build-helper.sh` | 308 | Build environment setup |

**Key Functions in omr-lib.sh**:
```bash
log_msg()           - Standardized logging
validate_ip()       - IPv4/IPv6 validation
validate_port()     - Port range validation
validate_password() - Strong password requirements
generate_password() - Secure random password
is_root()          - Permission checking
```

### 3.3 HARDWARE AUTOCONFIGURATION

| File | Lines | Purpose |
|------|-------|---------|
| `/common/files/usr/bin/usb-modem-autoconfig.sh` | 300+ | Detect and configure USB modems |
| `/common/files/usr/bin/wifi-autoconfig.sh` | 150+ | Configure WiFi interfaces |
| `/common/files/usr/bin/port-autoconfig.sh` | 200+ | Detect and configure network ports |
| `/common/files/etc/hotplug.d/usb/20-usb-modem` | 100+ | USB hotplug handler for modems |

**Modem Detection**:
- Scans `/sys/bus/usb-serial/devices/`
- Detects QMI or MBIM protocol modems
- Auto-configures as `wwan*` interfaces
- Sets up IP protocol (dhcp/qmi/mbim)
- Enables multipath flag automatically

### 3.4 INIT.D SCRIPTS

| File | Purpose |
|------|---------|
| `/common/files/etc/init.d/mptcp-manager` | Start MPTCP path management |
| `/common/files/etc/init.d/omr-diagnostics` | Start diagnostics daemon |
| (Auto-created) `network-monitor` | Start network health monitor |

---

## 4. KERNEL & MPTCP CONFIGURATION

### 4.1 Kernel Versions Supported

```
5.4   - Legacy, stable MPTCP support (LTE modems)
6.1   - Mid-range, improved drivers
6.6   - Mature, production-ready, recommended
6.10  - Latest stable, new features
6.12  - Experimental, cutting-edge
```

### 4.2 MPTCP-Related Configuration

**MPTCP Path Manager Options**:
```
fullmesh   - All interfaces can reach all subflows (default)
ndiffports - Different local ports per subflow
binder     - Netlink-based explicit binding
```

**MPTCP Scheduler Options**:
```
default    - Lowest RTT (PROBLEM: ignores bandwidth)
roundrobin - Equal distribution (PROBLEM: ignores latency)
redundant  - Redundant subflows
blest      - ✓ RECOMMENDED - Bandwidth-latency aware (FIX 1.3)
```

### 4.3 TCP Congestion Control

**BBR vs BBR2**:
- **BBR (Bottleneck Bandwidth and Round-trip time)**
  - Estimates available bandwidth
  - Better than Reno/CUBIC for long-latency WAN
  - Reduces buffering bloat
  
- **BBR2 (Enhanced version)**
  - Includes probing gain reduction
  - Better multipath coordination
  - Recommended: `net.ipv4.tcp_congestion_control = bbr2`

### 4.4 Device-Specific Kernel Features

**Example: config-r5s** (NanoPi R5S ARM board):
```
CONFIG_TARGET_rockchip=y
CONFIG_TARGET_rockchip_armv8=y
CONFIG_KERNEL_ARM64_MODULE_PLTS=y
CONFIG_KERNEL_TCP_CONG_BBR2=y        # ← BBR2 enabled
CONFIG_CRYPTO_HW=y
CONFIG_ARM64_CRYPTO=y                # Hardware crypto offload
CONFIG_PACKAGE_kmod-gpu-lima=y       # GPU acceleration
CONFIG_PACKAGE_kmod-mt76x0u=y        # WiFi drivers
CONFIG_PACKAGE_kmod-r8125=y          # Realtek NIC drivers
```

### 4.5 Kernel Patches

**Location**: `/patches/` directory (22 patch files)

Key patches:
- `bbr2-5.15.patch` (129KB) - BBR2 backport for older kernels
- `luci-nftables.patch` - NFTables support
- `ipt-nat6.patch` - IPv6 NAT
- `uefi.patch` (45KB) - UEFI boot support for x86

---

## 5. VPN/TUNNEL CONFIGURATION

### 5.1 Supported VPN Technologies

| Technology | Port | Type | Configuration |
|------------|------|------|---------------|
| **Shadowsocks** | 65500 | TCP | Encryption: chacha20-ietf-poly1305, aes-256-gcm |
| **Glorytun TCP** | 65510 | TCP | Tunnel over TCP with aggregation |
| **Glorytun UDP** | 65520 | UDP | UDP-based tunnel (lower latency) |
| **WireGuard** | N/A | UDP | Modern, fast, kernel-space VPN |
| **MLVPN** | N/A | Custom | Multi-link VPN with reordering |
| **V2Ray/XRay** | Custom | TCP/UDP | Flexible proxy framework |

### 5.2 Default Configuration

VPS credentials file location: `/root/openmptcprouter_credentials.txt`  
VPS config: `/etc/openmptcprouter/config.json`

**Router-side UCI config** (populated by wizard):
```bash
# Stored in /etc/config/network
network.wvpn (WireGuard VPN)
network.glorytun_tcp
network.glorytun_udp
network.shadowsocks (primary tunnel)
```

### 5.3 Tunnel Configuration Process

1. **VPS Setup Phase** (`wizard.sh` on VPS):
   - Detects public IP
   - Generates secure random password (cryptographically)
   - Configures shadowsocks-libev service
   - Sets up firewall rules
   - Creates web interface at port 8080
   - Saves credentials to `/root/openmptcprouter_credentials.txt`

2. **Router Setup Phase** (first boot wizard):
   - Web interface at `http://192.168.2.1`
   - Three methods:
     a) Pairing code (paste from VPS)
     b) Auto-discovery (enter VPS IP)
     c) Manual entry

3. **Auto-configuration**:
   - Client script (`client-auto-setup.sh`) runs
   - UCI configuration applied
   - Services restarted
   - Connection verified

---

## 6. VPS-SIDE VS CLIENT-SIDE CODE SEPARATION

### 6.1 VPS-Side Code

**Location**: `/vps-scripts/` directory

**Primary VPS Installation Workflow** (`wizard.sh` - 39KB):
1. **System Detection** (Step 1/8):
   - OS compatibility check (Debian 11/12/13, Ubuntu 20.04/22.04/24.04)
   - Root permission validation
   - Disk space verification (requires 30GB)

2. **Package Installation** (Step 2-4):
   - System updates via apt-get
   - Required packages: shadowsocks-libev, iptables, curl, git

3. **Kernel Optimization** (Step 5):
   - MPTCP enablement
   - BBR2 configuration
   - Buffer size tuning
   - Sysctl settings installation

4. **Firewall Configuration** (Step 6):
   - Drop default policy
   - Allow SSH (port 22)
   - Allow VPN ports (65500, 65510, 65520)
   - Allow web UI (port 8080)
   - Allow ICMP (ping)

5. **Service Setup** (Step 7):
   - Shadowsocks service creation
   - WireGuard module loading
   - Systemd service enablement

6. **Web Interface Generation** (Step 8):
   - HTML page generation at `/var/www/omr-setup/`
   - Copy-paste ready credentials
   - QR codes for mobile setup
   - Printable guide

**VPS Files Created**:
```
/etc/openmptcprouter/config.json          # Machine config
/etc/shadowsocks-libev/config.json        # Shadowsocks config
/etc/sysctl.d/99-openmptcprouter.conf    # Kernel params
/etc/iptables/rules.v4                    # Firewall rules
/root/openmptcprouter_credentials.txt     # Saved credentials (600 perms)
/var/www/omr-setup/index.html             # Web interface
/etc/systemd/system/omr-setup-web.service # Web service
```

### 6.2 Router (Client)-Side Code

**Location**: `/common/files/` directory

**Primary Router Setup Workflow**:

1. **First Boot** (`uci-defaults/*`):
   - Network initialization (10-omr-network-defaults)
   - Safety monitor startup (15-omr-autoconfig-init)
   - Memory buffer detection (05-omr-detect-ram-buffers)
   - Web wizard activation (90-omr-first-boot-wizard)

2. **Web Wizard** (runs on port 80):
   - User selects setup method
   - Enters VPS credentials
   - Tests connection
   - Applies configuration

3. **Runtime Monitoring** (continuous):
   - mptcp-manager (daemon)
   - network-monitor (health checks)
   - network-safety-monitor (lockout prevention)
   - omr-diagnostics (when queried)

4. **Daemon Functions**:
   - Metrics collection
   - Path health tracking
   - Automatic failover management
   - Emergency recovery

### 6.3 Code Separation Principles

| Aspect | VPS | Router |
|--------|-----|--------|
| **Role** | Tunnel server, VPN aggregation | Client, multi-WAN management |
| **Startup** | Manually triggered | Automatic (first boot) |
| **Complexity** | Linear, sequential | Reactive, continuous |
| **Reconfiguration** | Manual file edits or restart | Web UI or automated wizard |
| **Runtime State** | Minimal (connection log) | Rich (path metrics, health) |
| **Credential Storage** | `/root/`, restricted (600) | UCI config, can be synced |
| **Logging** | Systemd journal, Shadowsocks logs | Syslog, logger utility |

---

## 7. TESTING & DOCUMENTATION

### 7.1 Test Infrastructure

| File | Lines | Purpose |
|------|-------|---------|
| `/scripts/smoke-test.sh` | 98 | Quick validation of build system |
| `/scripts/validate-scripts.sh` | 84 | Syntax validation of shell scripts |
| `/vps-scripts/test-integration.sh` | 175 | VPS integration tests |
| `/vps-scripts/test-wizard.sh` | 133 | Wizard functionality tests |
| `/vps-scripts/test-confirmation-fix.sh` | 101 | Confirmation dialog tests |

**GitHub Workflows** (`.github/workflows/`):
- `build.yml` - Multi-target, multi-kernel build matrix (30+ device targets)
- `build-vps.yml` - VPS image building
- `validate.yml` - Code validation
- `stale.yml` - Issue staleness management

### 7.2 Comprehensive Documentation

**Audit & Analysis Documents** (20+ files):

1. **Core Audits**:
   - `AUDIT_FINDINGS.md` (634 lines) - 23 issues identified
   - `AUDIT_REPORT.md` - Original comprehensive audit
   - `AUDIT_SUMMARY.md` - Executive summary
   - `AUDIT_FINDINGS.md` - Issue breakdown by severity

2. **Bonding & Routing**:
   - `BONDING_FIX_PROPOSAL.md` (747 lines) - Fixes for critical bonding issues
   - `BONDING_FIXES_IMPLEMENTATION.md` (603 lines) - Implementation details
   - `BONDING_METRICS_AUDIT.md` - Metrics system analysis

3. **Kernel & Integration**:
   - `KERNEL_USERSPACE_INTEGRATION_REPORT.md` (928 lines)
   - `KERNEL_USERSPACE_ANALYSIS.md` (826 lines)
   - `KERNEL_TREE_ORGANIZATION.md` (630 lines)
   - `KERNEL_COMPATIBILITY.md` - Device support matrix
   - `KERNEL_OPTIMIZATIONS.md` - Tuning recommendations

4. **Architecture & Quality**:
   - `CODEBASE_MAPPING.md` (580 lines) - Codebase overview
   - `COMPREHENSIVE_AUDIT_SUMMARY.md` (686 lines)
   - `CODE_QUALITY_REPORT.md` (693 lines)
   - `COMPREHENSIVE_REVIEW_REPORT.md` (644 lines)

5. **Configuration & Deployment**:
   - `AUDIT-CONFIG-DEPLOYMENT.md` (844 lines)
   - `CHANGES-CONFIG-AUDIT.md` (490 lines)
   - `CHANGES_SUMMARY.md` - Release notes

6. **Security & Features**:
   - `BACKEND_SECURITY_AUDIT.md` - Backend security review
   - `BACKEND_SECURITY_FIXES.md` - Security fixes implemented
   - `SECURITY_AUDIT_REPORT.md` - Comprehensive security audit
   - `QOL_FEATURES.md` (459 lines) - Quality of life improvements
   - `IMPROVEMENTS.md` - Feature enhancements

7. **Setup & Guides**:
   - `README.md` - Main documentation
   - `SETUP_GUIDE.md` - Detailed setup instructions
   - `QUICK_START.md` - 5-minute quick start
   - `FAQ.md` (747 lines) - Frequently asked questions
   - `CONTRIBUTING.md` (516 lines) - Contribution guidelines

8. **Special Hardware**:
   - `DEVICE_TREE_GUIDE.md` - Device tree customization
   - `RM551E_QUICK_REF.md` - Hardware reference
   - `EMERGENCY_RECOVERY.md` - Recovery procedures

---

## 8. KNOWN ISSUES & PATTERNS

### 8.1 CRITICAL ISSUES IDENTIFIED

From `AUDIT_FINDINGS.md` (23 issues total):

**HIGH IMPACT (7 issues)**:

1. **Shell Compatibility** (Issue #1)
   - **File**: `/common/files/usr/lib/omr/omr-logger.sh`
   - **Problem**: Uses bash-specific associative arrays with `#!/bin/sh` shebang
   - **Impact**: Script fails on OpenWrt busybox ash
   - **Fix**: Change shebang to `#!/bin/bash` or reimplement without arrays

2. **Dangerous eval Usage** (Issue #2)
   - **File**: `/common/files/usr/lib/omr/omr-logger.sh` line 136
   - **Problem**: `eval "$check_command"` - potential command injection
   - **Impact**: Security vulnerability if check_command is user-provided
   - **Fix**: Replace with explicit function calls

3. **Unchecked UCI Command Failures** (Issue #3)
   - **File**: `/common/files/usr/bin/network-safety-monitor.sh` lines 202-218
   - **Problem**: Critical operations lack error checking
   - **Impact**: Emergency recovery may leave system partially configured
   - **Fix**: Check all critical operations, implement rollback

4. **Infinite Recovery Loop Risk** (Issue #4)
   - **File**: `/common/files/usr/bin/network-safety-monitor.sh` lines 288-304
   - **Problem**: Failed recovery triggers infinite retry loop
   - **Impact**: CPU thrashing, log spam, network instability
   - **Fix**: Implement exponential backoff, max retry count

5. **TCP Keepalive Timeout Too Long**
   - **File**: `/common/files/etc/sysctl.d/99-omr-mptcp-5g-optimization.conf`
   - **Problem**: Default 6.25-minute failover timeout (FIXED in code - now 50s)
   - **Impact**: Dead paths remain active for 6+ minutes
   - **Status**: ✓ FIXED - reduced to 20/3/10 (net.ipv4.tcp_keepalive_time settings)

6. **RTT-Only Scheduler**
   - **File**: MPTCP kernel configuration
   - **Problem**: Default scheduler ignores bandwidth (slow 10Mbps LTE beats fast Gbps fiber if RTT is lower)
   - **Impact**: Severe underutilization of fast paths
   - **Fix**: Enable BLEST scheduler (FIX 1.3) - ✓ DOCUMENTED but needs enabling

7. **No Path Blacklisting**
   - **File**: Missing path state management
   - **Problem**: Chronically lossy paths never permanently excluded
   - **Impact**: Continuous attempts to use degraded links
   - **Fix**: ✓ IMPLEMENTED - mptcp-path-manager maintains blacklist

**MEDIUM IMPACT (11 issues)** - Various edge cases, race conditions

**LOW IMPACT (5 issues)** - Minor improvements

### 8.2 IMPLEMENTATION STATUS OF BONDING FIXES

**FIX 1.1: Aggressive Failover Detection** ✓ IMPLEMENTED
- TCP keepalive: 20/3/10 = 50-second failover (vs 6.25 minutes default)
- File: `99-omr-mptcp-5g-optimization.conf`

**FIX 1.2: Faster TCP Retry Timeouts** ✓ IMPLEMENTED
- tcp_retries1=3, tcp_retries2=8, tcp_orphan_retries=0
- File: `99-omr-mptcp-5g-optimization.conf`

**FIX 1.3: Enable BLEST Scheduler** ✓ PARTIALLY IMPLEMENTED
- Code: `net.mptcp.mptcp_scheduler = blest`
- **NOTE**: Default config still has `OMR_MPTCP_SCHEDULER=${OMR_MPTCP_SCHEDULER:-default}`
- Recommendation: Change default to 'blest'

**FIX 2.1: Path Recovery Hysteresis** ✓ IMPLEMENTED
- File: `/usr/bin/mptcp-path-manager`
- Implementation: 30-second stability requirement before marking healthy

**FIX 2.2: Path Blacklisting** ✓ IMPLEMENTED
- File: `/usr/bin/mptcp-path-manager`
- Implementation: 5-failure threshold in 5-minute window, 5-minute blacklist

**FIX 3.2: Path Degradation Handling** ✓ IMPLEMENTED
- File: `/usr/bin/mptcp-path-manager`
- Implementation: 5% packet loss (500 basis points) triggers metric penalty

### 8.3 CODE PATTERNS & CONVENTIONS

**Shell Script Standards**:
```bash
#!/bin/sh  (Preferred for portability, except where bash needed)
set -u     (Catch undefined variables)
set -e     (Exit on error)
"$var"     (Always quote variables)
```

**Logging Convention**:
```bash
logger -t "tag-name" "message"  # Uses syslog
echo "text"                      # Fallback to console
```

**UCI (OpenWrt Configuration)**:
```bash
uci -q get network.lan.proto    # Query without errors
uci set network.lan.proto=static
uci commit network               # Apply changes
/etc/init.d/network restart     # Apply at network level
```

**Path Variables**:
```bash
/etc/openmptcprouter/           # Config directory (OMR_CONFIG_DIR)
/var/run/mptcp-paths/           # Path state directory
/var/run/mptcp-metrics/         # Metrics export directory
/var/log/openmptcprouter.log   # Log file (OMR_LOG_FILE)
/root/openmptcprouter_credentials.txt  # VPS creds (600 perms)
```

### 8.4 UNUSUAL PATTERNS IDENTIFIED

1. **Loose RP Filter Mode**
   - **Why**: MPTCP requires packets from any interface
   - **Trade-off**: Weakens IP spoofing protection
   - **Mitigation**: Firewall + connection tracking

2. **Aggressive TCP Keepalive**
   - **Why**: Detect dead paths in ~50 seconds vs 6+ minutes
   - **Trade-off**: May drop legitimate long-idle connections
   - **Suitable for**: WAN failover, not desktop connections

3. **Immediate Path Failures Not Blacklisted**
   - **By Design**: Single failure shouldn't exclude path
   - **Threshold**: 5 failures in 5-minute window

4. **Metric Penalties via UCI**
   - **Method**: Dynamic routing metric adjustment
   - **Effect**: Kernel routing selects lower metric paths
   - **Limitation**: Doesn't remove path from pool, just deprioritizes

5. **Race Condition in PID File** (Issue #5)
   - **File**: `/common/files/usr/bin/network-monitor.sh` lines 18-46
   - **Issue**: Lock directory check has race window
   - **Impact**: Multiple instances might run
   - **Fix**: Use flock or atomic operations

### 8.5 PERFORMANCE OPTIMIZATIONS

**omr-status UCI Caching Optimization**:
```bash
# BEFORE: 3 separate uci show calls = 40-100ms
# AFTER: 1 combined call, results cached = 10-30ms
# Location: /common/files/usr/bin/omr-status line 237-242
```

**Network Monitor Lock Mechanism**:
```bash
# Uses atomic mkdir for TOCTOU-free locking
# Prevents duplicate daemon instances
# File: /common/files/usr/bin/network-monitor.sh line 20-24
```

---

## COMPREHENSIVE FILE INDEX

### Configuration Files
- `/common/files/etc/openmptcprouter/defaults.conf` - Global defaults
- `/common/files/etc/sysctl.d/99-omr-mptcp-5g-optimization.conf` - Kernel tuning
- `/common/files/etc/uci-defaults/` - First-boot configuration (4 scripts)
- `/common/files/etc/usa-carrier-apns.conf` - USA carrier APN database

### Runtime Scripts (Executable)
- `/common/files/usr/bin/mptcp-path-manager` - Path health management
- `/common/files/usr/bin/mptcp-metrics-exporter` - Metrics collection
- `/common/files/usr/bin/network-monitor.sh` - Health monitoring
- `/common/files/usr/bin/network-safety-monitor.sh` - Safety & recovery
- `/common/files/usr/bin/omr-status` - Status dashboard
- `/common/files/usr/bin/omr-diagnostics` - Diagnostics tool
- `/common/files/usr/bin/omr-recovery` - Recovery utility
- `/common/files/usr/bin/port-autoconfig.sh` - Port detection
- `/common/files/usr/bin/usb-modem-autoconfig.sh` - Modem detection
- `/common/files/usr/bin/wifi-autoconfig.sh` - WiFi configuration
- `/common/files/usr/bin/set-carrier` - Carrier selection
- `/common/files/usr/lib/omr/omr-logger.sh` - Logging library

### Hotplug & Button Handlers
- `/common/files/etc/hotplug.d/usb/20-usb-modem` - USB modem detection
- `/common/files/etc/rc.button/reset` - Reset button handler
- `/common/files/etc/profile.d/99-omr-banner.sh` - Login banner

### Init Scripts
- `/common/files/etc/init.d/mptcp-manager` - MPTCP daemon manager
- `/common/files/etc/init.d/omr-diagnostics` - Diagnostics daemon
- (Auto-created) `network-monitor` - Network monitor daemon

### Build & Setup Scripts
- `build.sh` (1,157 lines) - Master build orchestrator
- `quick-setup.sh` (241 lines) - Quick setup helper
- `/scripts/omr-lib.sh` (592 lines) - Shared functions
- `/vps-scripts/wizard.sh` (39,532 lines) - Full VPS wizard
- `/vps-scripts/omr-vps-install.sh` (18,728 lines) - VPS installer
- Plus 10+ other setup/utility scripts

### Device Configurations
- `config-*` files (35+ devices) - Device-specific build options

### Kernel Patches
- `/patches/` - 22 patch files for kernel customization

---

## SUMMARY STATISTICS

- **Total Shell Scripts**: 50+
- **Total Makefiles**: 100+
- **Device Configurations**: 35+
- **Kernel Versions**: 5 (5.4, 6.1, 6.6, 6.10, 6.12)
- **Documentation Files**: 20+
- **Configuration Files**: 10+
- **Init Scripts**: 3 custom + auto-created
- **Total Lines in Main Scripts**: 4,700+ (scripts/)
- **Total Lines in VPS Scripts**: 60,000+
- **Total Lines in Daemons**: 1,500+
- **Kernel Parameters Tuned**: 50+
- **Issues Identified**: 23 (7 high, 11 medium, 5 low)
- **Fixes Implemented**: 6/7 (85%)

