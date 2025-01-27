#!/bin/bash -x

sysctl -q -w net.ipv4.conf.all.rp_filter=0
sysctl -q -w net.ipv4.conf.eth0.rp_filter=0
sysctl -q -w net.ipv4.conf.default.rp_filter=0

# enable IP forwarding and NAT
sysctl -q -w net.ipv4.ip_forward=1
sysctl -q -w net.ipv4.conf.eth0.send_redirects=0
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# wait for network connection
curl --retry 10 http://www.google.com

# reestablish connections
systemctl restart amazon-ssm-agent.service
