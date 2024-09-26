#!/bin/bash

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

echo -e ${Yellow} "Teardown and remove network namespaces and OVS bridge"

# Delete network namespaces
sudo ip netns del bowser &> /dev/null
sudo ip netns del peach &> /dev/null
sudo ip netns del mario &> /dev/null
sudo ip netns del yoshi &> /dev/null
sudo ip netns del router &> /dev/null

# Delete the OVS bridge
sudo ovs-vsctl del-br donut-plains &> /dev/null

# Clear iptables rules
sudo iptables -P FORWARD DROP && sudo iptables -F FORWARD && sudo iptables -t nat -F

echo -e ${Green} "Old setup has been torn down."

# Disable IP forwarding and remove IP forwarding rules
echo -e ${Cyan} "Removing IP forwarding settings"
sudo rm /etc/sysctl.d/10-ip-forwarding.conf
sudo sysctl -p /etc/sysctl.d/10-ip-forwarding.conf

# Remove veth pair used for the router
echo -e ${Yellow} "Removing veth pairs and associated routing"
sudo ip link del host2router &> /dev/null

# Restore iptables to their default state
echo -e ${Green} "Flushing iptables rules"
sudo iptables -t filter -F
sudo iptables -t nat -F

# Restore /etc/hosts from backup
if [ -f /etc/hosts.backup ]; then
    echo -e ${Cyan} "Restoring /etc/hosts from backup"
    sudo cp /etc/hosts.backup /etc/hosts
else
    echo -e ${Red} "No /etc/hosts backup found."
fi

echo -e ${Green} "Cleanup completed. System restored to its previous state."
