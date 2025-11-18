# OpenMPTCProuter Optimized - Comprehensive Codebase Overview

**Project:** OpenMPTCProuter (Optimized Fork by spotty118)  
**Purpose:** Multi-WAN bonding router with MPTCP aggregation and VPS-based encryption  
**Architecture:** OpenWrt-based router OS with multi-kernel support and VPS backend  
**Key Technologies:** MPTCP, Shadowsocks, WireGuard, BBR2, QMI/MBIM modem support

---

## 1. TOP-LEVEL DIRECTORY STRUCTURE

```
/home/user/openmptcprouter/
├── .github/                          # GitHub configuration and CI/CD
│   ├── workflows/                    # GitHub Actions workflows
│   │   ├── build.yml                 # Main router image build pipeline
│   │   ├── build-vps.yml             # VPS backend build pipeline
│   │   ├── validate.yml              # Code validation
│   │   └── stale.yml                 # Stale issue management
│   └── ISSUE_TEMPLATE/               # Issue templates
│
├── 5.4/, 6.1/, 6.6/, 6.10/, 6.12/   # Kernel version trees (OpenWrt forks)
│   ├── package/                      # Kernel-specific packages
│   ├── target/                       # Target platform definitions
│   ├── tools/                        # Build tools for this kernel
│   └── include/                      # Build includes
│
├── common/                           # SHARED across all kernel versions
│   ├── files/                        # Filesystem overlays (root mount point mapping)
│   ├── package/                      # OpenWrt packages (router binaries/daemons)
│   ├── scripts/                      # Build scripts
│   ├── target/                       # Target-specific common files
│   └── tools/                        # Common build tools
│
├── patches/                          # Kernel and package patches
│   ├── bbr2*.patch                   # BBR v2 congestion control
│   ├── mt76-wifi7-optimizations.patch
│   └── [23 total patches]
│
├── scripts/                          # ROUTER-SIDE deployment/setup
│   ├── client-auto-setup*.sh         # Automated client configuration
│   ├── auto-pair.sh                  # VPS-router pairing
│   ├── easy-install.sh               # Web-based installer
│   ├── omr-*.sh                      # Helper scripts (build, health, config)
│   └── validate-scripts.sh
│
├── vps-scripts/                      # VPS-SIDE deployment
│   ├── wizard.sh                     # Interactive VPS setup (37K lines!)
│   ├── omr-vps-install.sh            # Automated VPS installation
│   ├── install.sh                    # Minimal installer
│   ├── test-*.sh                     # Integration tests
│   └── README.md                     # VPS setup documentation
│
├── build.sh                          # MAIN BUILD ORCHESTRATOR (59K lines)
├── quick-setup.sh                    # Build environment setup
├── sign.sh                           # Image signing script
├── config                            # Default build config (OpenWrt standard)
├── config-*                          # Device-specific configs (40+ device types)
│
├── Documentation Files               # Various audit and guide documents
├── QUICK_START.md, SETUP_GUIDE.md   
├── BONDING_FIX_PROPOSAL.md
├── KERNEL_USERSPACE_INTEGRATION_REPORT.md
└── [60+ documentation files]
```

---

## 2. KEY CONFIGURATION FILES & NETWORKING

### 2.1 Kernel and System Optimization
```
/common/files/etc/sysctl.d/99-omr-mptcp-5g-optimization.conf
```
Critical system parameters for MPTCP bonding:
- **MPTCP**: `net.mptcp.enabled = 1` (enabled)
- **Scheduler**: `net.mptcp.mptcp_scheduler = blest` (bandwidth-delay optimization)
- **Path Manager**: `net.mptcp.mptcp_path_manager = fullmesh`
- **Congestion Control**: `net.ipv4.tcp_congestion_control = bbr2` (BBR v2)
- **TCP Buffers**: 32MB max (reduced from 128MB to prevent bufferbloat)
- **Network Device Backlog**: 300,000 (high packet rates)
- **TCP Fast Open**: Enabled (reduced latency)
- **MTU Probing**: Enabled (path discovery)
- **Failover Tuning**:
  - `tcp_keepalive_time = 20` (aggressive detection)
  - `tcp_keepalive_probes = 3`
  - `tcp_keepalive_intvl = 10`
  - `tcp_retries2 = 8` (faster retry escalation)

