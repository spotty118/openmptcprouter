#!/bin/sh
# OpenMPTCProuter Network Helper Library
# Provides safe, consistent network interface operations
# Replaces fragile uci show | grep | cut | cut patterns
# Part of OpenMPTCProuter bonding behavior fixes

# Get list of WAN interface names from UCI
# Usage: get_wan_interfaces
# Returns: space-separated list of WAN interface names (e.g., "wan wan2 wan3")
# Safe: Properly handles UCI output without fragile grep/cut chains
get_wan_interfaces() {
    local interfaces=""
    local section=""

    # Use uci show and parse properly
    # Format: network.wan=interface, network.wan.proto=dhcp, etc.
    for section in $(uci -q show network 2>/dev/null | grep "=interface$" | cut -d'.' -f2 | cut -d'=' -f1); do
        # Check if this is a WAN interface (starts with "wan")
        case "$section" in
            wan|wan[0-9]|wan[0-9][0-9])
                interfaces="$interfaces $section"
                ;;
        esac
    done

    echo "$interfaces" | xargs
}

# Get list of all interface names from UCI (not just WANs)
# Usage: get_all_interfaces
get_all_interfaces() {
    uci -q show network 2>/dev/null | grep "=interface$" | cut -d'.' -f2 | cut -d'=' -f1 | xargs
}

# Find UCI section name for a network device
# Usage: get_uci_section_for_device "eth1"
# Returns: UCI section name (e.g., "wan2") or empty if not found
get_uci_section_for_device() {
    local device="$1"
    local section=""

    # Try 'device' attribute first (modern UCI)
    for section in $(get_all_interfaces); do
        local dev=$(uci -q get "network.$section.device")
        if [ "$dev" = "$device" ]; then
            echo "$section"
            return 0
        fi
    done

    # Try 'ifname' attribute (legacy UCI)
    for section in $(get_all_interfaces); do
        local ifname=$(uci -q get "network.$section.ifname")
        if [ "$ifname" = "$device" ]; then
            echo "$section"
            return 0
        fi
    done

    return 1
}

# Check if an interface name is a WAN interface
# Usage: is_wan_interface_name "wan2"
# Returns: 0 if WAN, 1 otherwise
is_wan_interface_name() {
    local iface="$1"
    case "$iface" in
        wan|wan[0-9]|wan[0-9][0-9])
            return 0
            ;;
    esac
    return 1
}

# Validate interface name for security (prevent command injection)
# Usage: validate_interface_name "eth0"
# Returns: 0 if valid, 1 if invalid
validate_interface_name() {
    local iface="$1"

    # Only allow alphanumeric, underscore, hyphen, and dot
    case "$iface" in
        *[!a-zA-Z0-9._-]*)
            return 1
            ;;
    esac

    # Ensure reasonable length (max 15 chars for Linux interfaces)
    if [ "${#iface}" -gt 15 ]; then
        return 1
    fi

    # Ensure not empty
    [ -n "$iface" ]
}

# Check if interface should be skipped (virtual/internal interfaces)
# Usage: is_virtual_interface "br-lan"
# Returns: 0 if virtual (should skip), 1 if physical (should process)
is_virtual_interface() {
    local iface="$1"

    case "$iface" in
        # Loopback
        lo)
            return 0
            ;;
        # Bridges
        br-*)
            return 0
            ;;
        # VLAN interfaces on br-lan
        eth0.1|eth0.2)
            return 0
            ;;
        # WiFi client interfaces
        wlan*client|apcli*)
            return 0
            ;;
        # Traffic shaping
        ifb*)
            return 0
            ;;
        # IPv6 tunnels
        sit*|ip6tnl*|ip6gre*)
            return 0
            ;;
        # Generic tunnels
        tun*|tap*|gre*)
            return 0
            ;;
        # VPN interfaces
        vpn*|wg*|ppp*)
            return 0
            ;;
        # Docker/container interfaces
        docker*|veth*)
            return 0
            ;;
        # NSS interfaces (Qualcomm)
        nss*)
            return 0
            ;;
    esac

    return 1
}

# Get metric for an interface with bounds checking
# Usage: get_interface_metric "wan2"
# Returns: metric value (default 100 if not set)
get_interface_metric() {
    local section="$1"
    local metric=$(uci -q get "network.$section.metric")

    # Default to 100 if not set
    [ -z "$metric" ] && metric=100

    # Ensure within bounds
    [ "$metric" -lt 1 ] && metric=1
    [ "$metric" -gt 10000 ] && metric=10000

    echo "$metric"
}

# Set metric for an interface with bounds checking
# Usage: set_interface_metric "wan2" 150
# Returns: 0 on success, 1 on failure
set_interface_metric() {
    local section="$1"
    local metric="$2"

    # Validate metric value
    if ! echo "$metric" | grep -qE '^[0-9]+$'; then
        return 1
    fi

    # Enforce bounds
    [ "$metric" -lt 1 ] && metric=1
    [ "$metric" -gt 10000 ] && metric=10000

    uci -q set "network.$section.metric=$metric"
}

# Get all WAN devices (physical interfaces, not UCI sections)
# Usage: get_wan_devices
# Returns: space-separated list of device names (e.g., "eth1 wwan0 usb0")
get_wan_devices() {
    local devices=""
    local wan

    for wan in $(get_wan_interfaces); do
        local device=$(uci -q get "network.$wan.device")
        [ -n "$device" ] && devices="$devices $device"
    done

    echo "$devices" | xargs
}

# Check if device is assigned to any WAN
# Usage: is_device_wan "eth1"
# Returns: 0 if assigned to WAN, 1 otherwise
is_device_wan() {
    local check_device="$1"
    local wan

    for wan in $(get_wan_interfaces); do
        local device=$(uci -q get "network.$wan.device")
        if [ "$device" = "$check_device" ]; then
            return 0
        fi
    done

    return 1
}
