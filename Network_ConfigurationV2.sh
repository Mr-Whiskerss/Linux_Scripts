#!/bin/bash

#Script devloped to set static IP address quicker on linux based systems. I got fed up with setting them in my homelab so here we are..
#Example of running script - sudo ./set_network.sh -i eth0 -a 192.168.1.100 -n 255.255.255.0 -g 192.168.1.1
#Dont forget to run as root!! 

#Checking if script is running at root. You need to be root to change your network interface settings.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Function to display usage
usage() {
    echo "Usage: $0 -i <interface> -a <ip_address> -n <netmask> -g <gateway>"
    exit 1
}

# Parse command line arguments
while getopts "i:a:n:g:" opt; do
    case "${opt}" in
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

# Check if all arguments are provided
if [ -z "${INTERFACE}" ] || [ -z "${IP_ADDRESS}" ] || [ -z "${NETMASK}" ] || [ -z "${GATEWAY}" ]; then
    usage
fi

# Set the IP address and netmask on the interface
echo "Setting IP address ${IP_ADDRESS} with netmask ${NETMASK} on interface ${INTERFACE}..."
ifconfig ${INTERFACE} ${IP_ADDRESS} netmask ${NETMASK} up

# Set the default gateway
echo "Setting default gateway to ${GATEWAY}..."
route add default gw ${GATEWAY} ${INTERFACE}

echo "Network configuration applied successfully."
