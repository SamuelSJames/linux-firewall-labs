#!/bin/bash
# lab-setup/lxc/01-ip-forwarding/setup.sh

set -e

# Create containers
echo "[+] Creating router container"
lxc launch images:ubuntu/22.04 router --profile default

sleep 5

lxc exec router -- apt update
lxc exec router -- apt install -y iproute2 net-tools

# Add network interfaces and configure IPs
# This assumes you have set up two Linux bridges: lxdbr0 and lxdbr1
# Adjust as necessary for your Proxmox or LXC setup

lxc network attach lxdbr0 router eth0 eth0
lxc network attach lxdbr1 router eth1 eth1

lxc exec router -- ip addr add 192.168.1.1/24 dev eth0
lxc exec router -- ip addr add 10.0.0.1/24 dev eth1
lxc exec router -- ip link set eth0 up
lxc exec router -- ip link set eth1 up

# Enable IP forwarding
lxc exec router -- bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'

# Optional: make it persistent
lxc exec router -- sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Create client
lxc launch images:ubuntu/22.04 client
sleep 5
lxc network attach lxdbr0 client eth0 eth0
lxc exec client -- ip addr add 192.168.1.2/24 dev eth0
lxc exec client -- ip link set eth0 up
lxc exec client -- ip route add default via 192.168.1.1

# Create server
lxc launch images:ubuntu/22.04 server
sleep 5
lxc network attach lxdbr1 server eth0 eth0
lxc exec server -- ip addr add 10.0.0.2/24 dev eth0
lxc exec server -- ip link set eth0 up
lxc exec server -- ip route add default via 10.0.0.1

# Test connectivity
echo "[+] Testing connectivity from client to server"
lxc exec client -- ping -c 3 10.0.0.2
