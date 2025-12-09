#!/bin/bash

# Script developed to set static IP address quicker on Linux-based systems.
# I got fed up with setting them in my homelab so here we are..
# Example of running script - sudo ./set_network.sh -i eth0 -a 192.168.1.100 -n 255.255.255.0 -g 192.168.1.1
# Don't forget to run as root!!

set -e  # Exit on error
set -u  # Exit on undefined variable

# Checking if script is running at root. You need to be root to change your network interface settings.
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root."
    exit 1
fi

# Function to display usage
usage() {
    echo "Usage: $0 -i <interface> [-a <ip_address>] [-n <netmask>] [-g <gateway>]"
    echo "Example: sudo ./set_network.sh -i eth0 -a 192.168.1.100 -n 255.255.255.0 -g 192.168.1.1"
    exit 1
}

# Consolidated function to validate IPv4 address format
validate_ipv4() {
    local ip=$1
    local name=${2:-IP}

    if ! [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "ERROR: Invalid $name format: $ip"
        return 1
    fi

    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if ((octet < 0 || octet > 255)); then
            echo "ERROR: Invalid $name octet value: $octet (must be 0-255)"
            return 1
        fi
    done
    return 0
}

# Function to check if network interface exists
check_interface() {
    local interface=$1
    if ! ip link show "$interface" &>/dev/null; then
        echo "ERROR: Network interface '$interface' does not exist."
        echo "Available interfaces:"
        ip -brief link show
        return 1
    fi
    return 0
}

# Parse command line arguments
while getopts "i:a:n:g:" opt; do
    case "$opt" in
        i)
            INTERFACE=${OPTARG}
            ;;
        a)
            IP_ADDRESS=${OPTARG}
            ;;
        n)
            NETMASK=${OPTARG}
            ;;
        g)
            GATEWAY=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

# Check if interface is provided
if [ -z "$INTERFACE" ]; then
    echo "ERROR: Interface (-i) must be specified."
    usage
fi

# Check if interface exists
check_interface "$INTERFACE" || exit 1

# Validate IP address
if [ -n "$IP_ADDRESS" ]; then
    validate_ipv4 "$IP_ADDRESS" "IP address" || exit 1
fi

# Validate netmask (can be CIDR or dotted decimal)
if [ -n "$NETMASK" ]; then
    # Check if it's CIDR notation (just a number)
    if [[ $NETMASK =~ ^[0-9]+$ ]]; then
        if ((NETMASK < 0 || NETMASK > 32)); then
            echo "ERROR: Invalid CIDR netmask: $NETMASK (must be 0-32)"
            exit 1
        fi
    else
        # Validate as dotted decimal
        validate_ipv4 "$NETMASK" "netmask" || exit 1
    fi
fi

# Validate gateway
if [ -n "$GATEWAY" ]; then
    validate_ipv4 "$GATEWAY" "gateway" || exit 1
fi

# Set the IP address and netmask on the interface using ip command
if [ -n "$IP_ADDRESS" ] || [ -n "$NETMASK" ]; then
    if [ -z "$IP_ADDRESS" ]; then
        IP_ADDRESS=$(ip addr show dev "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
        if [ -z "$IP_ADDRESS" ]; then
            echo "ERROR: No IP address currently configured on $INTERFACE and none provided."
            exit 1
        fi
        echo "Current IP address on interface $INTERFACE: $IP_ADDRESS"
    fi

    if [ -z "$NETMASK" ]; then
        NETMASK=$(ip addr show dev "$INTERFACE" | awk '/inet / {print $2}' | cut -d'/' -f2 | head -n1)
        if [ -z "$NETMASK" ]; then
            echo "ERROR: No netmask currently configured on $INTERFACE and none provided."
            exit 1
        fi
        echo "Current netmask on interface $INTERFACE: /$NETMASK"
    fi

    echo "Flushing existing IP addresses on interface ${INTERFACE}..."
    if ! ip addr flush dev "$INTERFACE"; then
        echo "WARNING: Could not flush existing addresses on $INTERFACE"
    fi

    echo "Setting IP address ${IP_ADDRESS}/${NETMASK} on interface ${INTERFACE}..."
    if ! ip addr add "${IP_ADDRESS}/${NETMASK}" dev "$INTERFACE"; then
        echo "ERROR: Failed to set IP address on $INTERFACE"
        exit 1
    fi

    # Bring up the interface
    echo "Bringing up interface ${INTERFACE}..."
    if ! ip link set dev "$INTERFACE" up; then
        echo "ERROR: Failed to bring up interface $INTERFACE"
        exit 1
    fi

    # Set the default gateway if provided
    if [ -n "$GATEWAY" ]; then
        echo "Setting default gateway to ${GATEWAY}..."
        # Remove existing default gateway first
        ip route del default &>/dev/null || true
        if ! ip route add default via "${GATEWAY}"; then
            echo "ERROR: Failed to set default gateway"
            exit 1
        fi
    fi
fi

echo "Network configuration applied successfully!"
echo
echo "Current configuration:"
ip addr show dev "$INTERFACE"
echo
ip route show
