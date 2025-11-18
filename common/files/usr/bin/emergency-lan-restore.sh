#!/bin/sh
#
# Emergency LAN Restore Script
# Called by reset button or can be run from serial console
# Restores at least one LAN port for network access
#

# Source network helper library for safe UCI operations
if [ -f /usr/lib/omr/omr-network.sh ]; then
    . /usr/lib/omr/omr-network.sh
fi

LOG_TAG="emergency-restore"

log_msg() {
    logger -t "$LOG_TAG" "$1"
    echo "$1"
}

log_msg "═══════════════════════════════════════════════════"
log_msg "EMERGENCY LAN RESTORE"
log_msg "═══════════════════════════════════════════════════"

# Find any available physical port
emergency_port=""

# Build list of WAN devices using helper library
wan_devices=""
if type get_wan_interfaces >/dev/null 2>&1; then
    for wan in $(get_wan_interfaces); do
        wan_device=$(uci -q get "network.$wan.device")
        [ -n "$wan_device" ] && wan_devices="$wan_devices $wan_device "
    done
else
    # Fallback to grep/cut if helper not available
    for wan in $(uci show network 2>/dev/null | grep "=interface" | grep -E "\.wan" | cut -d. -f2 | cut -d= -f1); do
        wan_device=$(uci -q get "network.$wan.device")
        [ -n "$wan_device" ] && wan_devices="$wan_devices $wan_device "
    done
fi

# Try to find a port not assigned to WAN
for iface in /sys/class/net/eth* /sys/class/net/lan*; do
    if [ -e "$iface" ]; then
        port=$(basename "$iface")

        # Check if this port is assigned to a WAN (O(1) string match)
        if echo "$wan_devices" | grep -q " $port "; then
            continue
        fi

        # If not a WAN, use it for emergency LAN
        emergency_port="$port"
        break
    fi
done

# If all ports are WANs, take the last one back
if [ -z "$emergency_port" ]; then
    last_wan=""
    if type get_wan_interfaces >/dev/null 2>&1; then
        last_wan=$(get_wan_interfaces | awk '{print $NF}')
    else
        last_wan=$(uci show network 2>/dev/null | grep "=interface" | grep -E "\.wan" | cut -d. -f2 | cut -d= -f1 | tail -n 1)
    fi

    if [ -n "$last_wan" ]; then
        emergency_port=$(uci -q get "network.$last_wan.device")
        if [ -n "$emergency_port" ]; then
            log_msg "Taking WAN port $emergency_port for emergency LAN"
            # SAFETY: Check delete succeeds before continuing
            if ! uci delete "network.$last_wan" 2>/dev/null; then
                log_msg "WARNING: Failed to delete interface $last_wan"
            fi
        else
            log_msg "WARNING: Could not get device for interface $last_wan"
        fi
    fi
fi

# If still no port, assign ALL ports to LAN
if [ -z "$emergency_port" ]; then
    log_msg "No ports available - assigning ALL ports to LAN"

    # Delete all WANs with error handling
    if type get_wan_interfaces >/dev/null 2>&1; then
        for wan in $(get_wan_interfaces); do
            if ! uci delete "network.$wan" 2>/dev/null; then
                log_msg "WARNING: Failed to delete WAN $wan"
            fi
        done
    else
        for wan in $(uci show network 2>/dev/null | grep "=interface" | grep -E "\.wan" | cut -d. -f2 | cut -d= -f1); do
            if ! uci delete "network.$wan" 2>/dev/null; then
                log_msg "WARNING: Failed to delete WAN $wan"
            fi
        done
    fi
    
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
			set network.lan.ipaddr='192.168.2.1'
			set network.lan.netmask='255.255.255.0'
			set network.lan.ip6assign='60'
		EOF
        
        uci commit network
        /etc/init.d/network restart
        
        log_msg "✓ ALL ports assigned to LAN"
        log_msg "✓ LAN IP: 192.168.2.1"
        log_msg "✓ Connect to any port and access http://192.168.2.1"
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
		set network.lan.ipaddr='192.168.2.1'
		set network.lan.netmask='255.255.255.0'
		set network.lan.ip6assign='60'
	EOF
    
    uci commit network
    
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
    /etc/init.d/network restart
    /etc/init.d/dnsmasq restart
    
    log_msg "═══════════════════════════════════════════════════"
    log_msg "✓ EMERGENCY RESTORE COMPLETE"
    log_msg "  LAN Port: $emergency_port"
    log_msg "  LAN IP: 192.168.2.1"
    log_msg "  Access: http://192.168.2.1"
    log_msg "═══════════════════════════════════════════════════"
else
    log_msg "ERROR: Could not find any ports for LAN!"
    exit 1
fi

exit 0
