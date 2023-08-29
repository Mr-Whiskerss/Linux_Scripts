#!/bin/bash

#Checking if script is running at root. You need to be root to change your network interface settings.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#This script is used to configure a static IP address and a MAC address.
#You need to change the blank spaces with the interface IP address and MAC address of YOUR choosing. In this script eth0 is the interface needing to be changed.
#Warning Changes made with this script will not stick after the system has been rebooted.

#Changing mac address 
sudo ip link set etho down
sudo ip link set eth0 address XX:XX:XX:XX:XX:XX
sudo ip link set etho up

#Setting ip address
sudo ip addr add [ip address insert here] dev [interface here]

#Example - sudo ip addr add 192.168.56.21/24 dev eth1

#Setting default route/gateway
ip route add <network>/<netmask> via <gateway> dev <interface>

#Example - sudo ip route add 192.168.1.0/24 dev eth0