### 2.2 Default Configuration
```
/common/files/etc/openmptcprouter/defaults.conf
```
Environment variables for VPS and router setup:
- **Port Configuration**:
  - Shadowsocks: 65500
  - Glorytun TCP: 65510
  - Glorytun UDP: 65520
  - Web UI: 8080
  - Auto-pairing API: 9999
- **LAN Network**: 192.168.2.1/255.255.255.0 (static, never DHCP)
- **DHCP Range**: 192.168.2.100-249
- **Encryption**: chacha20-ietf-poly1305
- **MPTCP Scheduler Options**: fullmesh, ndiffports, binder

### 2.3 Network Initialization (UCI Defaults)
```
/common/files/etc/uci-defaults/10-omr-network-defaults
```
First-boot network setup:
- Static LAN IP (CRITICAL: never DHCP to prevent APIPA)
- DHCP server activation
- DNS configuration via dnsmasq
- DHCPv6 and RA server setup

---

## 3. MAIN SCRIPTS AND DAEMONS

### 3.1 Daemon Services (Init.d Scripts)
```
/common/files/etc/init.d/
```

#### mptcp-manager
- **Purpose**: Intelligent path management for MPTCP
- **Starts**: Two processes:
  1. `mptcp-metrics-exporter` - Collects link quality metrics
  2. `mptcp-path-manager` - Manages path state with hysteresis
- **Start Order**: 99 (very late, after everything else)
- **Stop Order**: 10 (early, before others)
- **Uses**: procd for auto-restart on crash

#### omr-diagnostics  
- **Purpose**: Health check service
- **Monitors**: Network health, MPTCP status, VPN connectivity

### 3.2 User-Space Utilities (/common/files/usr/bin/)

#### omr-status
- **Lines**: 361
- **Purpose**: Connection status dashboard
- **Shows**: All WAN connections, signal strength, traffic stats
- **Color output**: Terminal-aware formatting
- **Usage**: `omr-status` (no args)

#### omr-diagnostics
- **Lines**: 416
- **Purpose**: System health check
- **Checks**: Network, MPTCP, VPN, kernel params, firewall
- **Usage**: `omr-diagnostics check`

#### omr-recovery
- **Lines**: 200
- **Purpose**: Emergency recovery menu
- **Options**: LAN restore, IP reset, DHCP enable, factory reset
- **Interactive**: Menu-driven

#### mptcp-path-manager
- **Lines**: 317
- **Purpose**: Intelligent path state management
- **Features**:
  - Hysteresis (30 second stability requirement)
  - Blacklisting (5 failures in 5 minutes = 5-min blacklist)
  - Degradation tracking (5% loss threshold)
  - State tracking in `/var/run/mptcp-paths/`
- **Monitors**: Both WAN and cellular (wwan*) interfaces
- **Check Interval**: 5 seconds

#### mptcp-metrics-exporter
- **Lines**: 198
- **Purpose**: Collect per-link metrics
- **Metrics Collected**:
  - RTT (round-trip time)
  - Packet loss rate
  - Jitter
  - Signal strength (for cellular: RSSI, RSRP)
  - Interface statistics
- **Output**: `/var/run/mptcp-metrics/` (files per interface)
- **Update Interval**: 10 seconds
- **Signal Detection**: Supports QMI (uqmi) and MBIM (umbim) modems

#### network-safety-monitor.sh
- **Lines**: 375
- **Purpose**: Prevent network lockouts
- **Prevents**: APIPA addresses, LAN inaccessibility
- **Emergency Triggers**: Triggers emergency-lan-restore.sh if needed

#### network-monitor.sh
- **Lines**: 158
- **Purpose**: Continuous network health monitoring
- **Interval**: Periodic checks

#### usb-modem-autoconfig.sh
- **Lines**: 459
- **Purpose**: Auto-configure USB modems as WAN interfaces
- **Supports**:
  - QMI protocol (Qualcomm modems)
  - MBIM protocol (Huawei, others)
  - APN auto-lookup (USA carriers built-in)
