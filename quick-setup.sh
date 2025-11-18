#!/bin/bash
#
# OpenMPTCProuter Quick Setup
# Universal setup script for both VPS and Router
#
# Usage:
#   VPS:    curl -sSL https://get.omr.sh | sudo bash
#   Router: wget -O- https://get.omr.sh | sh
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Unicode characters
CHECK="✓"
CROSS="✗"
ARROW="→"
STAR="★"

# Print functions
print_header() {
    echo -e "\n${PURPLE}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}${BOLD}║                                                            ║${NC}"
    echo -e "${PURPLE}${BOLD}║         OpenMPTCProuter ${STAR} Quick Setup                    ║${NC}"
    echo -e "${PURPLE}${BOLD}║                                                            ║${NC}"
    echo -e "${PURPLE}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    echo -e "${BLUE}${BOLD}${ARROW} $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Detect environment
detect_environment() {
    print_step "Detecting environment..."

    # Check if running on OpenWrt (router)
    if [ -f /etc/openwrt_release ]; then
        ENV_TYPE="router"
        print_success "Detected OpenWrt Router"
        return 0
    fi

    # Check if running on standard Linux (VPS)
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu)
                ENV_TYPE="vps"
                print_success "Detected VPS ($PRETTY_NAME)"
                return 0
                ;;
            *)
                print_error "Unsupported OS: $PRETTY_NAME"
                print_info "Supported: Debian 11/12/13, Ubuntu 20.04/22.04/24.04"
                exit 1
                ;;
        esac
    fi

    print_error "Unable to detect environment"
    exit 1
}

# VPS Setup
setup_vps() {
    print_header
    echo -e "${BOLD}VPS Setup Mode${NC}\n"

    print_step "Downloading VPS wizard..."

    # Download and run the VPS wizard
    # SECURITY FIX: Download to temp file first to allow inspection
    WIZARD_URL="https://raw.githubusercontent.com/spotty118/openmptcprouter/develop/vps-scripts/wizard.sh"
    TEMP_WIZARD=$(mktemp)
    chmod 700 "$TEMP_WIZARD"
    trap "rm -f '$TEMP_WIZARD'" EXIT INT TERM

    if command -v curl &> /dev/null; then
        if ! curl -sSL -o "$TEMP_WIZARD" "$WIZARD_URL"; then
            print_error "Failed to download VPS wizard"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if ! wget -qO "$TEMP_WIZARD" "$WIZARD_URL"; then
            print_error "Failed to download VPS wizard"
            exit 1
        fi
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    chmod +x "$TEMP_WIZARD"
    bash "$TEMP_WIZARD"

    # Check if wizard completed successfully
    if [ $? -eq 0 ]; then
        print_success "VPS setup completed!"
        echo ""
        print_info "Next steps:"
        echo "  1. Your VPS is now ready"
        echo "  2. Visit http://$(get_public_ip):8080 for credentials"
        echo "  3. Use the pairing code or QR code to configure your router"
        echo ""
    else
        print_error "VPS setup failed. Please check the logs above."
        exit 1
    fi
}

# Router Setup
setup_router() {
    print_header
    echo -e "${BOLD}Router Setup Mode${NC}\n"

    print_info "Router setup options:"
    echo ""
    echo "  ${BOLD}1.${NC} First-time setup (recommended)"
    echo "     ${CYAN}→${NC} Visit http://192.168.2.1 in your browser"
    echo "     ${CYAN}→${NC} Follow the setup wizard"
    echo "     ${CYAN}→${NC} Use pairing code from your VPS"
    echo ""
    echo "  ${BOLD}2.${NC} Command-line setup"
    echo "     ${CYAN}→${NC} Run: /usr/bin/omr-setup-wizard"
    echo ""
    echo "  ${BOLD}3.${NC} Automated setup with VPS IP and password"
    echo ""

    read -p "Choose setup method (1-3) [1]: " SETUP_METHOD
    SETUP_METHOD=${SETUP_METHOD:-1}

    case $SETUP_METHOD in
        1)
            print_info "Please open http://192.168.2.1 in your web browser"
            print_info "The setup wizard will guide you through the process"
            ;;
        2)
            if [ -x /usr/bin/omr-setup-wizard ]; then
                /usr/bin/omr-setup-wizard
            else
                print_error "Setup wizard not found"
                exit 1
            fi
            ;;
        3)
            read -p "Enter VPS IP address: " VPS_IP
            read -s -p "Enter VPS password: " VPS_PASS
            echo ""

            if [ -z "$VPS_IP" ] || [ -z "$VPS_PASS" ]; then
                print_error "VPS IP and password are required"
                exit 1
            fi

            # Download and run client auto-setup
            # SECURITY FIX: Download to temp file first, then pass credentials via environment
            CLIENT_SETUP_URL="https://raw.githubusercontent.com/spotty118/openmptcprouter/develop/scripts/client-auto-setup.sh"
            TEMP_SCRIPT=$(mktemp)
            chmod 700 "$TEMP_SCRIPT"
            trap "rm -f '$TEMP_SCRIPT'" EXIT INT TERM

            print_step "Downloading client setup script..."
            if command -v curl &> /dev/null; then
                if ! curl -sSL -o "$TEMP_SCRIPT" "$CLIENT_SETUP_URL"; then
                    print_error "Failed to download setup script"
                    exit 1
                fi
            elif command -v wget &> /dev/null; then
                if ! wget -qO "$TEMP_SCRIPT" "$CLIENT_SETUP_URL"; then
                    print_error "Failed to download setup script"
                    exit 1
                fi
            else
                print_error "Neither curl nor wget found"
                exit 1
            fi

            # SECURITY: Pass credentials via environment to avoid process listing exposure
            chmod +x "$TEMP_SCRIPT"
            export OMR_VPS_IP="$VPS_IP"
            export OMR_VPS_PASS="$VPS_PASS"
            "$TEMP_SCRIPT" "$VPS_IP" "$VPS_PASS"
            ;;
        *)
            print_error "Invalid selection"
            exit 1
            ;;
    esac
}

# Get public IP with proper timeouts
get_public_ip() {
    local ip=""
    local services="ifconfig.me icanhazip.com ipinfo.io/ip api.ipify.org"

    for service in $services; do
        if ip=$(curl -4 -s --max-time 5 "https://$service" 2>/dev/null) && [ -n "$ip" ]; then
            # Validate IP format
            if echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
                echo "$ip"
                return 0
            fi
        fi
    done

    # Fallback with wget
    if ip=$(wget -qO- -4 --timeout=5 "https://ifconfig.me" 2>/dev/null) && [ -n "$ip" ]; then
        echo "$ip"
        return 0
    fi

    return 1
}

# Show quick help
show_help() {
    print_header
    echo "This script automatically detects your environment and runs the"
    echo "appropriate setup process."
    echo ""
    echo "${BOLD}For VPS:${NC}"
    echo "  curl -sSL https://get.omr.sh | sudo bash"
    echo ""
    echo "${BOLD}For Router:${NC}"
    echo "  wget -O- https://get.omr.sh | sh"
    echo ""
    echo "${BOLD}Manual setup:${NC}"
    echo "  ./quick-setup.sh [--help]"
    echo ""
}

# Main
main() {
    # Check for help flag
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi

    # Detect environment
    detect_environment

    # Run appropriate setup
    case "$ENV_TYPE" in
        vps)
            setup_vps
            ;;
        router)
            setup_router
            ;;
        *)
            print_error "Unknown environment type"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
