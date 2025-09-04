#!/bin/bash
repo_root=$(git rev-parse --show-toplevel)
mkdir /etc/gemini
mkdir /.quarantine
chmod 000 /.quarantine
mv "$repo_root/scripts/linux/Gemini/core.sh" /etc/gemini/core
chmod +x /etc/gemini/core
mv $repo_root/scripts/linux/Gemini/controller.sh /etc/gemini/controller
chmod +x /etc/gemini/controller
mv $repo_root/scripts/linux/Gemini/gemini-bin.sh /bin/gemini
chmod +x /bin/gemini
mv $repo_root/scripts/linux/Gemini/modules/firewatch/firewatch.sh /etc/gemini/firewatch
chmod +x /etc/gemini/firewatch
mv $repo_root/scripts/linux/Gemini/modules/firewatch/firewatch.service /etc/systemd/system/gemini-firewatch.service
touch /etc/gemini/iptablesrules.bak
iptables -L -v -n > /etc/gemini/iptablesrules.bak
mv "$repo_root/scripts/linux/Gemini/gemini.service" /etc/systemd/system/gemini.service
mv "$repo_root/scripts/linux/Gemini/core.service" /etc/systemd/system/gemini-core.service
mv "$repo_root/scripts/linux/Gemini/gemini.conf" /etc/gemini/gemini.conf
systemctl daemon-reload
if [[ -d /var/www/ ]]; then
	echo "Webserver detected, installing Titan Web-Guard."
	bash $repo_root/scripts/linux/Titan/install.sh
fi
declare -i x=3
machineList=("centos" "ecom" "fedora" "debian" "ubuntu")
while [[ x -eq 3 ]]; do
	if [[ -d /opt/splunk/bin ]]; then
		echo "Splunk" >> machine.name
		x=4
	else
		echo "Enter your machine name(centos/fedora/debian/ubuntu): "
		read machine
		for item in "${machineList[@]}"; do
			if [[ $machine == $item ]]; then
				x=4
			fi
		done
		if [[ x -eq 3 ]]; then
			echo "Invalid entry."
		fi
	fi
done
touch /etc/gemini/machine.name
echo "$machine" >> machine.name
echo "Gemini installed, but has not started. Please edit the file located at /etc/gemini/gemini.conf and make changes to the settings as needed before starting."
echo "Once settings have been changed, start Gemini by running this command:"
echo "gemini start"