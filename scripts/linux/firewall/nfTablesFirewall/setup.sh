#!/bin/bash
apt-get update && apt-get install -y nftables 
apt-get update && apt-get install -y python3 
yum install -y nftables 
yum install -y python3
repo_root=$(git rev-parse --show-toplevel) 
mv $repo_root/scripts/linux/firewall/nfTablesFirewall/firewall.py /bin/firewall
chmod +x /bin/firewall
echo "Defaults env_keep += \"SSH_CONNECTION SSH_CLIENT SSH_TTY\"" >> /etc/sudoers
python3 $repo_root/scripts/linux/firewall/nfTablesFirewall/setup.py
rm $0