- **Triggers**: Hotplug events, manual invocation
- **Supported Modems**:
  - Quectel (2c7c)
  - Huawei (12d1)
  - Sierra Wireless (1199)
  - ZTE (19d2)
  - SIMCom (1e0e)
  - Fibocom (2cb7)
  - Telit (1bc7)
  - MediaTek/Fibocom (0e8d)

#### wifi-autoconfig.sh
- **Lines**: 239
- **Purpose**: WiFi radio configuration
- **Sets**: Country code, SSID prefix, bands

#### port-autoconfig.sh
- **Lines**: 243
- **Purpose**: Physical port role detection
- **Assigns**: WAN vs LAN roles

#### emergency-lan-restore.sh
- **Lines**: 146
- **Purpose**: Emergency network restoration
- **Actions**: Reset IP, enable DHCP, ensure LAN accessibility

#### set-carrier.sh
- **Lines**: 178
- **Purpose**: Modem carrier/technology selection
- **Methods**: AT commands, QMI, MBIM

### 3.3 Event Handlers (Hotplug)
```
/common/files/etc/hotplug.d/usb/20-usb-modem
```
- **Trigger**: USB device addition
- **Action**: Spawns `usb-modem-autoconfig.sh` in background
- **Lock Mechanism**: Prevents race conditions with flock
- **Detects**: Multiple modem brands by USB vendor ID

### 3.4 Setup Scripts (Router-Side)
```
/scripts/
```

#### client-auto-setup.sh / client-auto-setup-improved.sh
- **Lines**: 11K-16K
- **Purpose**: Automated router configuration via SSH
- **Actions**:
  - Configure VPN credentials
  - Set up MPTCP
  - Enable WAN bonding
- **Usage**: `client-auto-setup.sh <VPS_IP> <PASSWORD>`

#### auto-pair.sh
- **Lines**: 18K
- **Purpose**: Bidirectional pairing protocol
- **Process**: Router and VPS exchange credentials automatically
- **Output**: Pairing code for user

#### easy-install.sh
- **Lines**: 19K
- **Purpose**: Web-based VPS installer
- **Output**: HTTP interface at port 8080 for configuration

#### omr-lib.sh
- **Lines**: 13K
- **Purpose**: Shared library functions
- **Contains**: Color output, logging, validation helpers

#### omr-config-manager.sh
- **Lines**: 10K
- **Purpose**: Configuration file management

#### omr-health-check.sh
- **Lines**: 9K
- **Purpose**: System health verification

#### smoke-test.sh
- **Lines**: 3K
- **Purpose**: Quick sanity tests

### 3.5 Setup Scripts (VPS-Side)
```
/vps-scripts/
```

#### wizard.sh
- **Lines**: 37,532 (LARGEST VPS COMPONENT)
- **Purpose**: Interactive VPS installation wizard
- **Features**:
  - OS detection (Debian 11/12/13, Ubuntu 20.04/22.04/24.04)
  - Automatic network configuration
  - Cryptographically secure password generation
  - Kernel optimization for MPTCP
  - Firewall configuration
  - VPN service setup (Shadowsocks, WireGuard)
  - Web interface generation at port 8080
- **Output**:
  - `/root/openmptcprouter_credentials.txt`
  - `/etc/openmptcprouter/config.json`
  - Web setup page at `http://VPS_IP:8080`

#### omr-vps-install.sh
- **Lines**: 18K
- **Purpose**: Full automated VPS installation
- **Alternative**: To wizard.sh for non-interactive environments

#### install.sh
- **Lines**: 2.9K
- **Purpose**: Minimal installer wrapper

#### test-integration.sh
- **Lines**: 5.7K
- **Purpose**: VPS integration testing

### 3.6 Build Scripts
```
/build.sh (59K lines)
/quick-setup.sh (6.6K lines)
```

#### build.sh - Main Orchestrator
**Purpose**: Compile router images for all supported devices  
**Capabilities**:
- Multi-kernel builds (5.4, 6.1, 6.6, 6.10, 6.12)
- 40+ device configurations (Raspberry Pi, BananaPi, Teltonika, x86, ARM)
- Package feed integration
- Custom patches application
- Image signing
- Repository management

