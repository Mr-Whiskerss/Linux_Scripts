#!/bin/bash

# Script developed to set static IP address quicker on Linux-based systems.
# I got fed up with setting them in my homelab so here we are..
# Example of running script - sudo ./set_network.sh -i eth0 -a 192.168.1.100 -n 255.255.255.0 -g 192.168.1.1
# Don't forget to run as root!!

# Checking if script is running at root. You need to be root to change your network interface settings.
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Function to display usage
usage() {
    echo "Usage: $0 -i <interface> [-a <ip_address>] [-n <netmask>] [-g <gateway>]"
    echo "Example: sudo ./set_network.sh -i eth0 -a 192.168.1.100 -n 255.255.255.0 -g 192.168.1.1"
    exit 1
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if ((octet < 0 || octet > 255)); then
            return 1
        fi
    done
}

# Function to validate netmask
validate_netmask() {
    local netmask=$1
    [[ $netmask =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octets <<< "$netmask"
    for octet in "${octets[@]}"; do
        if ((octet < 0 || octet > 255)); then
            return 1
        fi
    done
}

# Function to validate gateway
validate_gateway() {
    local gateway=$1
    [[ $gateway =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octets <<< "$gateway"
    for octet in "${octets[@]}"; do
        if ((octet < 0 || octet > 255)); then
            return 1
        fi
    done
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
    echo "Error: Interface (-i) must be specified."
    usage
fi

# Validate IP address
if [ -n "$IP_ADDRESS" ] && ! validate_ip "$IP_ADDRESS"; then
    echo "Error: Invalid IP address format."
    exit 1
fi

# Validate netmask
if [ -n "$NETMASK" ] && ! validate_netmask "$NETMASK"; then
    echo "Error: Invalid netmask format."
    exit 1
fi

# Validate gateway
if [ -n "$GATEWAY" ] && ! validate_gateway "$GATEWAY"; then
    echo "Error: Invalid gateway format."
    exit 1
fi

# Set the IP address and netmask on the interface using ip command
if [ -n "$IP_ADDRESS" ] || [ -n "$NETMASK" ]; then
    if [ -z "$IP_ADDRESS" ]; then
        IP_ADDRESS=$(ip addr show dev "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
        echo "Current IP address on interface $INTERFACE: $IP_ADDRESS"
    fi

    if [ -z "$NETMASK" ]; then
        NETMASK=$(ip addr show dev "$INTERFACE" | awk '/inet / {print $2}' | cut -d'/' -f2)
        echo "Current netmask on interface $INTERFACE: $NETMASK"
    fi

    echo "Setting IP address ${IP_ADDRESS} with netmask ${NETMASK} on interface ${INTERFACE}..."
    ip addr add "${IP_ADDRESS}/${NETMASK}" dev "$INTERFACE"

    # Bring up the interface
    ip link set dev "$INTERFACE" up

    # Set the default gateway if provided
    if [ -n "$GATEWAY" ]; then
        echo "Setting default gateway to ${GATEWAY}..."
        ip route add default via "${GATEWAY}"
    fi
fi

echo "Network configuration applied successfully."
