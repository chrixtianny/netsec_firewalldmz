#!/bin/bash
iptables -F
iptables -X

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT

iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -i eth1 -o eth0 -m state --state NEW -j ACCEPT

iptables -A FORWARD -i eth1 -o eth2 -m state --state NEW -j ACCEPT

iptables -A FORWARD -i eth0 -o eth2 -d 10.0.2.10 -p tcp -m multiport --dports 80,443 -m state --state NEW -j ACCEPT

echo "Politica de perimetro aplicada."