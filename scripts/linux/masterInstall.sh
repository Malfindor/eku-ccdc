#This installer is designed to be used in conjunction with the EKU-CCDC github (https://github.com/malfindor/eku-ccdc)
#This can be run on any linux machine and it will begin installing the custom tools involved in the competition

#!/bin/bash
echo "Installing dependencies"
repo_root=$(git rev-parse --show-toplevel)
echo "Installing VigilEDR"
python3 $repo_root/scripts/linux/vigiledr/install.py -c
echo "Installing Firewall interface"
bash $repo_root/scripts/linux/firewall/install.sh
systemctl daemon-reload
echo "Installation complete."
echo "Don't forget to edit the file located at /etc/vigil.conf before starting Gemini."
echo "It can brick your service if you don't"
echo "When it's edited, run the following two commands:"
echo "systemctl enable vigil.service"
echo "systemctl start vigil.service"