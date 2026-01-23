#!/bin/bash
repo_root=$(git rev-parse --show-toplevel)
echo "Enter new root password: "
stty -echo
read rPass
stty echo
echo "root:$rPass" | chpasswd
echo "Enter new sysadmin password: "
stty -echo
read sPass
stty echo
echo "Enter new splunk admin password: "
stty -echo
read password
stty echo
echo "sysadmin:$sPass" | chpasswd
echo "Clearing crontab..."
echo "" > /etc/crontab
echo "Removing ssh keys..."
if [ -f /root/.ssh/authorized_keys ]
then
echo "" > /root/.ssh/authorized_keys
fi
if [ -f /home/sysadmin/.ssh/authorized_keys ] 
then
echo "" > /home/sysadmin/.ssh/authorized_keys ] 
fi
echo "Clearing splunk and installing new admin user..."
/opt/splunk/bin/splunk stop
/opt/splunk/bin/splunk clean all -f
cat <<EOFA > /opt/splunk/etc/system/local/user-seed.conf
[user_info]
USERNAME = admin
PASSWORD = $password
EOFA
/opt/splunk/bin/splunk start
echo "Splunk accounts reset."
echo "Installing VigilEDR..."
yum install -y python3 python3-pip
pip3 install GitPython
python3 $repo_root/scripts/linux/vigil/installer.py -s --repo-root $repo_root/scripts/linux/vigiledr
echo "VigilEDR installation complete."
echo "Setting up firewall..."
mv $repo_root/scripts/linux/firewall/nfTablesFirewall/firewall.py /bin/firewall
chmod +x /bin/firewall
echo "Defaults env_keep += \"SSH_CONNECTION SSH_CLIENT SSH_TTY\"" >> /etc/sudoers
python3 $repo_root/scripts/linux/firewall/nfTablesFirewall/setup.py "splunk"
echo "Beginning GUI setup..."
yum update -y
yum groupinstall -y "Server with GUI"
systemctl set-default graphical
echo "Preventing password changes..."
chattr +i /etc/passwd
chattr +i /opt/splunk/etc/passwd
chattr +i /etc/shadow
reboot