**Key Variables**:
- `OMR_KERNEL`: Kernel version (default: 5.4)
- `OMR_TARGET`: Device type (default: x86_64)
- `OMR_PACKAGES`: Package set (default: full)
- `OMR_DIST`: Distribution name
- `OMR_RELEASE`: Git tag-based release name
- `UPSTREAM`: Use upstream OpenWrt vs customized

**Process**:
1. Validate dependencies (git, curl, patch, gcc, g++, python3)
2. Verify disk space (30GB minimum)
3. Clone/update OpenWrt repository
4. Apply patches from `/patches/`
5. Load device-specific config
6. Compile kernel and packages
7. Generate image for device
8. Sign image if keys available

#### quick-setup.sh
**Purpose**: Initial build environment setup  
**Tasks**:
- Install build dependencies
- Clone OpenWrt repo
- Prepare toolchain

---

## 4. PACKAGE ORGANIZATION

### 4.1 Common Packages
```
/common/package/
├── base-files/                       # Root filesystem structure
│   └── files/
│       ├── bin/config_generate       # Network config generator
│       ├── etc/banner                # Login banner
│       └── sbin/sysupgrade           # System upgrade script
│
├── network/                          # Network-related packages
│   ├── config/
│   │   └── firewall/
│   │       └── patches/fullconenat.patch
│   │
│   ├── services/
│   │   └── dnsmasq/                  # DNS/DHCP server
│   │
│   ├── utils/
│   │   └── wwan/                     # Cellular connectivity
│   │
│   └── ipv6/
│       └── 6in4/                     # IPv6 tunneling
│
├── modems/                           # Modem drivers and firmware
│   ├── Makefile
│   ├── files/
│   │   ├── modem-ca-optimize.sh      # Carrier aggregation setup
│   │   ├── rm551e-init.sh            # RM551E modem initialization
│   │   └── rm551e-monitor.sh         # RM551E monitoring
│   │
│   └── src/
│       ├── README_RM551E.md          # Fibocom RM551E documentation
│       ├── data/                     # USB modem device definitions
│       │   ├── 0421-*/               # Fibocom
│       │   ├── 05c6-*/               # Qualcomm/Sierra
│       │   ├── 12d1-*/               # Huawei
│       │   ├── 19d2-*/               # ZTE (440+ variants!)
│       │   ├── 2c7c-*/               # Quectel
│       │   └── [50+ manufacturers]
│       └── [USB device firmware configs]
│
├── boot/                             # Bootloaders
│   ├── uboot-mvebu                   # Marvell (BananaPi R2, R4)
│   └── uboot-ipq40xx                 # Qualcomm (RUTX, WiFi 6)
│
├── firmware/
│   └── linux-firmware/               # WiFi/modem firmware
│
├── luci-theme-omr-optimized/         # Web UI theme
│   ├── htdocs/                       # Static assets
│   ├── luasrc/view/                  # LuCI templates
│   └── uci-defaults/                 # UI configuration
│
└── utils/
    └── wmt/                          # MediaTek wireless tools
        └── files/
```

### 4.2 Device-Specific Configs
```
/config-<device>
```
40+ device configurations including:
- **Raspberry Pi**: rpi2, rpi3, rpi4, rpi5
- **BananaPi**: bpi-r1, bpi-r2, bpi-r3, bpi-r3-mini, bpi-r4, bpi-r4-poe, bpi-r64
- **Teltonika RUTX**: rutx, rutx12, rutx50
- **x86/x86_64**: x86, x86_64
- **GL.inet**: gl-mt2500, gl-mt3000, gl-mt6000
- **Other**: espressobin, r2s, r4s, r5c, r5s, r6s, r7800, qnap-301w, etc.

Each contains kernel module selections and driver configurations specific to that hardware.

---

## 5. KERNEL AND SYSCTL CONFIGURATIONS

### 5.1 Kernel Optimization
```
/common/files/etc/sysctl.d/99-omr-mptcp-5g-optimization.conf (250+ lines)
```

**Core MPTCP Settings**:
- Enable MPTCP aggregation
- Set BLEST scheduler (better than RTT-only)
- fullmesh path manager (all interface combinations)
- Disable MPTCP checksums (performance optimization)

