#!/bin/bash -x

# Enable logging
exec 1> >(logger -s -t $(basename $0)) 2>&1

# wait for eth0 to be ready
echo "Waiting for eth0 interface..."
while ! ip link show dev eth0; do
  sleep 1
done

sysctl -q -w net.ipv4.conf.all.rp_filter=0
sysctl -q -w net.ipv4.conf.eth0.rp_filter=0
sysctl -q -w net.ipv4.conf.default.rp_filter=0

# enable IP forwarding and NAT
sysctl -q -w net.ipv4.ip_forward=1
sysctl -q -w net.ipv4.conf.eth0.send_redirects=0

# Clear existing NAT rules and add new one
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Make IP forwarding persistent
echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-nat.conf
sysctl -p /etc/sysctl.d/99-nat.conf

# Test network connectivity
curl --retry 10 --retry-delay 5 http://www.google.com

# reestablish connections
systemctl restart amazon-ssm-agent.service
