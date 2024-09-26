#!/bin/bash

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

sudo apt update
sudo apt install openvswitch-switch -y

echo -e ${Yellow} Teardown OLD STUFF - Just in case you run this script twice
sudo ip netns del bowser &> /dev/null
sudo ip netns del peach &> /dev/null
sudo ip netns del mario &> /dev/null
sudo ip netns del yoshi &> /dev/null
sudo ip netns del router &> /dev/null
sudo ovs-vsctl del-br donut-plains &> /dev/null
sudo iptables -P FORWARD DROP && sudo iptables -F FORWARD && sudo iptables -t nat -F

echo -e ${Green} Create an OvS bridge called donut-plains
sudo ovs-vsctl add-br donut-plains

echo -e ${Cyan} CREATE NETWORK NAKESPACES
sudo ip netns add peach &> /dev/null
sudo ip netns add bowser &> /dev/null
sudo ip netns add mario &> /dev/null
sudo ip netns add yoshi &> /dev/null

echo -e ${Yellow} CREATE OVS BRIDGE INTERNALS
sudo ovs-vsctl add-port donut-plains peach -- set interface peach type=internal
sudo ovs-vsctl add-port donut-plains bowser -- set interface bowser type=internal
sudo ovs-vsctl add-port donut-plains mario -- set interface mario type=internal
sudo ovs-vsctl add-port donut-plains yoshi -- set interface yoshi type=internal

echo -e ${Cyan} PLUG OVS BRIDGE INTERNALS INTO NAMESPACES
sudo ip link set peach netns peach
sudo ip link set bowser netns bowser
sudo ip link set mario netns mario
sudo ip link set yoshi netns yoshi

echo -e ${Green} BRING ALL INTERFACES UP
sudo ip netns exec peach ip link set dev peach up
sudo ip netns exec peach ip link set dev lo up
sudo ip netns exec bowser ip link set dev bowser up
sudo ip netns exec bowser ip link set dev lo up
sudo ip netns exec mario ip link set dev mario up
sudo ip netns exec mario ip link set dev lo up
sudo ip netns exec yoshi ip link set dev yoshi up
sudo ip netns exec yoshi ip link set dev lo up

echo -e ${Cyan} ADD IP ADDRESSES TO ALL THOSE NEW INTERFACES
sudo ip netns exec peach ip addr add 10.64.2.2/24 dev peach
sudo ip netns exec bowser ip addr add 10.64.2.3/24 dev bowser
sudo ip netns exec mario ip addr add 10.64.1.2/24 dev mario
sudo ip netns exec yoshi ip addr add 10.64.1.3/24 dev yoshi

echo -e ${Yellow} REMOVE THE ROUTES THAT ARE CREATED WHEN ADDING AN IP ADDRESS
sudo ip netns exec peach ip route del 10.64.2.0/24
sudo ip netns exec bowser ip route del 10.64.2.0/24
sudo ip netns exec mario ip route del 10.64.1.0/24
sudo ip netns exec yoshi ip route del 10.64.1.0/24

echo -e ${Green} ADD VLANs
sudo ovs-vsctl set port peach tag=90
sudo ovs-vsctl set port bowser tag=90
sudo ovs-vsctl set port mario tag=70
sudo ovs-vsctl set port yoshi tag=70

echo -e ${Cyan} CREATE THE NFV ROUTER
sudo ip netns add router
sudo ovs-vsctl add-port donut-plains router1 -- set interface router1 type=internal
sudo ovs-vsctl add-port donut-plains router2 -- set interface router2 type=internal
sudo ip link set router1 netns router
sudo ip link set router2 netns router
sudo ip netns exec router ip a
sudo ip netns exec router ip link set dev router1 up && sudo ip netns exec router ip link set dev router2 up
sudo ip netns exec router ip addr add 10.64.1.1/24 dev router1
sudo ip netns exec router ip addr add 10.64.2.1/24 dev router2
sudo ip netns exec router ip route del 10.64.2.0/24
sudo ip netns exec router ip route del 10.64.1.0/24
sudo ovs-vsctl set port router1 tag=70
sudo ovs-vsctl set port router2 tag=90

echo -e ${Yellow} ADD DEFAULT ROUTES
sudo ip netns exec mario ip route add default via 10.64.1.1 dev mario onlink
sudo ip netns exec bowser ip route add default via 10.64.2.1 dev bowser onlink
sudo ip netns exec peach ip route add default via 10.64.2.1 dev peach onlink
sudo ip netns exec yoshi ip route del default

cat << EOF >  10-ip-forwarding.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
EOF
sudo cp 10-ip-forwarding.conf /etc/sysctl.d/10-ip-forwarding.conf
rm 10-ip-forwarding.conf
sudo ip netns exec router sysctl -p /etc/sysctl.d/10-ip-forwarding.conf

echo -e ${Yellow} CONNECT THE ROUER TO THE ROOT NAMESPACE
sudo ip link add host2router type veth peer name router2host
sudo ip link set dev router2host netns router
sudo ip netns exec router ip addr add 10.64.3.1/24 dev router2host
sudo ip netns exec router ip link set dev router2host up
sudo ip netns exec router ip route del 10.64.0.0/24 &> /dev/null
sudo ip addr add 10.64.3.2/24 dev host2router
sudo ip netns exec router ip route add default dev router2host via 10.64.3.2 onlink

echo -e ${Green} ADD ROUTES and FOWARDING RULES TO ROUTER
sudo ip netns exec router ip route add 10.64.1.0/24 dev router1
sudo ip netns exec router ip route add 10.64.2.0/24 dev router2
sudo ip netns exec router iptables -t nat -A POSTROUTING -j MASQUERADE
sudo ip route del 10.64.0.0/20 &> /dev/null
sudo ip route add 10.64.0.0/20 via 10.64.3.1 dev host2router onlink

echo -e ${Cyan} INSTALL IPTABLE CHANGES
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
echo -e ${Green} The -t stands for table.
sudo iptables -t filter -F
sudo iptables -t nat -F
sudo iptables -t nat    -A POSTROUTING -s 10.64.0.0/20 -o ens3 -j MASQUERADE
sudo iptables -t filter -A FORWARD -i ens3 -o host2router -j ACCEPT
sudo iptables -t filter -A FORWARD -o ens3 -i host2router -j ACCEPT
echo -e ${white} DONE \n

# Backup the current /etc/hosts file
sudo cp /etc/hosts /etc/hosts.backup

# Define the new entries with a comment
new_entries="# New entries
10.64.2.2 bowser
10.64.2.2 peach
10.64.1.3 yoshi
10.64.1.2 mario
10.64.3.1 router"

# Append the new entries to the /etc/hosts file
echo "$new_entries" | sudo tee -a /etc/hosts > /dev/null

# Verify the changes
echo "The following new entries have been added to /etc/hosts:"
echo "$new_entries"

sudo ip netns exec mario ping -c 1 10.64.2.3
sudo ip netns exec mario ping -c 1 8.8.8.8