**Network Buffer Tuning**:
- `rmem_max`: 32MB (prevent bufferbloat while supporting high throughput)
- `wmem_max`: 32MB
- TCP buffers: 4KB min → 87KB default → 32MB max
- netdev backlog: 300,000 (high packet rate handling)

**TCP Performance**:
- Window scaling (high-latency link support)
- TCP Fast Open (reduced connection setup latency)
- SACK/DSACK (loss recovery)
- MTU probing (path discovery)
- MSS clamping at 1400 bytes (tunnel overhead)

**Failover Aggressiveness**:
- keepalive time: 20 seconds (vs traditional 300s)
- keepalive probes: 3 attempts
- keepalive interval: 10 seconds
- **Total failover time: ~50 seconds** (vs 6+ minutes default)
- tcp_retries2: 8 (faster escalation vs 15)

**Connection Management**:
- TCP time-wait reuse enabled
- FIN timeout: 10 seconds
- Max time-wait buckets: 2,000,000

### 5.2 Device Tree and Target-Specific Configs
```
/common/target/linux/
├── bcm27xx/                          # Raspberry Pi (ARM32/ARM64)
│   └── base-files/lib/functions/board.sh
│
└── ipq40xx/                          # Qualcomm (RUTX, WiFi 6)
    └── base-files/lib/functions/
        ├── board.sh
        ├── teltonika-defaults.sh     # RUTX/IPQ specific
        └── teltonika-functions.sh
```

These define:
- Network interface detection
- Port layout (which ports are LAN vs WAN)
- GPIO button mapping
- LED triggers

---

## 6. ROUTING RULES AND FIREWALL CONFIGURATION

### 6.1 Firewall Configuration
```
/common/package/network/config/firewall/
```
- Uses nftables (not legacy iptables by default)
- Patch for full-cone NAT (game-friendly)
- VPN traffic redirection rules
- MPTCP-aware connection tracking

### 6.2 Network Routing
```
/common/files/etc/uci-defaults/10-omr-network-defaults
/common/package/base-files/files/etc/board.d/99-default_network
```

**Routing Architecture**:
- All WAN interfaces marked with `multipath=on`
- MPTCP creates subflows on all available WAN paths
- BLEST scheduler allocates bandwidth proportionally
- Failover automatic if path RTT exceeds threshold or blacklisted

**MPTCP Path Management**:
- **Fullmesh**: All combinations of local and remote IPs
- **NDiffPorts**: Different source ports, same interface IP
- **Binder**: Single interface, multiple subflows

---

## 7. VPS-SIDE vs CLIENT-SIDE CODE SEPARATION

### 7.1 CLIENT-SIDE (Router)
Location: `/common/files/`, `/scripts/`, root filesystem  
**Responsibilities**:
- Detect available WAN connections (Ethernet, USB modems, WiFi)
- Configure MPTCP to aggregate WAN paths
- Encrypt traffic with Shadowsocks
- Run local VPN termination (local Shadowsocks server for LAN clients)
- Monitor link quality metrics
- Handle user configuration via LuCI web interface
- Emergency network recovery

**Key Services**:
1. `mptcp-manager` (path state, metrics)
2. `netifd` (network interface daemon)
3. `dnsmasq` (DNS/DHCP)
4. `firewall` (nftables)
5. `shadowsocks-libev-local` (local VPN for LAN)
6. `network-safety-monitor` (emergency recovery)

### 7.2 VPS-SIDE
Location: `/vps-scripts/`, deployed to external VPS  
**Responsibilities**:
- Accept encrypted traffic from router on multiple ports
- Decrypt MPTCP traffic
- Route decrypted traffic to internet (normal gateway)
- Re-encrypt return traffic
- Expose public IP to router (for geolocation, etc.)
- Serve web setup interface on port 8080
- Firewall configuration (allow VPN, SSH, web UI)
- Kernel optimization (MPTCP enabled, BBR2)

**Key Services** (installed by wizard.sh):
1. `shadowsocks-libev-server` (port 65500)
2. `glorytun` (alternative tunnel, ports 65510/65520)
3. `wg-quick` (WireGuard if enabled)
4. `dnsmasq` (local DNS caching)
5. `omr-setup-web` (web interface at 8080)

