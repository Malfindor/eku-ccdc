#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Must be run as root"
	exit
fi
repo_root=$(git rev-parse --show-toplevel)
#User creation
useradd -M -u 600 -g 600 -s /usr/sbin/nologin manticore

#Listener service creation
mv $repo_root/scripts/linux/Manticore/listener.service /etc/systemd/system/manticore.service
mv $repo_root/scripts/linux/Manticore/listener.sh /bin/manticoreListener
chmod 700 /bin/manticoreListener #Perms: rwx --- ---
chown manticore /bin/manticoreListener
echo "manticore ALL=(ALL) NOPASSWD: /bin/manticoreListener" >> /etc/sudoers
chown root /etc/systemd/system/manticore.service
systemctl daemon-reload
systemctl enable manticore
systemctl start manticore

#Log file creation
touch /var/log/manticore.log
chmod 640 /var/log/manticore.log #Perms: rw- r-- ---		Arbiter log forwarder user will be a member of the "manticore" group, and so will be able to read