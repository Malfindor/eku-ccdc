#!/bin/bash
repo_root=$(git rev-parse --show-toplevel)
validNames=("centos" "ecom" "fedora" "ubuntu" "debian" "splunk")
isValid="false"
while [ "$isValid" == "false" ]; do
	echo "Enter machine name(centos/ecom, fedora, ubuntu, debian, splunk): "
	read machine
	for name in "${validNames[@]}"; do
		if [[ "$name" -eq "machine" ]]; then
			isValid="true"
		fi
	done
done
requiredPortsTCP=()
requiredPortsUDP=()
requiredIPs=("8.8.8.8" "8.8.4.4")
case "$machine" in 
	"centos")
		requiredPortsTCP=("80" "443" "53")
		requiredPortsUDP=("53" "123")
		;;
	"ecom")
		requiredPortsTCP=("80" "443" "53")
		requiredPortsUDP=("53" "123")
		;;
	"fedora")
		requiredPortsTCP=("80" "443" "53" "25" "110")
		requiredPortsUDP=("53" "123")
		;;
	"ubuntu")
		requiredPortsTCP=("80" "443" "53")
		requiredPortsUDP=("53" "123")
		;;
	"debian")
		requiredPortsTCP=("80" "443" "53")
		requiredPortsUDP=("53" "123")
		;;
	"splunk")
		requiredPortsTCP=("80" "443" "53" "8000" "8089")
		requiredPortsUDP=("53" "123")
		;;
	*)
		requiredPortsTCP=("80" "443" "53")
		requiredPortsUDP=("53")
		;;
esac
#Setting all policies to accept and clearing all rules. This clears any pre-set rules from red-team and prevents services from going down during install.
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
#Allowing loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

for port in "${requiredPortsTCP[@]}"; do
	iptables -A INPUT -p tcp --dport $port -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -p tcp --sport $port -m conntrack --ctstate ESTABLISHED -j ACCEPT
done
for port in "${requiredPortsUDP[@]}"; do
	iptables -A INPUT -p udp --dport $port -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -p udp --sport $port -m conntrack --ctstate ESTABLISHED -j ACCEPT
done
for address in "${requiredIPs[@]}"; do #Whitelisted IPs
	iptables -A INPUT -s $address -j ACCEPT
	iptables -A OUTPUT -d $address -j ACCEPT
done
#Setup complete. Denying all other traffic.
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

#Saving rules
iptables-save > /etc/iptables/rules.v4

#Enabling reboot persistance
apt install iptables-persistent
systemctl enable iptables
systemctl start iptables

mv $repo_root/scripts/linux/firewall/ipTablesFirewall/firewall.sh /bin/firewall
chmod +x /bin/firewall