**Separation Mechanism**:
- **Configuration Storage**:
  - Router: `/etc/config/` (UCI format)
  - VPS: `/etc/openmptcprouter/config.json` (JSON)
  
- **Credential Handling**:
  - Router: Stores VPS IP, port, password locally
  - VPS: Generates credentials, serves via web interface
  
- **Pairing Protocol**:
  - Auto-pair.sh exchanges keys
  - QR codes or pairing tokens for user confirmation
  - One-time setup, credentials persisted on both sides

---

## 8. TEST FILES AND DOCUMENTATION

### 8.1 Test Scripts
```
/scripts/
├── smoke-test.sh                     # Quick sanity checks
├── validate-scripts.sh               # Syntax validation
└── verify-setup.sh                   # Connection verification

/vps-scripts/
├── test-integration.sh               # VPS integration tests
├── test-wizard.sh                    # Wizard interaction tests
└── test-confirmation-fix.sh          # Confirmation protocol tests
```

### 8.2 Documentation Files
```
QUICK_START.md                        # 5-minute setup guide
SETUP_GUIDE.md                        # Comprehensive installation
README.md                             # Project overview
BONDING_FIX_PROPOSAL.md               # Bonding behavior improvements
KERNEL_USERSPACE_INTEGRATION_REPORT.md # Technical deep-dive
CODEBASE_MAPPING.md                   # Code organization
CODEBASE_QUICK_REFERENCE.txt          # File index and purposes

Audit Reports (20+ documents):
├── AUDIT_FINDINGS.md
├── AUDIT_REPORT.md
├── BACKEND_SECURITY_AUDIT.md
├── BONDING_FIXES_IMPLEMENTATION.md
├── CODE_QUALITY_REPORT.md
├── COMPREHENSIVE_REVIEW_REPORT.md
├── DEPENDENCY_REVIEW_REPORT.md
├── ERROR_HANDLING_AUDIT.md
├── FRONTEND_ANALYSIS.md
├── KERNEL_COMPATIBILITY.md
├── KERNEL_OPTIMIZATIONS.md
├── KERNEL_TREE_ORGANIZATION.md
├── PERFORMANCE_AUDIT.txt
├── PROPOSED_PATCHES.md
├── SECURITY_AUDIT_REPORT.md
└── [And more...]
```

---

## 9. CRITICAL FILE LOCATIONS

### Router-Side Critical Files
```
/common/files/etc/
├── sysctl.d/99-omr-mptcp-5g-optimization.conf          # Kernel tuning (CRITICAL)
├── init.d/mptcp-manager                                 # Core path management daemon
├── openmptcprouter/defaults.conf                        # Configuration defaults
├── uci-defaults/10-omr-network-defaults                 # First-boot setup
├── hotplug.d/usb/20-usb-modem                          # Modem detection

/common/files/usr/bin/
├── mptcp-path-manager                                   # Path state machine
├── mptcp-metrics-exporter                               # Metrics collection
├── omr-status                                           # Dashboard
├── usb-modem-autoconfig.sh                             # Modem auto-config
└── network-safety-monitor.sh                            # Lockout prevention

/common/files/usr/lib/omr/
└── omr-logger.sh                                        # Logging library
```

### VPS-Side Critical Files
```
/vps-scripts/
├── wizard.sh                                            # Main VPS installer (37.5K)
├── omr-vps-install.sh                                   # Alternative installer
└── README.md                                            # VPS documentation

Generated during VPS setup:
/etc/openmptcprouter/config.json                        # VPS config
/root/openmptcprouter_credentials.txt                   # Saved credentials
/etc/sysctl.d/99-openmptcprouter.conf                   # Kernel optimization
/etc/shadowsocks-libev/config.json                      # Shadowsocks config
/etc/iptables/rules.v4                                  # Firewall rules
```

### Build-Critical Files
```
/build.sh                                                # Main build orchestrator
/quick-setup.sh                                          # Environment setup
/patches/                                                # 23 kernel/package patches
/common/package/modems/src/data/                        # 700+ modem definitions
/config-<device>                                         # Device-specific configs
```

