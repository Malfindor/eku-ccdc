#!/bin/bash

# Author: Raven Dean

# Ensure root
if [ "$EUID" -ne 0 ]
then echo "This script must be ran as root!" >&2
    exit
fi

# Get the path of the repository root
repo_root=$(git rev-parse --show-toplevel)

# Import environment variables
. $repo_root/config_files/ekurc

# Check repository security requirement
check_security

# Banner creation
cp $repo_root/config_files/banner /etc/ssh/banner.txt
# Make sure banner.txt has 644 permissions
chmod 644 /etc/ssh/banner.txt

# This collects the output of lsattr /etc/ssh/sshd_config and removes everything except the attribute portion
remove=" /etc/ssh/sshd_config"
immu=$(lsattr /etc/ssh/sshd_config)
attr=${immu%"$remove"}

# If sshd_config has the immutable attribute, remove it
if [[ $attr == *i* ]] ; then
    chattr -i /etc/ssh/sshd_config
fi

# Add Banner line to sshd_config if not present
if ! grep -Fxq "Banner /etc/ssh/banner.txt" /etc/ssh/sshd_config ; then
    printf "\nBanner /etc/ssh/banner.txt" >> /etc/ssh/sshd_config
fi

# Make sure root login is not permitted
search="PermitRootLogin yes"
replace="PermitRootLogin no"
sed -i "s/$search/$replace/" /etc/ssh/sshd_config


# Restart the ssh service in a brute force hacky way.
which systemctl >/dev/null # Return code 0 if systemctl exists
if [[ $? -eq 0 ]]
then
    systemctl restart sshd
else # If systemctl doesn't exist, use service.
    service sshd restart
fi
