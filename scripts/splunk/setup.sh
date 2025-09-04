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
yum install -y nftables 
yum install -y python3
yum install -y pip
yum install -y python3-devel
pip install wheel
pip install python-magic
pip install libmagic
pip install paramiko
echo "Setting up Manticore..."
mkdir /etc/manticore
mv $repo_root/scripts/linux/Manticore/* /etc/manticore
mv /etc/manticore/Manticore.py /bin/manticore
mv /etc/manticore/manticoreManager.py /bin/manticoreManager
chmod +x /bin/manticore
chmod +x /bin/manticoreManager
rm /etc/manticore/setup.sh
touch /etc/manticore/hosts.list
cat <<EOFA > /etc/systemd/system/manager.service
[Unit]
Description=Manticore management service

[Service]
Type=simple
Restart=on-failure
Environment="PATH=/sbin:/bin:/usr/sbin:/usr/bin"
ExecStart=/bin/bash -c 'manticoreManager "1894"'
StartLimitInterval=1s
StartLimitBurst=999

[Install]
WantedBy=multi-user.target
EOFA
#systemctl enable manager
#systemctl start manager
cat <<EOFA > /etc/manticore/listenerSetup
#!/bin/bash
yum install -y python3 #Still installing/updating python3 as backup
#Manual compile of Python 3.8 for OS versions too old for standard python3.8 install.
yum install -y wget
yum groupinstall -y "Development Tools"
yum install -y openssl-devel bzip2-devel libffi-devel
wget https://www.python.org/ftp/python/3.8.0/Python-3.8.0.tgz -P /
tar -xzf Python-3.8.0.tgz
Python-3.8.0/configure --enable-optimizations
make altinstall

#yum install -y libmnl libmnl-devel autoconf automake libtool pkgconfig bison flex
#wget --no-check-certificate https://netfilter.org/projects/libmnl/files/libmnl-1.0.5.tar.bz2 -P /
#tar -xjf libmnl-1.0.5.tar.bz2
#libmnl-1.0.5.tar.bz2/configure
#make
#make install
#cp libmnl.pc /usr/local/lib/pkgconfig/
#export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:\$PKG_CONFIG_PATH
#ldconfig

#wget --no-check-certificate https://netfilter.org/projects/libnftnl/files/libnftnl-1.2.8.tar.xz -P /
#tar -xzf libnftnl-1.2.8.tar.xz
#libnftnl-1.2.8/configure
#make
#make install

#yum install -y nftables #Install nftables as backup, manual compile of nft 1.1.0
#yum install -y libmnl-devel libnetlink-devel gmp gmp-devel libedit libedit-devel asciidoc
#git -c http.sslVerify=false clone https://git.netfilter.org/nftables /nftables
#wget --no-check-certificate https://netfilter.org/projects/nftables/files/nftables-1.1.0.tar.xz -P /
#tar -xvf nftables-1.1.0.tar.xz
#git checkout /nftables/v1.1.0
#/nftables/autogen.sh
#/nftables/configure
#make
#make install

if ! [ -d /etc/eku-ccdc ]
then
git clone https://github.com/ravesec/eku-ccdc /etc/eku-ccdc
fi
mv /etc/eku-ccdc/scripts/linux/Manticore/listener.py /bin/manticoreListener
chmod +x /bin/manticoreListener
cat << EOFB > /etc/systemd/system/manticore.service
[Unit]
Description=Manticore listener service

[Service]
Type=simple
Restart=on-failure
Environment="PATH=/sbin:/bin:/usr/sbin:/usr/bin"
ExecStart=/bin/bash -c 'manticoreListener "1893"'
StartLimitInterval=1s
StartLimitBurst=999

[Install]
WantedBy=multi-user.target
EOFB
ln -s /usr/local/bin/pip-3.8 /usr/bin/pip
mv /usr/bin/python3 /usr/bin/python3OLD
ln -s /usr/local/bin/python3.8 /usr/bin/python3
#mv /usr/bin/nft /usr/bin/nftOLD
#ln -s /usr/local/bin/nft /usr/bin/nft
systemctl daemon-deload
systemctl enable manticore
systemctl start manticore
rm /tmp/manticoreSetup
EOFA
#echo "Setting up E-Comm listener..."
#python3 /etc/manticore/netListenerSetup.py "172.20.241.30"
#echo "Setting up Fedora listener..."
#python3 /etc/manticore/netListenerSetup.py "172.20.241.40"
#echo "Setting up Debian listener..."
#python3 /etc/manticore/netListenerSetup.py "172.20.240.20"
#echo "Setting up Ubuntu listener..."
echo "Installing Gemini EDR..."
bash $repo_root/scripts/linux/Gemini/install.sh
mv $repo_root/scripts/linux/Gemini/terminal.py /bin/gemini
chmod +x /bin/gemini
echo "Installing Arbiter SIM..."
bash $repo_root/scripts/linux/Arbiter/install.sh
echo "Setting up firewall..."
mv $repo_root/scripts/linux/firewall/nfTablesFirewall/firewall.py /bin/firewall
chmod +x /bin/firewall
echo "Defaults env_keep += \"SSH_CONNECTION SSH_CLIENT SSH_TTY\"" >> /etc/sudoers
python3 $repo_root/scripts/linux/firewall/nfTablesFirewall/setup.py "splunk"
#echo "Beginning remote setup..."
#manticore -i
#manticore -gi
echo "Beginning GUI setup..."
yum update -y
yum groupinstall -y "Server with GUI"
systemctl set-default graphical
echo "Preventing password changes..."
chattr +i /etc/passwd
chattr +i /opt/splunk/etc/passwd
chattr +i /etc/shadow
reboot