---

## 10. ARCHITECTURE OVERVIEW

### Signal Flow: From WAN to Internet

```
[Multiple WAN Inputs]
        ↓
Ethernet/USB Modem/WiFi ← Auto-detected by hotplug/port-autoconfig
        ↓
   [MPTCP Subflows]
        ↓
    (Kernel MPTCP)
        ↓
[mptcp-metrics-exporter] ← Measures RTT, loss, signal
        ↓
[mptcp-path-manager] ← Smart scheduling & failover
        ↓
  Shadowsocks Encryption (local → VPS)
        ↓
    [Internet]
        ↓
Shadowsocks Decryption (VPS)
        ↓
   [Default Gateway]
        ↓
   [Internet]
```

### Key Technology Stack

| Layer | Technology | Location |
|-------|-----------|----------|
| **OS** | OpenWrt (Linux 5.4-6.12) | / |
| **Multi-WAN** | MPTCP (kernel) | net.mptcp.* |
| **Scheduling** | BLEST | mptcp-path-manager |
| **VPN** | Shadowsocks, WireGuard | vps-scripts/wizard.sh |
| **DNS/DHCP** | dnsmasq | standard OpenWrt |
| **Firewall** | nftables | /common/package/network/config/firewall |
| **Modem Support** | QMI/MBIM | usb-modem-autoconfig.sh |
| **TCP Optimization** | BBR2 | patches/bbr2.patch |
| **Web UI** | LuCI | common/package/luci-theme-omr-optimized |

---

## 11. DATA FLOWS & STATE MANAGEMENT

### State Directories
```
/var/run/mptcp-paths/
├── wan0                              # Interface state file
├── wan1
├── wan0.blacklist                    # Blacklist marker
└── wan0.degraded                     # Degradation marker

/var/run/mptcp-metrics/
├── wan0.metrics                      # JSON metrics for interface
├── wan1.metrics
└── [one file per active interface]
```

### Configuration Storage
```
/etc/config/                          # UCI (Unified Configuration Interface)
├── network                           # Interface and routing config
├── dhcp                             # DHCP/DNS server config
├── firewall                         # Firewall rules
└── openmptcprouter                  # OMR-specific config

/etc/openmptcprouter/
└── defaults.conf                     # Environment variable defaults
```

---

## 12. MULTI-DEVICE SUPPORT

**Supported Platforms** (40+ device types):
- Raspberry Pi 2/3/4/5 (ARM32/ARM64)
- BananaPi series (R1, R2, R3, R4 - all ARM variants)
- Teltonika RUTX series (embedded routers with cellular)
- x86/x86_64 (generic PC builds)
- GL.iNET routers (WiFi + cellular)
- Various ARM SBC boards

**Kernel Selection** (5 major versions):
- 5.4: Older, stable, less overhead
- 6.1: LTS, good balance
- 6.6: Newer features, better drivers
- 6.10: Cutting edge
- 6.12: Latest

**Per-Device Config Aspects**:
- CPU type (ARM32/ARM64, x86)
- Available RAM (triggers buffer size adjustments)
- Network interface count and speed
- Storage (EMMC vs SD vs disk)
- WiFi chipsets (mt76, ath11k, etc.)
- Bootloader specifics

---

## 13. KEY FEATURES OVERVIEW

| Feature | Implementation | Location |
|---------|---|---|
| **MPTCP Aggregation** | Kernel + scheduler | sysctl.d + mptcp-path-manager |
| **Automatic Failover** | Path monitoring + blacklisting | mptcp-path-manager |
| **USB Modem Auto-Config** | Hotplug + QMI/MBIM | hotplug.d + usb-modem-autoconfig.sh |
| **Signal Monitoring** | QMI/MBIM signal queries | mptcp-metrics-exporter |
| **Path Metrics** | RTT, loss, jitter, signal | mptcp-metrics-exporter |
| **Encryption** | Shadowsocks + WireGuard | vps-scripts/wizard.sh |
| **Web Setup Wizard** | First-boot UI + VPS wizard | uci-defaults/90 + vps-scripts/wizard.sh |
| **Emergency Recovery** | LAN restore + DHCP reset | network-safety-monitor + emergency-lan-restore |
| **Kernel Optimization** | BBR2, MPTCP tuning | patches + sysctl.d |
| **VPS Auto-Pairing** | Bidirectional key exchange | auto-pair.sh |

