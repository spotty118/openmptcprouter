#!/bin/sh
#
# Emergency LAN Restore Script
# Called by reset button or can be run from serial console
# Restores at least one LAN port for network access
#

LOG_TAG="emergency-restore"
LOCK_FILE="/var/run/emergency-restore.lock"

# Source defaults and helper library
[ -f /etc/openmptcprouter/defaults.conf ] && . /etc/openmptcprouter/defaults.conf
[ -f /usr/lib/omr/omr-network.sh ] && . /usr/lib/omr/omr-network.sh

# Use default LAN IP if not set
LAN_IP="${OMR_LAN_IP:-192.168.2.1}"
LAN_NETMASK="${OMR_LAN_NETMASK:-255.255.255.0}"

log_msg() {
    logger -t "$LOG_TAG" "$1"
    echo "$1"
}

# Acquire lock to prevent race conditions
acquire_lock() {
    if ! mkdir "$LOCK_FILE" 2>/dev/null; then
        log_msg "Another emergency restore is running, waiting..."
        sleep 2
        if ! mkdir "$LOCK_FILE" 2>/dev/null; then
            log_msg "ERROR: Could not acquire lock after retry"
            exit 1
        fi
    fi
    trap 'rmdir "$LOCK_FILE" 2>/dev/null' EXIT INT TERM
}

acquire_lock

log_msg "═══════════════════════════════════════════════════"
log_msg "EMERGENCY LAN RESTORE"
log_msg "═══════════════════════════════════════════════════"

# Find any available physical port
emergency_port=""

# Try to find a port not assigned to WAN
for iface in /sys/class/net/eth* /sys/class/net/lan*; do
    if [ -e "$iface" ]; then
        port=$(basename "$iface")
        
        # Check if this port is assigned to a WAN using helper library
        is_wan=0
        if type is_device_wan >/dev/null 2>&1 && is_device_wan "$port"; then
            is_wan=1
        else
            # Fallback if helper library not available
            for wan in $(get_wan_interfaces 2>/dev/null || uci -q show network | grep "=interface$" | grep -E "^network\.wan" | cut -d. -f2 | cut -d= -f1); do
                wan_device=$(uci -q get network.$wan.device)
                if [ "$wan_device" = "$port" ]; then
                    is_wan=1
                    break
                fi
            done
        fi
        
        # If not a WAN, use it for emergency LAN
        if [ $is_wan -eq 0 ]; then
            emergency_port="$port"
            break
        fi
    fi
done

# If all ports are WANs, take the last one back
if [ -z "$emergency_port" ]; then
    local last_wan=""
    for wan in $(get_wan_interfaces 2>/dev/null || uci -q show network | grep "=interface$" | grep -E "^network\.wan" | cut -d. -f2 | cut -d= -f1); do
        last_wan="$wan"
    done
    if [ -n "$last_wan" ]; then
        emergency_port=$(uci -q get network.$last_wan.device)
        if [ -n "$emergency_port" ]; then
            log_msg "Taking WAN port $emergency_port for emergency LAN"
            uci delete network.$last_wan
        fi
    fi
fi

# If still no port, assign ALL ports to LAN
if [ -z "$emergency_port" ]; then
    log_msg "No ports available - assigning ALL ports to LAN"
    
    # Delete all WANs
    for wan in $(get_wan_interfaces 2>/dev/null || uci -q show network | grep "=interface$" | grep -E "^network\.wan" | cut -d. -f2 | cut -d= -f1); do
        uci delete network.$wan
    done
    
    # Collect all physical ports
    all_ports=""
    for iface in /sys/class/net/eth* /sys/class/net/lan*; do
        if [ -e "$iface" ]; then
            port=$(basename "$iface")
            all_ports="$all_ports $port"
        fi
    done
    
    all_ports=$(echo "$all_ports" | xargs)
    
    if [ -n "$all_ports" ]; then
        uci -q batch <<-EOF
			delete network.@device[0]
			add network device
			set network.@device[-1].name='br-lan'
			set network.@device[-1].type='bridge'
			set network.@device[-1].ports='$all_ports'
			set network.lan.device='br-lan'
			set network.lan.proto='static'
			set network.lan.ipaddr='$LAN_IP'
			set network.lan.netmask='$LAN_NETMASK'
			set network.lan.ip6assign='60'
		EOF
        
        if ! uci commit network; then
            log_msg "ERROR: Failed to commit network configuration"
            return 1
        fi

        if ! /etc/init.d/network restart; then
            log_msg "ERROR: Network restart failed - system may be in inconsistent state"
            log_msg "Try manual recovery: /etc/init.d/network restart"
            return 1
        fi

        log_msg "✓ ALL ports assigned to LAN"
        log_msg "✓ LAN IP: $LAN_IP"
        log_msg "✓ Connect to any port and access http://$LAN_IP"
        exit 0
    fi
fi

# Create LAN with emergency port
if [ -n "$emergency_port" ]; then
    log_msg "Restoring LAN on port: $emergency_port"
    
    uci -q batch <<-EOF
		delete network.@device[0]
		add network device
		set network.@device[-1].name='br-lan'
		set network.@device[-1].type='bridge'
		set network.@device[-1].ports='$emergency_port'
		set network.lan.device='br-lan'
		set network.lan.proto='static'
		set network.lan.ipaddr='$LAN_IP'
		set network.lan.netmask='$LAN_NETMASK'
		set network.lan.ip6assign='60'
	EOF
    
    if ! uci commit network; then
        log_msg "ERROR: Failed to commit network configuration"
        exit 1
    fi

    # Ensure DHCP is enabled
    uci -q batch <<-EOF
		set dhcp.lan=dhcp
		set dhcp.lan.interface='lan'
		set dhcp.lan.start='100'
		set dhcp.lan.limit='150'
		set dhcp.lan.leasetime='12h'
		set dhcp.lan.dhcpv4='server'
		commit dhcp
	EOF
    
    # Restart network services
    if ! /etc/init.d/network restart; then
        log_msg "ERROR: Network restart failed"
        log_msg "Try manual: /etc/init.d/network restart"
        exit 1
    fi

    if ! /etc/init.d/dnsmasq restart; then
        log_msg "WARNING: DHCP restart failed - LAN may work but no DHCP"
    fi
    
    log_msg "═══════════════════════════════════════════════════"
    log_msg "✓ EMERGENCY RESTORE COMPLETE"
    log_msg "  LAN Port: $emergency_port"
    log_msg "  LAN IP: $LAN_IP"
    log_msg "  Access: http://$LAN_IP"
    log_msg "═══════════════════════════════════════════════════"
else
    log_msg "ERROR: Could not find any ports for LAN!"
    exit 1
fi

exit 0