---

## 14. BUILD & DEPLOYMENT WORKFLOW

```
Developer/User
     ↓
[build.sh] ← Parses OMR_TARGET, OMR_KERNEL
     ↓
[quick-setup.sh] ← Downloads OpenWrt base, applies patches
     ↓
[OpenWrt build system]
     ↓
[common/package/*] ← OMR-specific packages injected
     ↓
[Kernel compilation] (selected by OMR_KERNEL)
     ↓
[Package compilation]
     ↓
[Image generation] for OMR_TARGET
     ↓
[Image signing] (if keys present)
     ↓
[Router image] (sysupgrade or first-time flash)
     ↓
↓Router first boot
├─ [10-omr-network-defaults]
├─ [15-omr-autoconfig-init]
└─ [90-omr-first-boot-wizard] ← Web UI at 192.168.2.1
     ↓
Pairing options:
├─ Auto-discovery
├─ QR code scan
└─ Manual entry
     ↓
[client-auto-setup.sh] or [auto-pair.sh]
     ↓
↓VPS side (parallel)
[vps-scripts/wizard.sh] (run once)
     ↓
Generate credentials → Router uses them
     ↓
MPTCP aggregation active + encryption enabled
```

---

## 15. PERFORMANCE OPTIMIZATIONS

### Kernel-Level
- BBR v2 congestion control (better utilization)
- MPTCP with BLEST scheduler (bandwidth-aware)
- Extended TCP buffers (32MB, prevents packet loss)
- Fast failover (20-second keepalive)
- MTU probing (automatic path discovery)

### User-Space
- Intelligent path blacklisting (permanent removal of bad paths)
- Hysteresis filtering (prevents flapping)
- Degradation detection (5% loss threshold)
- Metrics-driven scheduling (real data, not just RTT)
- Signal strength integration (modem awareness)

### System-Level
- Dynamic buffer sizing based on RAM
- Connection tracking optimization
- netdev backlog tuning (300K packets)
- UDP packet batching
- SYN cookies for protection

---

## 16. SUMMARY TABLE

| Aspect | Details |
|--------|---------|
| **Repository Size** | 1GB+ (with kernel sources) |
| **Main Languages** | Shell scripts, Lua (LuCI), C (kernel) |
| **Supported Devices** | 40+ (RPi, BananaPi, Teltonika, x86) |
| **Kernel Versions** | 5.4, 6.1, 6.6, 6.10, 6.12 |
| **Key Daemons** | mptcp-manager, netifd, dnsmasq, firewall |
| **User-Space Tools** | 12 major scripts (3.3K lines total) |
| **VPS Backend** | wizard.sh (37.5K lines) |
| **Build Time** | 15-60 minutes (depends on device/kernel) |
| **Image Size** | 50-300MB (depending on device/packages) |
| **Default Router IP** | 192.168.2.1 (static) |
| **VPS Ports** | 65500 (SS), 65510 (Glorytun-TCP), 65520 (Glorytun-UDP) |
| **Configuration Format** | UCI (router) + JSON (VPS) |
| **License** | GPL v3 |

---

## 17. MOST CRITICAL FILES FOR BONDING BEHAVIOR

If you want to understand multi-WAN bonding, study these in order:

1. **`99-omr-mptcp-5g-optimization.conf`** - Kernel tuning (failover timeouts)
2. **`mptcp-path-manager`** - Intelligent path state machine (blacklisting, hysteresis)
3. **`mptcp-metrics-exporter`** - Link quality metrics (RTT, loss, signal)
4. **`build.sh`** - Kernel version selection (determines MPTCP features)
5. **`bbr2.patch`** - Congestion control algorithm
6. **`usb-modem-autoconfig.sh`** - Multi-WAN interface detection
7. **`vps-scripts/wizard.sh`** - VPS encryption and traffic handling

---

This comprehensive overview covers the full vertical stack from kernel optimization through VPS configuration.
